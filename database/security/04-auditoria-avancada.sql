-- =====================================================
-- AI-DEPOM - FASE 2: AUDITORIA AVANÇADA
-- =====================================================
-- Caminho: database/security/04-auditoria-avancada.sql
-- Data: 08/09/2026 - 15:15
-- Versão: 1.0.0
-- Descrição: Sistema completo de auditoria e logs
-- =====================================================

-- =====================================================
-- 1. TABELA DE AUDITORIA DETALHADA
-- =====================================================
-- Descrição: Registro completo de todas as ações do sistema
-- =====================================================

CREATE TABLE IF NOT EXISTS public.auditoria_detalhada (
    id_auditoria SERIAL PRIMARY KEY,
    id_usuario UUID REFERENCES public.usuarios(id),
    acao VARCHAR(50) NOT NULL,
    tabela VARCHAR(50) NOT NULL,
    id_registro INTEGER,
    dados_anteriores JSONB,
    dados_novos JSONB,
    ip_origem VARCHAR(45),
    user_agent TEXT,
    data_hora TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sucesso BOOLEAN DEFAULT TRUE,
    mensagem_erro TEXT,
    tempo_execucao INTEGER, -- em milissegundos
    detalhes_adicionais JSONB
);

-- =====================================================
-- 2. ÍNDICES PARA PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_auditoria_detalhada_usuario ON public.auditoria_detalhada(id_usuario);
CREATE INDEX IF NOT EXISTS idx_auditoria_detalhada_tabela ON public.auditoria_detalhada(tabela);
CREATE INDEX IF NOT EXISTS idx_auditoria_detalhada_data ON public.auditoria_detalhada(data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_detalhada_acao ON public.auditoria_detalhada(acao);
CREATE INDEX IF NOT EXISTS idx_auditoria_detalhada_sucesso ON public.auditoria_detalhada(sucesso);

-- =====================================================
-- 3. FUNÇÃO PARA REGISTRAR AUDITORIA
-- =====================================================
-- Descrição: Função central para registrar ações no sistema
-- =====================================================

CREATE OR REPLACE FUNCTION public.registrar_auditoria(
    p_acao VARCHAR,
    p_tabela VARCHAR,
    p_id_registro INTEGER DEFAULT NULL,
    p_dados_anteriores JSONB DEFAULT NULL,
    p_dados_novos JSONB DEFAULT NULL,
    p_sucesso BOOLEAN DEFAULT TRUE,
    p_mensagem_erro TEXT DEFAULT NULL,
    p_tempo_execucao INTEGER DEFAULT NULL,
    p_detalhes JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_usuario_id UUID;
    v_ip VARCHAR;
    v_user_agent TEXT;
    v_id_auditoria INTEGER;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    -- Obter IP e User-Agent
    v_ip := COALESCE(current_setting('request.headers', TRUE)::json->>'x-forwarded-for', '127.0.0.1');
    v_user_agent := COALESCE(current_setting('request.headers', TRUE)::json->>'user-agent', 'unknown');
    
    -- Inserir auditoria
    INSERT INTO public.auditoria_detalhada (
        id_usuario,
        acao,
        tabela,
        id_registro,
        dados_anteriores,
        dados_novos,
        ip_origem,
        user_agent,
        sucesso,
        mensagem_erro,
        tempo_execucao,
        detalhes_adicionais
    ) VALUES (
        v_usuario_id,
        p_acao,
        p_tabela,
        p_id_registro,
        p_dados_anteriores,
        p_dados_novos,
        v_ip,
        v_user_agent,
        p_sucesso,
        p_mensagem_erro,
        p_tempo_execucao,
        p_detalhes
    ) RETURNING id_auditoria INTO v_id_auditoria;
    
    RETURN v_id_auditoria;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. FUNÇÃO PARA CONSULTAR AUDITORIA
-- =====================================================
-- Descrição: Consulta logs de auditoria com filtros
-- =====================================================

CREATE OR REPLACE FUNCTION public.consultar_auditoria(
    p_data_inicio TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_data_fim TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    p_usuario_id UUID DEFAULT NULL,
    p_acao VARCHAR DEFAULT NULL,
    p_tabela VARCHAR DEFAULT NULL,
    p_sucesso BOOLEAN DEFAULT NULL,
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id_auditoria INTEGER,
    usuario_matricula VARCHAR,
    usuario_nome VARCHAR,
    acao VARCHAR,
    tabela VARCHAR,
    id_registro INTEGER,
    dados_anteriores JSONB,
    dados_novos JSONB,
    ip_origem VARCHAR,
    data_hora TIMESTAMP WITH TIME ZONE,
    sucesso BOOLEAN,
    mensagem_erro TEXT,
    tempo_execucao INTEGER
) AS $$
BEGIN
    -- Verificar permissão (apenas usuários com nível >= 8)
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 8
    ) THEN
        RAISE EXCEPTION 'Usuário sem permissão para consultar auditoria (nível necessário: 8)';
    END IF;
    
    RETURN QUERY
    SELECT 
        a.id_auditoria,
        u.matricula AS usuario_matricula,
        u.nome_completo AS usuario_nome,
        a.acao,
        a.tabela,
        a.id_registro,
        a.dados_anteriores,
        a.dados_novos,
        a.ip_origem,
        a.data_hora,
        a.sucesso,
        a.mensagem_erro,
        a.tempo_execucao
    FROM public.auditoria_detalhada a
    LEFT JOIN public.usuarios u ON a.id_usuario = u.id
    WHERE a.data_hora BETWEEN p_data_inicio AND p_data_fim
      AND (p_usuario_id IS NULL OR a.id_usuario = p_usuario_id)
      AND (p_acao IS NULL OR a.acao = p_acao)
      AND (p_tabela IS NULL OR a.tabela = p_tabela)
      AND (p_sucesso IS NULL OR a.sucesso = p_sucesso)
    ORDER BY a.data_hora DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. TRIGGERS PARA AUDITORIA AUTOMÁTICA
-- =====================================================

-- Trigger para INSERT
CREATE OR REPLACE FUNCTION public.auditoria_insert_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_id_registro INTEGER;
BEGIN
    -- Determinar ID do registro
    CASE TG_TABLE_NAME
        WHEN 'suspeito' THEN v_id_registro := NEW.id_suspeito;
        WHEN 'investigacao' THEN v_id_registro := NEW.id_investigacao;
        WHEN 'mandado_prisao' THEN v_id_registro := NEW.id_mandado;
        WHEN 'ocorrencia' THEN v_id_registro := NEW.id_ocorrencia;
        ELSE v_id_registro := 0;
    END CASE;
    
    PERFORM public.registrar_auditoria(
        'INSERT',
        TG_TABLE_NAME,
        v_id_registro,
        NULL,
        to_jsonb(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para UPDATE
CREATE OR REPLACE FUNCTION public.auditoria_update_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_id_registro INTEGER;
BEGIN
    -- Determinar ID do registro
    CASE TG_TABLE_NAME
        WHEN 'suspeito' THEN v_id_registro := OLD.id_suspeito;
        WHEN 'investigacao' THEN v_id_registro := OLD.id_investigacao;
        WHEN 'mandado_prisao' THEN v_id_registro := OLD.id_mandado;
        WHEN 'ocorrencia' THEN v_id_registro := OLD.id_ocorrencia;
        ELSE v_id_registro := 0;
    END CASE;
    
    PERFORM public.registrar_auditoria(
        'UPDATE',
        TG_TABLE_NAME,
        v_id_registro,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para DELETE (lógico)
CREATE OR REPLACE FUNCTION public.auditoria_delete_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_id_registro INTEGER;
BEGIN
    -- Determinar ID do registro
    CASE TG_TABLE_NAME
        WHEN 'suspeito' THEN v_id_registro := OLD.id_suspeito;
        WHEN 'investigacao' THEN v_id_registro := OLD.id_investigacao;
        WHEN 'mandado_prisao' THEN v_id_registro := OLD.id_mandado;
        WHEN 'ocorrencia' THEN v_id_registro := OLD.id_ocorrencia;
        ELSE v_id_registro := 0;
    END CASE;
    
    PERFORM public.registrar_auditoria(
        'DELETE_LOGICO',
        TG_TABLE_NAME,
        v_id_registro,
        to_jsonb(OLD),
        jsonb_build_object('deletado', TRUE, 'data_deletado', NOW())
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. APLICAR TRIGGERS (OPCIONAL - ATIVAR CONFORME NECESSIDADE)
-- =====================================================
-- NOTA: Ative os triggers abaixo apenas quando necessário
-- para evitar sobrecarga no banco de dados
-- =====================================================

-- Trigger para suspeito
-- CREATE TRIGGER auditoria_suspeito_insert
-- AFTER INSERT ON public.suspeito
-- FOR EACH ROW
-- EXECUTE FUNCTION public.auditoria_insert_trigger();

-- CREATE TRIGGER auditoria_suspeito_update
-- AFTER UPDATE ON public.suspeito
-- FOR EACH ROW
-- EXECUTE FUNCTION public.auditoria_update_trigger();

-- CREATE TRIGGER auditoria_suspeito_delete
-- BEFORE DELETE ON public.suspeito
-- FOR EACH ROW
-- EXECUTE FUNCTION public.auditoria_delete_trigger();

-- =====================================================
-- 7. VIEW DE RESUMO DE AUDITORIA
-- =====================================================
-- Descrição: Resumo das atividades do sistema
-- =====================================================

CREATE OR REPLACE VIEW public.vw_resumo_auditoria AS
SELECT 
    DATE(a.data_hora) AS data,
    COUNT(*) AS total_acoes,
    COUNT(*) FILTER (WHERE a.acao = 'INSERT') AS total_inserts,
    COUNT(*) FILTER (WHERE a.acao = 'UPDATE') AS total_updates,
    COUNT(*) FILTER (WHERE a.acao = 'DELETE_LOGICO') AS total_deletes,
    COUNT(*) FILTER (WHERE a.acao = 'LOGIN') AS total_logins,
    COUNT(*) FILTER (WHERE a.sucesso = FALSE) AS total_erros,
    COUNT(DISTINCT a.id_usuario) AS usuarios_ativos
FROM public.auditoria_detalhada a
WHERE a.data_hora >= NOW() - INTERVAL '30 days'
GROUP BY DATE(a.data_hora)
ORDER BY data DESC;

-- =====================================================
-- 8. FUNÇÃO PARA LIMPAR LOGS ANTIGOS
-- =====================================================
-- Descrição: Remove logs mais antigos que o período especificado
-- =====================================================

CREATE OR REPLACE FUNCTION public.limpar_logs_antigos(
    p_dias INTEGER DEFAULT 90
)
RETURNS INTEGER AS $$
DECLARE
    v_removidos INTEGER;
BEGIN
    -- Verificar permissão (apenas administradores)
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND (p.is_master = TRUE OR p.nome = 'ADMINISTRADOR')
    ) THEN
        RAISE EXCEPTION 'Usuário sem permissão para limpar logs';
    END IF;
    
    -- Remover logs antigos
    WITH deletados AS (
        DELETE FROM public.auditoria_detalhada
        WHERE data_hora < NOW() - (p_dias || ' days')::INTERVAL
        RETURNING id_auditoria
    )
    SELECT COUNT(*) INTO v_removidos FROM deletados;
    
    -- Registrar ação
    PERFORM public.registrar_auditoria(
        'LIMPAR_LOGS',
        'auditoria_detalhada',
        NULL,
        NULL,
        jsonb_build_object('dias', p_dias, 'removidos', v_removidos)
    );
    
    RETURN v_removidos;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ AUDITORIA AVANÇADA CONFIGURADA' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Itens criados:' ;
    RAISE NOTICE '   - Tabela: auditoria_detalhada' ;
    RAISE NOTICE '   - Função: registrar_auditoria' ;
    RAISE NOTICE '   - Função: consultar_auditoria' ;
    RAISE NOTICE '   - Função: limpar_logs_antigos' ;
    RAISE NOTICE '   - View: vw_resumo_auditoria' ;
    RAISE NOTICE '   - Triggers: INSERT, UPDATE, DELETE' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔐 Próximo passo: Configurar Backup Automático' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
