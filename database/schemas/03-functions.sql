-- =====================================================
-- AI-DEPOM - BANCO DE DADOS POLICIAL
-- 03-functions.sql - FUNÇÕES E PROCEDURES
-- =====================================================
-- Data: 04/09/2026
-- Versão: 1.0.0
-- Banco: Supabase (PostgreSQL 15+)
-- Descrição: Funções de validação, segurança e utilitários
-- =====================================================

-- =====================================================
-- FUNÇÃO 1: validar_email
-- =====================================================
-- Descrição: Valida formato de email
-- Parâmetros: p_email (TEXT)
-- Retorno: BOOLEAN
-- Uso: Validação de cadastro de usuários
-- =====================================================

CREATE OR REPLACE FUNCTION public.validar_email(p_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Verifica formato básico de email
    -- Exemplo: usuario@dominio.com
    RETURN p_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- FUNÇÃO 2: prevent_physical_delete
-- =====================================================
-- Descrição: Impede deleção física de registros
-- Uso: Trigger BEFORE DELETE em todas as tabelas
-- Mensagem: Orienta sobre exclusão lógica
-- =====================================================

CREATE OR REPLACE FUNCTION public.prevent_physical_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION '🚫 Não é permitido deletar registros fisicamente. Use a flag "deletado" para exclusão lógica.';
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNÇÃO 3: get_usuario_perfil
-- =====================================================
-- Descrição: Obtém o perfil do usuário logado
-- Retorno: Tabela com id, perfil_nome, nivel_acesso, is_master
-- Uso: Políticas de RLS, verificações de segurança
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_usuario_perfil()
RETURNS TABLE(
    usuario_id UUID,
    perfil_nome VARCHAR,
    nivel_acesso INTEGER,
    is_master BOOLEAN,
    pode_gerenciar_usuarios BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        p.nome,
        p.nivel_acesso,
        p.is_master,
        p.pode_gerenciar_usuarios
    FROM public.usuarios u
    INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
    WHERE u.id = auth.uid() 
      AND u.ativo = TRUE 
      AND u.deletado = FALSE;
END;
$$;

-- =====================================================
-- FUNÇÃO 4: cadastrar_usuario
-- =====================================================
-- Descrição: Cadastra um novo usuário no sistema
-- Regras: Apenas ADMINISTRADOR_MASTER pode executar
--          Valida email e matrícula
--          Gera senha temporária
-- =====================================================

CREATE OR REPLACE FUNCTION public.cadastrar_usuario(
    p_matricula VARCHAR,
    p_nome_completo VARCHAR,
    p_email VARCHAR,
    p_setor VARCHAR,
    p_id_perfil_acesso INTEGER,
    p_id_delegacia INTEGER DEFAULT NULL,
    p_id_usuario_cadastrador UUID
)
RETURNS JSONB AS $$
DECLARE
    v_is_master BOOLEAN;
    v_id_usuario UUID;
    v_salt VARCHAR(64);
    v_senha_temporaria VARCHAR(20);
    v_resultado JSONB;
BEGIN
    -- 1. VERIFICAR SE O USUÁRIO CADASTRADOR É MASTER
    SELECT p.is_master
    INTO v_is_master
    FROM public.usuarios u
    INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
    WHERE u.id = p_id_usuario_cadastrador
    AND u.deletado = FALSE
    AND u.ativo = TRUE;

    IF v_is_master IS NULL OR v_is_master = FALSE THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Apenas o Administrador Master pode cadastrar novos usuários'
        );
    END IF;

    -- 2. VALIDAR EMAIL
    IF NOT public.validar_email(p_email) THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Email inválido. Use um formato válido (ex: usuario@dominio.com)'
        );
    END IF;

    -- 3. VERIFICAR SE MATRÍCULA OU EMAIL JÁ EXISTEM
    IF EXISTS (SELECT 1 FROM public.usuarios WHERE matricula = p_matricula AND deletado = FALSE) THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Matrícula já cadastrada no sistema'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM public.usuarios WHERE email = p_email AND deletado = FALSE) THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Email já cadastrado no sistema'
        );
    END IF;

    -- 4. GERAR SENHA TEMPORÁRIA
    v_senha_temporaria := 'Temp@' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || LPAD(floor(random() * 10000)::TEXT, 4, '0');
    
    -- 5. GERAR SALT
    v_salt := encode(gen_random_bytes(32), 'hex');

    -- 6. INSERIR USUÁRIO NO AUTH
    -- Nota: O usuário deve ser criado primeiro no auth.users
    -- Esta função retorna o ID para vincular à tabela usuarios
    
    -- 7. INSERIR NA TABELA USUARIOS
    INSERT INTO public.usuarios (
        matricula,
        nome_completo,
        email,
        setor,
        id_perfil_acesso,
        id_delegacia,
        ativo,
        primeiro_acesso,
        id_usuario_cadastrador,
        data_cadastro_usuario
    ) VALUES (
        p_matricula,
        p_nome_completo,
        p_email,
        p_setor,
        p_id_perfil_acesso,
        p_id_delegacia,
        TRUE,
        TRUE,
        p_id_usuario_cadastrador,
        NOW()
    ) RETURNING id INTO v_id_usuario;

    -- 8. REGISTRAR LOG DE CADASTRO
    INSERT INTO public.log_cadastro_usuario (
        id_usuario_cadastrador,
        id_usuario_cadastrado,
        acao,
        dados_novos,
        ip_origem,
        sucesso
    ) VALUES (
        p_id_usuario_cadastrador,
        v_id_usuario,
        'CADASTRO',
        jsonb_build_object(
            'matricula', p_matricula,
            'nome_completo', p_nome_completo,
            'email', p_email,
            'setor', p_setor,
            'perfil_id', p_id_perfil_acesso
        ),
        current_setting('request.headers', TRUE)::json->>'x-forwarded-for',
        TRUE
    );

    -- 9. RETORNAR SUCESSO COM SENHA TEMPORÁRIA
    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Usuário cadastrado com sucesso!',
        'id_usuario', v_id_usuario,
        'matricula', p_matricula,
        'senha_temporaria', v_senha_temporaria,
        'primeiro_acesso', TRUE
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Registrar erro no log
        INSERT INTO public.log_cadastro_usuario (
            id_usuario_cadastrador,
            acao,
            dados_novos,
            ip_origem,
            sucesso,
            mensagem_erro
        ) VALUES (
            p_id_usuario_cadastrador,
            'CADASTRO',
            jsonb_build_object(
                'matricula', p_matricula,
                'email', p_email,
                'erro', SQLERRM
            ),
            current_setting('request.headers', TRUE)::json->>'x-forwarded-for',
            FALSE,
            SQLERRM
        );
        
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Erro ao cadastrar usuário: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNÇÃO 5: log_auditoria_insert
-- =====================================================
-- Descrição: Trigger para registrar INSERT nas tabelas
-- Uso: Audit logs automáticos
-- =====================================================

