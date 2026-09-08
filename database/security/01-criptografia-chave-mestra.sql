-- =====================================================
-- AI-DEPOM - FASE 2: CRIPTOGRAFIA
-- =====================================================
-- Caminho: database/security/01-criptografia-chave-mestra.sql
-- Data: 08/09/2026 - 14:30
-- Versão: 1.0.0
-- Descrição: Criação da chave mestra e funções de criptografia
-- =====================================================

-- =====================================================
-- 1. HABILITAR EXTENSÃO pgcrypto
-- =====================================================
-- Descrição: Habilita funções de criptografia
-- =====================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- 2. CRIAR TABELA DE CHAVES DE CRIPTOGRAFIA
-- =====================================================
-- Descrição: Armazena as chaves de criptografia do sistema
-- Campos: id_chave, nome, chave, data_criacao, ativo, deletado
-- =====================================================

CREATE TABLE public.chaves_criptografia (
    id_chave SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    chave BYTEA NOT NULL,
    data_criacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ativo BOOLEAN DEFAULT TRUE,
    deletado BOOLEAN DEFAULT FALSE
);

-- =====================================================
-- 3. INSERIR CHAVE MESTRA
-- =====================================================
-- Descrição: Chave AES-256 para criptografar dados sensíveis
-- ATENÇÃO: A chave abaixo é um exemplo. Gere uma chave REAL no seu banco.
-- Para gerar uma chave aleatória, execute:
-- SELECT gen_random_bytes(32);
-- =====================================================

INSERT INTO public.chaves_criptografia (nome, chave)
VALUES (
    'CHAVE_MESTRA_CPF',
    decode('SUA_CHAVE_HEX_32_BYTES_AQUI', 'hex')
);

-- =====================================================
-- 4. FUNÇÃO: criptografar_dado
-- =====================================================
-- Descrição: Criptografa dados usando AES-256-CBC
-- Parâmetros: p_dado (TEXT) - dado a ser criptografado
--             p_chave (BYTEA) - chave de criptografia
-- Retorno: TEXT - dado criptografado em hexadecimal
-- =====================================================

CREATE OR REPLACE FUNCTION public.criptografar_dado(
    p_dado TEXT,
    p_chave BYTEA
)
RETURNS TEXT AS $$
BEGIN
    IF p_dado IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN encode(
        encrypt(
            convert_to(p_dado, 'UTF8'),
            p_chave,
            'aes-256-cbc'
        ),
        'hex'
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNÇÃO: descriptografar_dado
-- =====================================================
-- Descrição: Descriptografa dados usando AES-256-CBC
-- Parâmetros: p_dado_criptografado (TEXT) - dado criptografado
--             p_chave (BYTEA) - chave de criptografia
-- Retorno: TEXT - dado descriptografado
-- =====================================================

CREATE OR REPLACE FUNCTION public.descriptografar_dado(
    p_dado_criptografado TEXT,
    p_chave BYTEA
)
RETURNS TEXT AS $$
BEGIN
    IF p_dado_criptografado IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN convert_from(
        decrypt(
            decode(p_dado_criptografado, 'hex'),
            p_chave,
            'aes-256-cbc'
        ),
        'UTF8'
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNÇÃO: obter_chave_mestra
-- =====================================================
-- Descrição: Retorna a chave mestra ativa
-- Retorno: BYTEA - chave mestra
-- =====================================================

CREATE OR REPLACE FUNCTION public.obter_chave_mestra()
RETURNS BYTEA AS $$
DECLARE
    v_chave BYTEA;
BEGIN
    SELECT chave INTO v_chave
    FROM public.chaves_criptografia
    WHERE nome = 'CHAVE_MESTRA_CPF' AND ativo = TRUE AND deletado = FALSE
    LIMIT 1;
    
    IF v_chave IS NULL THEN
        RAISE EXCEPTION 'Chave mestra não encontrada ou inativa';
    END IF;
    
    RETURN v_chave;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. TESTE DAS FUNÇÕES
-- =====================================================
-- Descrição: Valida o funcionamento da criptografia
-- =====================================================

DO $$
DECLARE
    v_chave BYTEA;
    v_dado_original TEXT;
    v_dado_criptografado TEXT;
    v_dado_descriptografado TEXT;
BEGIN
    -- Buscar chave
    v_chave := public.obter_chave_mestra();
    
    -- Testar com um CPF exemplo
    v_dado_original := '123.456.789-00';
    RAISE NOTICE '📌 Dado original: %', v_dado_original;
    
    -- Criptografar
    v_dado_criptografado := public.criptografar_dado(v_dado_original, v_chave);
    RAISE NOTICE '🔒 Dado criptografado: %', v_dado_criptografado;
    
    -- Descriptografar
    v_dado_descriptografado := public.descriptografar_dado(v_dado_criptografado, v_chave);
    RAISE NOTICE '🔓 Dado descriptografado: %', v_dado_descriptografado;
    
    -- Verificar
    IF v_dado_original = v_dado_descriptografado THEN
        RAISE NOTICE '✅ TESTE DE CRIPTOGRAFIA PASSADO!';
    ELSE
        RAISE NOTICE '❌ TESTE DE CRIPTOGRAFIA FALHOU!';
    END IF;
END;
$$;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ CHAVE MESTRA CRIADA COM SUCESSO' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Itens criados:' ;
    RAISE NOTICE '   - Tabela: chaves_criptografia' ;
    RAISE NOTICE '   - Função: criptografar_dado' ;
    RAISE NOTICE '   - Função: descriptografar_dado' ;
    RAISE NOTICE '   - Função: obter_chave_mestra' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔐 Próximo passo: Adicionar colunas criptografadas' ;
    RAISE NOTICE '   na tabela suspeito' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
