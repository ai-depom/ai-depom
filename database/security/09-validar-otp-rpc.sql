-- ============================================================
-- AI-DEPOM - FUNÇÃO RPC PARA VALIDAR OTP
-- ============================================================
-- Caminho: database/security/09-validar-otp-rpc.sql
-- Versão: 1.0.0
-- Data: 08/09/2026
-- Horário: 23:00
-- Autor: Admin Master
-- ============================================================
-- DESCRIÇÃO:
-- Função RPC para validar OTP (One-Time Password) via chamada do frontend.
-- Permite que a tela de login verifique o código OTP digitado pelo usuário.
-- ============================================================
-- ALTERAÇÕES:
-- v1.0.0 - 08/09/2026 - 23:00 - Admin Master
--   - Criação inicial da função
--   - Verificação de secret do usuário
--   - Validação de formato do código
--   - Placeholder para validação real (substituir em produção)
--   - Registro de logs de erro
-- ============================================================

-- ============================================================
-- 1. FUNÇÃO: validar_otp_rpc
-- ============================================================
-- Descrição: Valida o código OTP para um usuário específico
-- Parâmetros:
--   p_usuario_id (UUID) - ID do usuário no Supabase Auth
--   p_codigo (TEXT) - Código OTP de 6 dígitos
-- Retorno: BOOLEAN - TRUE se válido, FALSE se inválido
-- ============================================================

CREATE OR REPLACE FUNCTION public.validar_otp_rpc(
    p_usuario_id UUID,
    p_codigo TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_secret TEXT;
    v_codigo_esperado TEXT;
    v_usuario RECORD;
BEGIN
    -- ============================================
    -- 1. BUSCAR O SECRET DO USUÁRIO
    -- ============================================
    -- Busca o secret OTP e outros dados do usuário
    SELECT 
        u.id,
        u.otp_secret,
        u.otp_habilitado,
        u.ativo,
        u.deletado,
        u.nome_completo,
        u.email
    INTO v_usuario
    FROM public.usuarios u
    WHERE u.id = p_usuario_id;
    
    -- ============================================
    -- 2. VALIDAR SE USUÁRIO EXISTE E ESTÁ ATIVO
    -- ============================================
    IF v_usuario.id IS NULL THEN
        -- Usuário não encontrado
        INSERT INTO public.logs_detalhados (
            nivel,
            categoria,
            mensagem,
            detalhes
        ) VALUES (
            'WARNING',
            'SEGURANCA',
            'Tentativa de validação OTP - Usuário não encontrado',
            jsonb_build_object(
                'usuario_id', p_usuario_id,
                'codigo', p_codigo
            )
        );
        RETURN FALSE;
    END IF;
    
    IF NOT v_usuario.ativo OR v_usuario.deletado THEN
        -- Usuário inativo ou deletado
        INSERT INTO public.logs_detalhados (
            nivel,
            categoria,
            mensagem,
            detalhes
        ) VALUES (
            'WARNING',
            'SEGURANCA',
            'Tentativa de validação OTP - Usuário inativo',
            jsonb_build_object(
                'usuario_id', p_usuario_id,
                'codigo', p_codigo
            )
        );
        RETURN FALSE;
    END IF;
    
    -- ============================================
    -- 3. VERIFICAR SE OTP ESTÁ CONFIGURADO
    -- ============================================
    IF NOT v_usuario.otp_habilitado THEN
        -- OTP não configurado
        INSERT INTO public.logs_detalhados (
            nivel,
            categoria,
            mensagem,
            detalhes
        ) VALUES (
            'INFO',
            'SEGURANCA',
            'Tentativa de validação OTP - OTP não configurado',
            jsonb_build_object(
                'usuario_id', p_usuario_id,
                'codigo', p_codigo,
                'nome', v_usuario.nome_completo
            )
        );
        RETURN FALSE;
    END IF;
    
    -- ============================================
    -- 4. VALIDAR FORMATO DO CÓDIGO
    -- ============================================
    IF p_codigo !~ '^\d{6}$' THEN
        -- Código não tem 6 dígitos
        INSERT INTO public.logs_detalhados (
            nivel,
            categoria,
            mensagem,
            detalhes
        ) VALUES (
            'WARNING',
            'SEGURANCA',
            'Tentativa de validação OTP - Código com formato inválido',
            jsonb_build_object(
                'usuario_id', p_usuario_id,
                'codigo', p_codigo,
                'nome', v_usuario.nome_completo
            )
        );
        RETURN FALSE;
    END IF;
    
    -- ============================================
    -- 5. NOTA: VALIDAÇÃO REAL DO OTP
    -- ============================================
    -- A validação real do OTP deve ser feita com uma biblioteca como 'otpauth' ou 'speakeasy'
    -- Como o PostgreSQL não tem suporte nativo para TOTP, esta função é um placeholder
    -- 
    -- PARA PRODUÇÃO, implemente uma das opções:
    --   a) Edge Function no Supabase (recomendado) - ver arquivo '10-edge-function-validar-otp.js'
    --   b) Web Service no Render - ver arquivo '11-webservice-validar-otp.js'
    --   c) Extensão PG com suporte a TOTP
    --
    -- A função abaixo aceita qualquer código de 6 dígitos para testes
    -- EM PRODUÇÃO: Substitua pela validação real com a biblioteca apropriada
    
    -- ============================================
    -- 6. PLACEHOLDER: ACEITAR QUALQUER CÓDIGO DE 6 DÍGITOS
    -- ============================================
    -- EM PRODUÇÃO, substitua este bloco pela validação real
    -- Apenas para testes e demonstração
    
    -- Simulação: qualquer código de 6 dígitos é válido
    -- Na prática, você deve calcular o código esperado com base no secret e no tempo atual
    
    -- ============================================
    -- 7. REGISTRAR LOG DE SUCESSO
    -- ============================================
    INSERT INTO public.logs_detalhados (
        id_usuario,
        nivel,
        categoria,
        mensagem,
        detalhes
    ) VALUES (
        p_usuario_id,
        'INFO',
        'SEGURANCA',
        'OTP validado com sucesso',
        jsonb_build_object(
            'usuario_id', p_usuario_id,
            'nome', v_usuario.nome_completo,
            'email', v_usuario.email
        )
    );
    
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        -- ============================================
        -- 8. REGISTRAR ERRO
        -- ============================================
        INSERT INTO public.logs_detalhados (
            nivel,
            categoria,
            mensagem,
            detalhes
        ) VALUES (
            'ERROR',
            'SEGURANCA',
            'Erro ao validar OTP: ' || SQLERRM,
            jsonb_build_object(
                'usuario_id', p_usuario_id,
                'codigo', p_codigo,
                'erro', SQLERRM,
                'sqlstate', SQLSTATE
            )
        );
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. FUNÇÃO: gerar_secret_otp (RPC)
-- ============================================================
-- Descrição: Gera um secret para OTP no formato base32
-- ============================================================

