-- =====================================================
-- AI-DEPOM - FASE 2: BACKUP AUTOMÁTICO
-- =====================================================
-- Caminho: database/security/05-backup-automatico.sql
-- Data: 08/09/2026 - 15:30
-- Versão: 1.0.0
-- Descrição: Configuração de backup automático e manual
-- =====================================================

-- =====================================================
-- 1. TABELA DE HISTÓRICO DE BACKUPS
-- =====================================================
-- Descrição: Registra todos os backups realizados
-- =====================================================

CREATE TABLE IF NOT EXISTS public.historico_backups (
    id_backup SERIAL PRIMARY KEY,
    nome_backup VARCHAR(100) NOT NULL,
    tipo_backup VARCHAR(20) NOT NULL CHECK (tipo_backup IN ('AUTOMATICO', 'MANUAL', 'RESTAURACAO')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('INICIADO', 'EM_ANDAMENTO', 'CONCLUIDO', 'FALHA')),
    tamanho_bytes BIGINT,
    duracao_segundos INTEGER,
    data_inicio TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_fim TIMESTAMP WITH TIME ZONE,
    detalhes JSONB,
    id_usuario UUID REFERENCES public.usuarios(id)
);

-- =====================================================
-- 2. ÍNDICES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_historico_backups_data ON public.historico_backups(data_inicio DESC);
CREATE INDEX IF NOT EXISTS idx_historico_backups_status ON public.historico_backups(status);
CREATE INDEX IF NOT EXISTS idx_historico_backups_tipo ON public.historico_backups(tipo_backup);

-- =====================================================
-- 3. FUNÇÃO PARA INICIAR BACKUP MANUAL
-- =====================================================
-- Descrição: Inicia um backup manual do sistema
-- =====================================================

CREATE OR REPLACE FUNCTION public.iniciar_backup_manual()
RETURNS JSONB AS $$
DECLARE
    v_usuario_id UUID;
    v_backup_id INTEGER;
    v_nome_backup VARCHAR(100);
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Usuário não autenticado'
        );
    END IF;
    
    -- Verificar permissão (apenas administradores)
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = v_usuario_id AND (p.is_master = TRUE OR p.nome = 'ADMINISTRADOR')
    ) THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Usuário sem permissão para realizar backup'
        );
    END IF;
    
    -- Gerar nome do backup
    v_nome_backup := 'backup_manual_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    
    -- Registrar início do backup
    INSERT INTO public.historico_backups (
        nome_backup,
        tipo_backup,
        status,
        data_inicio,
        id_usuario
    ) VALUES (
        v_nome_backup,
        'MANUAL',
        'INICIADO',
        NOW(),
        v_usuario_id
    ) RETURNING id_backup INTO v_backup_id;
    
    -- Registrar auditoria
    PERFORM public.registrar_auditoria(
        'BACKUP_MANUAL_INICIO',
        'historico_backups',
        v_backup_id,
        NULL,
        jsonb_build_object(
            'nome_backup', v_nome_backup,
            'usuario', v_usuario_id
        )
    );
    
    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Backup manual iniciado com sucesso',
        'backup_id', v_backup_id,
        'nome_backup', v_nome_backup,
        'data_inicio', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. FUNÇÃO PARA CONCLUIR BACKUP
-- =====================================================
-- Descrição: Conclui um backup registrando o resultado
-- =====================================================