CREATE OR REPLACE FUNCTION public.log_auditoria_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_id_registro INTEGER;
BEGIN
    -- Determinar o ID do registro baseado na tabela
    IF TG_TABLE_NAME = 'suspeito' THEN
        v_id_registro := NEW.id_suspeito;
    ELSIF TG_TABLE_NAME = 'investigacao' THEN
        v_id_registro := NEW.id_investigacao;
    ELSIF TG_TABLE_NAME = 'mandado_prisao' THEN
        v_id_registro := NEW.id_mandado;
    ELSIF TG_TABLE_NAME = 'ocorrencia' THEN
        v_id_registro := NEW.id_ocorrencia;
    ELSIF TG_TABLE_NAME = 'arquivo_midia' THEN
        v_id_registro := NEW.id_arquivo;
    ELSE
        v_id_registro := 0;
    END IF;

    -- Inserir log
    INSERT INTO public.log_auditoria (
        id_usuario,
        acao,
        tabela,
        id_registro,
        dados_novos,
        ip_origem,
        user_agent,
        sucesso
    ) VALUES (
        auth.uid(),
        'INSERT',
        TG_TABLE_NAME,
        v_id_registro,
        to_jsonb(NEW),
        COALESCE(current_setting('request.headers', TRUE)::json->>'x-forwarded-for', '127.0.0.1'),
        COALESCE(current_setting('request.headers', TRUE)::json->>'user-agent', 'unknown'),
        TRUE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNÇÃO 6: log_auditoria_update
-- =====================================================
-- Descrição: Trigger para registrar UPDATE nas tabelas
-- Uso: Audit logs automáticos
-- =====================================================

CREATE OR REPLACE FUNCTION public.log_auditoria_update()
RETURNS TRIGGER AS $$
DECLARE
    v_id_registro INTEGER;
BEGIN
    -- Determinar o ID do registro baseado na tabela
    IF TG_TABLE_NAME = 'suspeito' THEN
        v_id_registro := OLD.id_suspeito;
    ELSIF TG_TABLE_NAME = 'investigacao' THEN
        v_id_registro := OLD.id_investigacao;
    ELSIF TG_TABLE_NAME = 'mandado_prisao' THEN
        v_id_registro := OLD.id_mandado;
    ELSIF TG_TABLE_NAME = 'ocorrencia' THEN
        v_id_registro := OLD.id_ocorrencia;
    ELSIF TG_TABLE_NAME = 'arquivo_midia' THEN
        v_id_registro := OLD.id_arquivo;
    ELSE
        v_id_registro := 0;
    END IF;

    -- Inserir log
    INSERT INTO public.log_auditoria (
        id_usuario,
        acao,
        tabela,
        id_registro,
        dados_anteriores,
        dados_novos,
        ip_origem,
        user_agent,
        sucesso
    ) VALUES (
        auth.uid(),
        'UPDATE',
        TG_TABLE_NAME,
        v_id_registro,
        to_jsonb(OLD),
        to_jsonb(NEW),
        COALESCE(current_setting('request.headers', TRUE)::json->>'x-forwarded-for', '127.0.0.1'),
        COALESCE(current_setting('request.headers', TRUE)::json->>'user-agent', 'unknown'),
        TRUE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNÇÃO 7: deletar_logicamente
-- =====================================================
-- Descrição: Realiza exclusão lógica de registros
-- Parâmetros: p_tabela (VARCHAR), p_id (INTEGER)
-- Uso: Substitui DELETE físico por flag deletado = TRUE
-- =====================================================

CREATE OR REPLACE FUNCTION public.deletar_logicamente(
    p_tabela VARCHAR,
    p_id INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_query TEXT;
    v_usuario_id UUID;
BEGIN
    -- Obter ID do usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Usuário não autenticado'
        );
    END IF;

    -- Construir query dinâmica
    v_query := format('
        UPDATE public.%I 
        SET deletado = TRUE, 
            data_atualizacao = NOW(),
            id_usuario_atualizacao = %L
        WHERE id_%I = %L
    ', p_tabela, v_usuario_id, lower(p_tabela), p_id);

    -- Executar query
    EXECUTE v_query;

    -- Registrar no log
    INSERT INTO public.log_auditoria (
        id_usuario,
        acao,
        tabela,
        id_registro,
        dados_novos,
        ip_origem,
        sucesso
    ) VALUES (
        v_usuario_id,
        'DELETE_LOGICO',
        p_tabela,
        p_id,
        jsonb_build_object('deletado', TRUE, 'data_deletado', NOW()),
        COALESCE(current_setting('request.headers', TRUE)::json->>'x-forwarded-for', '127.0.0.1'),
        TRUE
    );

    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Registro deletado logicamente com sucesso',
        'tabela', p_tabela,
        'id', p_id,
        'usuario', v_usuario_id,
        'data', NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Erro ao deletar logicamente: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNÇÃO 8: gerar_numero_mandado
-- =====================================================
-- Descrição: Gera número de mandado automático
-- Formato: MP-YYYY-XXX
-- =====================================================

CREATE OR REPLACE FUNCTION public.gerar_numero_mandado()
RETURNS VARCHAR AS $$
DECLARE
    v_ano VARCHAR(4);
    v_sequencia INTEGER;
    v_numero VARCHAR(30);
BEGIN
    v_ano := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SPLIT_PART(numero_mandado, '-', 3) AS INTEGER)), 0) + 1
    INTO v_sequencia
    FROM public.mandado_prisao
    WHERE numero_mandado LIKE 'MP-' || v_ano || '-%';
    
    v_numero := 'MP-' || v_ano || '-' || LPAD(v_sequencia::VARCHAR, 3, '0');
    
    RETURN v_numero;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNÇÃO 9: gerar_numero_inquerito