CREATE OR REPLACE FUNCTION public.gerar_secret_otp()
RETURNS TEXT AS $$
BEGIN
    -- Gerar secret no formato base32 (16 caracteres)
    -- Usar gen_random_bytes(10) para gerar 10 bytes aleatórios
    -- Codificar em base32 (que gera 16 caracteres)
    RETURN encode(gen_random_bytes(10), 'base32');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3. TESTAR AS FUNÇÕES
-- ============================================================

DO $$
DECLARE
    v_secret TEXT;
    v_resultado BOOLEAN;
BEGIN
    -- Testar geração de secret
    v_secret := public.gerar_secret_otp();
    RAISE NOTICE '✅ Secret gerado: %', v_secret;
    
    -- Testar validação (com um ID inválido para demonstração)
    -- v_resultado := public.validar_otp_rpc(
    --     '00000000-0000-0000-0000-000000000000',
    --     '123456'
    -- );
    -- RAISE NOTICE '✅ Resultado da validação: %', v_resultado;
    
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ FUNÇÕES CRIADAS COM SUCESSO';
    RAISE NOTICE '📅 Data: %', NOW();
    RAISE NOTICE '============================================';
    RAISE NOTICE '📋 Funções disponíveis:';
    RAISE NOTICE '   - validar_otp_rpc(UUID, TEXT) → BOOLEAN';
    RAISE NOTICE '   - gerar_secret_otp() → TEXT';
    RAISE NOTICE '============================================';
    RAISE NOTICE '⚠️ ATENÇÃO: A validação OTP é um PLACEHOLDER!';
    RAISE NOTICE '   Substituir em produção pela validação real.';
    RAISE NOTICE '============================================';
END;
$$;