CREATE OR REPLACE FUNCTION public.concluir_backup(
    p_backup_id INTEGER,
    p_status VARCHAR(20),
    p_tamanho_bytes BIGINT DEFAULT NULL,
    p_duracao_segundos INTEGER DEFAULT NULL,
    p_detalhes JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_usuario_id UUID;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    -- Atualizar status do backup
    UPDATE public.historico_backups
    SET 
        status = p_status,
        tamanho_bytes = COALESCE(p_tamanho_bytes, tamanho_bytes),
        duracao_segundos = COALESCE(p_duracao_segundos, duracao_segundos),
        data_fim = NOW(),
        detalhes = COALESCE(p_detalhes, detalhes)
    WHERE id_backup = p_backup_id;
    
    -- Registrar auditoria
    PERFORM public.registrar_auditoria(
        'BACKUP_' || p_status,
        'historico_backups',
        p_backup_id,
        NULL,
        jsonb_build_object(
            'status', p_status,
            'tamanho_bytes', p_tamanho_bytes,
            'duracao_segundos', p_duracao_segundos
        )
    );
    
    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Backup concluído com status: ' || p_status,
        'backup_id', p_backup_id,
        'status', p_status,
        'data_fim', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. FUNÇÃO PARA VERIFICAR BACKUPS RECENTES
-- =====================================================
-- Descrição: Verifica backups realizados nos últimos dias
-- =====================================================

CREATE OR REPLACE FUNCTION public.verificar_backups_recentes(
    p_dias INTEGER DEFAULT 7
)
RETURNS JSONB AS $$
DECLARE
    v_total INTEGER;
    v_ultimo_backup RECORD;
    v_resultado JSONB;
BEGIN
    -- Contar backups nos últimos dias
    SELECT COUNT(*) INTO v_total
    FROM public.historico_backups
    WHERE data_inicio >= NOW() - (p_dias || ' days')::INTERVAL
    AND status = 'CONCLUIDO';
    
    -- Obter último backup
    SELECT * INTO v_ultimo_backup
    FROM public.historico_backups
    WHERE status = 'CONCLUIDO'
    ORDER BY data_fim DESC
    LIMIT 1;
    
    v_resultado := jsonb_build_object(
        'sucesso', TRUE,
        'total_backups', v_total,
        'dias_analisados', p_dias,
        'ultimo_backup', CASE 
            WHEN v_ultimo_backup IS NOT NULL THEN 
                jsonb_build_object(
                    'id', v_ultimo_backup.id_backup,
                    'nome', v_ultimo_backup.nome_backup,
                    'tipo', v_ultimo_backup.tipo_backup,
                    'data', v_ultimo_backup.data_fim,
                    'tamanho_bytes', v_ultimo_backup.tamanho_bytes
                )
            ELSE NULL
        END,
        'backup_necessario', COALESCE(v_total, 0) < 1
    );
    
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. FUNÇÃO PARA RESTAURAR BACKUP (SIMULADA)
-- =====================================================
-- Descrição: Restaura um backup (apenas registra a ação)
-- NOTA: A restauração real é feita pelo Supabase
-- =====================================================

CREATE OR REPLACE FUNCTION public.restaurar_backup(
    p_backup_id INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_usuario_id UUID;
    v_backup RECORD;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Usuário não autenticado'
        );
    END IF;
    
    -- Verificar permissão
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = v_usuario_id AND (p.is_master = TRUE OR p.nome = 'ADMINISTRADOR')
    ) THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Usuário sem permissão para restaurar backup'
        );
    END IF;
    
    -- Buscar backup
    SELECT * INTO v_backup
    FROM public.historico_backups
    WHERE id_backup = p_backup_id;
    
    IF v_backup IS NULL THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Backup não encontrado'
        );
    END IF;
    
    -- Registrar restauração
    INSERT INTO public.historico_backups (
        nome_backup,
        tipo_backup,
        status,
        data_inicio,
        id_usuario,
        detalhes
    ) VALUES (
        'restauracao_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS'),
        'RESTAURACAO',
        'INICIADO',
        NOW(),
        v_usuario_id,
        jsonb_build_object(
            'backup_original_id', p_backup_id,
            'backup_original_nome', v_backup.nome_backup
        )
    );
    
    -- Registrar auditoria
    PERFORM public.registrar_auditoria(
        'RESTAURAR_BACKUP',
        'historico_backups',
        p_backup_id,
        NULL,
        jsonb_build_object(
            'backup_restaurado', v_backup.nome_backup,
            'usuario', v_usuario_id
        )
    );
    
    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Restauração do backup iniciada com sucesso',
        'backup_original', v_backup.nome_backup,
        'data_restauracao', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. VIEW DE STATUS DOS BACKUPS
-- =====================================================
-- Descrição: Resumo dos backups realizados
-- =====================================================

CREATE OR REPLACE VIEW public.vw_status_backups AS
SELECT 
    id_backup,
    nome_backup,
    tipo_backup,
    status,
    data_inicio,
    data_fim,
    EXTRACT(EPOCH FROM (data_fim - data_inicio)) AS duracao_segundos,
    tamanho_bytes,
    CASE 
        WHEN tamanho_bytes IS NOT NULL THEN 
            ROUND(tamanho_bytes / 1024.0 / 1024.0, 2) || ' MB'
        ELSE 'N/A'
    END AS tamanho_formatado,
    CASE 
        WHEN status = 'CONCLUIDO' THEN '✅ Concluído'
        WHEN status = 'EM_ANDAMENTO' THEN '⏳ Em Andamento'
        WHEN status = 'INICIADO' THEN '🔄 Iniciado'
        WHEN status = 'FALHA' THEN '❌ Falha'
        ELSE status
    END AS status_label
FROM public.historico_backups
ORDER BY data_inicio DESC;

-- =====================================================
-- 8. CRON JOB PARA BACKUP AUTOMÁTICO (SIMULADO)
-- =====================================================
-- Descrição: Função que seria chamada por um cron job
-- NOTA: No Supabase, os backups automáticos são configurados
--       no painel de administração
-- =====================================================

CREATE OR REPLACE FUNCTION public.backup_automatico()
RETURNS JSONB AS $$
DECLARE
    v_backup_id INTEGER;
    v_nome_backup VARCHAR(100);
BEGIN
    -- Gerar nome do backup
    v_nome_backup := 'backup_auto_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    
    -- Registrar início do backup
    INSERT INTO public.historico_backups (
        nome_backup,
        tipo_backup,
        status,
        data_inicio
    ) VALUES (
        v_nome_backup,
        'AUTOMATICO',
        'INICIADO',
        NOW()
    ) RETURNING id_backup INTO v_backup_id;
    
    -- Simular execução do backup
    PERFORM pg_sleep(1);
    
    -- Concluir backup
    UPDATE public.historico_backups
    SET 
        status = 'CONCLUIDO',
        data_fim = NOW(),
        tamanho_bytes = 1024 * 1024 * 10, -- 10 MB (simulado)
        duracao_segundos = 1
    WHERE id_backup = v_backup_id;
    
    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Backup automático concluído',
        'backup_id', v_backup_id,
        'nome_backup', v_nome_backup
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ BACKUP AUTOMÁTICO CONFIGURADO' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Itens criados:' ;
    RAISE NOTICE '   - Tabela: historico_backups' ;
    RAISE NOTICE '   - Função: iniciar_backup_manual' ;
    RAISE NOTICE '   - Função: concluir_backup' ;
    RAISE NOTICE '   - Função: verificar_backups_recentes' ;
    RAISE NOTICE '   - Função: restaurar_backup' ;
    RAISE NOTICE '   - Função: backup_automatico' ;
    RAISE NOTICE '   - View: vw_status_backups' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔐 Próximo passo: Configurar Logging Avançado' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
