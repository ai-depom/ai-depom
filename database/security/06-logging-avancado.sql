-- =====================================================
-- AI-DEPOM - FASE 2: LOGGING AVANÇADO
-- =====================================================
-- Caminho: database/security/06-logging-avancado.sql
-- Data: 08/09/2026 - 15:45
-- Versão: 1.0.0
-- Descrição: Sistema avançado de logs com níveis e categorias
-- =====================================================

-- =====================================================
-- 1. TABELA DE LOGS DETALHADOS
-- =====================================================
-- Descrição: Logs estruturados com níveis e categorias
-- =====================================================

CREATE TABLE IF NOT EXISTS public.logs_detalhados (
    id_log SERIAL PRIMARY KEY,
    id_usuario UUID REFERENCES public.usuarios(id),
    nivel VARCHAR(20) NOT NULL CHECK (nivel IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    categoria VARCHAR(50) NOT NULL,
    mensagem TEXT NOT NULL,
    detalhes JSONB,
    ip_origem VARCHAR(45),
    user_agent TEXT,
    data_hora TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    id_entidade INTEGER,
    tipo_entidade VARCHAR(50),
    origem VARCHAR(100),
    stack_trace TEXT
);

-- =====================================================
-- 2. ÍNDICES PARA PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_logs_detalhados_data ON public.logs_detalhados(data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_logs_detalhados_nivel ON public.logs_detalhados(nivel);
CREATE INDEX IF NOT EXISTS idx_logs_detalhados_categoria ON public.logs_detalhados(categoria);
CREATE INDEX IF NOT EXISTS idx_logs_detalhados_usuario ON public.logs_detalhados(id_usuario);
CREATE INDEX IF NOT EXISTS idx_logs_detalhados_entidade ON public.logs_detalhados(id_entidade, tipo_entidade);

-- =====================================================
-- 3. FUNÇÃO PARA REGISTRAR LOG
-- =====================================================
-- Descrição: Função central para registrar logs
-- =====================================================

CREATE OR REPLACE FUNCTION public.registrar_log(
    p_nivel VARCHAR,
    p_categoria VARCHAR,
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL,
    p_id_entidade INTEGER DEFAULT NULL,
    p_tipo_entidade VARCHAR DEFAULT NULL,
    p_origem VARCHAR DEFAULT NULL,
    p_stack_trace TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_usuario_id UUID;
    v_ip VARCHAR;
    v_user_agent TEXT;
    v_id_log INTEGER;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    -- Obter IP e User-Agent
    v_ip := COALESCE(current_setting('request.headers', TRUE)::json->>'x-forwarded-for', '127.0.0.1');
    v_user_agent := COALESCE(current_setting('request.headers', TRUE)::json->>'user-agent', 'unknown');
    
    -- Inserir log
    INSERT INTO public.logs_detalhados (
        id_usuario,
        nivel,
        categoria,
        mensagem,
        detalhes,
        ip_origem,
        user_agent,
        id_entidade,
        tipo_entidade,
        origem,
        stack_trace
    ) VALUES (
        v_usuario_id,
        p_nivel,
        p_categoria,
        p_mensagem,
        p_detalhes,
        v_ip,
        v_user_agent,
        p_id_entidade,
        p_tipo_entidade,
        p_origem,
        p_stack_trace
    ) RETURNING id_log INTO v_id_log;
    
    -- Se for erro crítico, registrar também na auditoria
    IF p_nivel IN ('ERROR', 'CRITICAL') THEN
        PERFORM public.registrar_auditoria(
            'LOG_' || p_nivel,
            'logs_detalhados',
            v_id_log,
            NULL,
            jsonb_build_object(
                'nivel', p_nivel,
                'categoria', p_categoria,
                'mensagem', p_mensagem,
                'detalhes', p_detalhes
            ),
            p_nivel = 'CRITICAL'
        );
    END IF;
    
    RETURN v_id_log;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. FUNÇÕES WRAPPER PARA CADA NÍVEL
-- =====================================================

-- DEBUG
CREATE OR REPLACE FUNCTION public.log_debug(
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL,
    p_origem VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log('DEBUG', 'SISTEMA', p_mensagem, p_detalhes, NULL, NULL, p_origem);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- INFO
CREATE OR REPLACE FUNCTION public.log_info(
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL,
    p_origem VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log('INFO', 'SISTEMA', p_mensagem, p_detalhes, NULL, NULL, p_origem);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- WARNING
CREATE OR REPLACE FUNCTION public.log_warning(
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL,
    p_origem VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log('WARNING', 'SISTEMA', p_mensagem, p_detalhes, NULL, NULL, p_origem);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ERROR
CREATE OR REPLACE FUNCTION public.log_error(
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL,
    p_origem VARCHAR DEFAULT NULL,
    p_stack_trace TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log('ERROR', 'SISTEMA', p_mensagem, p_detalhes, NULL, NULL, p_origem, p_stack_trace);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CRITICAL
CREATE OR REPLACE FUNCTION public.log_critical(
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL,
    p_origem VARCHAR DEFAULT NULL,
    p_stack_trace TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log('CRITICAL', 'SISTEMA', p_mensagem, p_detalhes, NULL, NULL, p_origem, p_stack_trace);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. LOGS POR CATEGORIA
-- =====================================================

-- Log de Segurança
CREATE OR REPLACE FUNCTION public.log_seguranca(
    p_mensagem TEXT,
    p_nivel VARCHAR DEFAULT 'INFO',
    p_detalhes JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log(p_nivel, 'SEGURANCA', p_mensagem, p_detalhes);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log de Banco de Dados
CREATE OR REPLACE FUNCTION public.log_banco(
    p_mensagem TEXT,
    p_nivel VARCHAR DEFAULT 'INFO',
    p_detalhes JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log(p_nivel, 'BANCO_DADOS', p_mensagem, p_detalhes);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log de Usuário
CREATE OR REPLACE FUNCTION public.log_usuario(
    p_mensagem TEXT,
    p_id_usuario UUID DEFAULT NULL,
    p_nivel VARCHAR DEFAULT 'INFO',
    p_detalhes JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log(p_nivel, 'USUARIO', p_mensagem, p_detalhes);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log de API
CREATE OR REPLACE FUNCTION public.log_api(
    p_mensagem TEXT,
    p_nivel VARCHAR DEFAULT 'INFO',
    p_detalhes JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
    RETURN public.registrar_log(p_nivel, 'API', p_mensagem, p_detalhes);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. FUNÇÃO PARA CONSULTAR LOGS
-- =====================================================
-- Descrição: Consulta logs com filtros avançados
-- =====================================================

CREATE OR REPLACE FUNCTION public.consultar_logs(
    p_data_inicio TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '7 days',
    p_data_fim TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    p_nivel VARCHAR DEFAULT NULL,
    p_categoria VARCHAR DEFAULT NULL,
    p_usuario_id UUID DEFAULT NULL,
    p_busca TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id_log INTEGER,
    usuario_matricula VARCHAR,
    usuario_nome VARCHAR,
    nivel VARCHAR,
    categoria VARCHAR,
    mensagem TEXT,
    detalhes JSONB,
    ip_origem VARCHAR,
    data_hora TIMESTAMP WITH TIME ZONE,
    id_entidade INTEGER,
    tipo_entidade VARCHAR,
    origem VARCHAR
) AS $$
BEGIN
    -- Verificar permissão (apenas usuários com nível >= 7)
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 7
    ) THEN
        RAISE EXCEPTION 'Usuário sem permissão para consultar logs (nível necessário: 7)';
    END IF;
    
    RETURN QUERY
    SELECT 
        l.id_log,
        u.matricula AS usuario_matricula,
        u.nome_completo AS usuario_nome,
        l.nivel,
        l.categoria,
        l.mensagem,
        l.detalhes,
        l.ip_origem,
        l.data_hora,
        l.id_entidade,
        l.tipo_entidade,
        l.origem
    FROM public.logs_detalhados l
    LEFT JOIN public.usuarios u ON l.id_usuario = u.id
    WHERE l.data_hora BETWEEN p_data_inicio AND p_data_fim
      AND (p_nivel IS NULL OR l.nivel = p_nivel)
      AND (p_categoria IS NULL OR l.categoria = p_categoria)
      AND (p_usuario_id IS NULL OR l.id_usuario = p_usuario_id)
      AND (p_busca IS NULL OR l.mensagem ILIKE '%' || p_busca || '%')
    ORDER BY l.data_hora DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. VIEW DE ESTATÍSTICAS DE LOGS
-- =====================================================
-- Descrição: Estatísticas de logs por nível e categoria
-- =====================================================

CREATE OR REPLACE VIEW public.vw_estatisticas_logs AS
SELECT 
    DATE(data_hora) AS data,
    nivel,
    categoria,
    COUNT(*) AS total_logs,
    COUNT(DISTINCT id_usuario) AS usuarios_afetados
FROM public.logs_detalhados
WHERE data_hora >= NOW() - INTERVAL '30 days'
GROUP BY DATE(data_hora), nivel, categoria
ORDER BY data DESC, nivel;

-- =====================================================
-- 8. FUNÇÃO PARA LIMPAR LOGS ANTIGOS
-- =====================================================
-- Descrição: Remove logs mais antigos que o período especificado
-- =====================================================

CREATE OR REPLACE FUNCTION public.limpar_logs(
    p_dias INTEGER DEFAULT 30,
    p_nivel VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_removidos INTEGER;
    v_usuario_id UUID;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    -- Verificar permissão (apenas administradores)
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = v_usuario_id AND (p.is_master = TRUE OR p.nome = 'ADMINISTRADOR')
    ) THEN
        RAISE EXCEPTION 'Usuário sem permissão para limpar logs';
    END IF;
    
    -- Remover logs antigos
    WITH deletados AS (
        DELETE FROM public.logs_detalhados
        WHERE data_hora < NOW() - (p_dias || ' days')::INTERVAL
        AND (p_nivel IS NULL OR nivel = p_nivel)
        RETURNING id_log
    )
    SELECT COUNT(*) INTO v_removidos FROM deletados;
    
    -- Registrar ação
    PERFORM public.registrar_auditoria(
        'LIMPAR_LOGS',
        'logs_detalhados',
        NULL,
        NULL,
        jsonb_build_object(
            'dias', p_dias,
            'nivel', p_nivel,
            'removidos', v_removidos
        )
    );
    
    RETURN v_removidos;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 9. TRIGGER PARA LOGS DE ALTERAÇÃO DE SENHA
-- =====================================================
-- Descrição: Registra alterações de senha automaticamente
-- =====================================================

CREATE OR REPLACE FUNCTION public.log_alteracao_senha()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.senha_hash IS DISTINCT FROM NEW.senha_hash THEN
        PERFORM public.log_seguranca(
            'Alteração de senha do usuário ' || NEW.nome_completo,
            'INFO',
            jsonb_build_object(
                'usuario_id', NEW.id,
                'matricula', NEW.matricula,
                'data_alteracao', NOW()
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 10. TRIGGER PARA LOGS DE ACESSO
-- =====================================================
-- Descrição: Registra acessos ao sistema
-- =====================================================

CREATE OR REPLACE FUNCTION public.log_acesso_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.data_ultimo_acesso IS DISTINCT FROM OLD.data_ultimo_acesso THEN
        PERFORM public.log_seguranca(
            'Acesso do usuário ' || NEW.nome_completo,
            'INFO',
            jsonb_build_object(
                'usuario_id', NEW.id,
                'matricula', NEW.matricula,
                'data_acesso', NEW.data_ultimo_acesso,
                'ip', current_setting('request.headers', TRUE)::json->>'x-forwarded-for'
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 11. APLICAR TRIGGERS (OPCIONAL)
-- =====================================================

-- CREATE TRIGGER log_alteracao_senha_trigger
-- AFTER UPDATE ON public.usuarios
-- FOR EACH ROW
-- EXECUTE FUNCTION public.log_alteracao_senha();

-- CREATE TRIGGER log_acesso_usuario_trigger
-- AFTER UPDATE ON public.usuarios
-- FOR EACH ROW
-- EXECUTE FUNCTION public.log_acesso_usuario();

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ LOGGING AVANÇADO CONFIGURADO' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Itens criados:' ;
    RAISE NOTICE '   - Tabela: logs_detalhados' ;
    RAISE NOTICE '   - Função: registrar_log' ;
    RAISE NOTICE '   - Função: log_debug' ;
    RAISE NOTICE '   - Função: log_info' ;
    RAISE NOTICE '   - Função: log_warning' ;
    RAISE NOTICE '   - Função: log_error' ;
    RAISE NOTICE '   - Função: log_critical' ;
    RAISE NOTICE '   - Função: log_seguranca' ;
    RAISE NOTICE '   - Função: log_banco' ;
    RAISE NOTICE '   - Função: log_usuario' ;
    RAISE NOTICE '   - Função: log_api' ;
    RAISE NOTICE '   - Função: consultar_logs' ;
    RAISE NOTICE '   - Função: limpar_logs' ;
    RAISE NOTICE '   - View: vw_estatisticas_logs' ;
    RAISE NOTICE '   - Triggers: log_alteracao_senha' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🎉 FASE 2 CONCLUÍDA COM SUCESSO!' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