-- =====================================================
-- Descrição: Gera número de inquérito automático
-- Formato: YYYY/XXX-PF
-- =====================================================

CREATE OR REPLACE FUNCTION public.gerar_numero_inquerito()
RETURNS VARCHAR AS $$
DECLARE
    v_ano VARCHAR(4);
    v_sequencia INTEGER;
    v_numero VARCHAR(30);
BEGIN
    v_ano := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SPLIT_PART(numero_inquerito, '/', 1) AS INTEGER)), 0) + 1
    INTO v_sequencia
    FROM public.investigacao
    WHERE numero_inquerito LIKE '%/' || v_ano || '-PF';
    
    v_numero := LPAD(v_sequencia::VARCHAR, 3, '0') || '/' || v_ano || '-PF';
    
    RETURN v_numero;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ FUNÇÕES CRIADAS COM SUCESSO' ;
    RAISE NOTICE '📊 Total de funções: 9' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '1. validar_email' ;
    RAISE NOTICE '2. prevent_physical_delete' ;
    RAISE NOTICE '3. get_usuario_perfil' ;
    RAISE NOTICE '4. cadastrar_usuario' ;
    RAISE NOTICE '5. log_auditoria_insert' ;
    RAISE NOTICE '6. log_auditoria_update' ;
    RAISE NOTICE '7. deletar_logicamente' ;
    RAISE NOTICE '8. gerar_numero_mandado' ;
    RAISE NOTICE '9. gerar_numero_inquerito' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
