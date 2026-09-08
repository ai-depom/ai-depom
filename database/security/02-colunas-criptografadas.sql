-- =====================================================
-- AI-DEPOM - FASE 2: CRIPTOGRAFIA DE COLUNAS
-- =====================================================
-- Caminho: database/security/02-colunas-criptografadas.sql
-- Data: 08/09/2026 - 14:45
-- Versão: 1.0.0
-- Descrição: Adiciona colunas criptografadas na tabela suspeito
-- =====================================================

-- =====================================================
-- 1. ADICIONAR COLUNAS CRIPTOGRAFADAS
-- =====================================================
-- Descrição: Adiciona colunas para armazenar dados criptografados
-- =====================================================

ALTER TABLE public.suspeito 
ADD COLUMN IF NOT EXISTS cpf_criptografado TEXT,
ADD COLUMN IF NOT EXISTS rg_criptografado TEXT,
ADD COLUMN IF NOT EXISTS biometria_criptografada TEXT;

-- =====================================================
-- 2. MIGRAR DADOS EXISTENTES
-- =====================================================
-- Descrição: Criptografa dados existentes na tabela suspeito
-- ATENÇÃO: Execute apenas quando houver dados reais
-- =====================================================

DO $$
DECLARE
    v_chave BYTEA;
BEGIN
    -- Obter chave mestra
    v_chave := public.obter_chave_mestra();
    
    -- Migrar CPF
    UPDATE public.suspeito
    SET cpf_criptografado = public.criptografar_dado(cpf, v_chave)
    WHERE cpf IS NOT NULL AND cpf_criptografado IS NULL;
    
    -- Migrar RG
    UPDATE public.suspeito
    SET rg_criptografado = public.criptografar_dado(rg, v_chave)
    WHERE rg IS NOT NULL AND rg_criptografado IS NULL;
    
    -- Migrar Biometria
    UPDATE public.suspeito
    SET biometria_criptografada = public.criptografar_dado(biometria_hash, v_chave)
    WHERE biometria_hash IS NOT NULL AND biometria_criptografada IS NULL;
    
    RAISE NOTICE '✅ Dados migrados com sucesso!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Erro na migração: %', SQLERRM;
END;
$$;

-- =====================================================
-- 3. TRIGGER: CRIPTOGRAFIA AUTOMÁTICA EM INSERT/UPDATE
-- =====================================================
-- Descrição: Criptografa automaticamente dados ao inserir ou atualizar
-- =====================================================

CREATE OR REPLACE FUNCTION public.criptografar_suspeito()
RETURNS TRIGGER AS $$
DECLARE
    v_chave BYTEA;
BEGIN
    -- Obter chave mestra
    v_chave := public.obter_chave_mestra();
    
    -- Criptografar CPF se fornecido
    IF NEW.cpf IS NOT NULL THEN
        NEW.cpf_criptografado := public.criptografar_dado(NEW.cpf, v_chave);
        NEW.cpf := NULL; -- Remover dado original
    END IF;

    -- Criptografar RG se fornecido
    IF NEW.rg IS NOT NULL THEN
        NEW.rg_criptografado := public.criptografar_dado(NEW.rg, v_chave);
        NEW.rg := NULL; -- Remover dado original
    END IF;

    -- Criptografar biometria se fornecida
    IF NEW.biometria_hash IS NOT NULL THEN
        NEW.biometria_criptografada := public.criptografar_dado(NEW.biometria_hash, v_chave);
        NEW.biometria_hash := NULL; -- Remover dado original
    END IF;

    -- Garantir que o campo nome_completo nunca seja criptografado
    IF NEW.nome_completo IS NULL THEN
        RAISE EXCEPTION 'Campo nome_completo é obrigatório';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. APLICAR TRIGGER
-- =====================================================

DROP TRIGGER IF EXISTS criptografar_suspeito_trigger ON public.suspeito;

CREATE TRIGGER criptografar_suspeito_trigger
BEFORE INSERT OR UPDATE ON public.suspeito
FOR EACH ROW
EXECUTE FUNCTION public.criptografar_suspeito();

-- =====================================================
-- 5. FUNÇÃO PARA DESCRIPTOGRAFAR DADOS
-- =====================================================
-- Descrição: Função segura para descriptografar dados
-- Verifica se o usuário tem permissão para acessar dados sensíveis
-- =====================================================

CREATE OR REPLACE FUNCTION public.descriptografar_suspeito(
    p_id_suspeito INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_chave BYTEA;
    v_usuario_id UUID;
    v_nivel_acesso INTEGER;
    v_resultado JSONB;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Usuário não autenticado';
    END IF;
    
    -- Verificar nível de acesso
    SELECT p.nivel_acesso INTO v_nivel_acesso
    FROM public.usuarios u
    INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
    WHERE u.id = v_usuario_id AND u.ativo = TRUE AND u.deletado = FALSE;
    
    IF v_nivel_acesso IS NULL THEN
        RAISE EXCEPTION 'Usuário não possui permissão de acesso';
    END IF;
    
    -- Verificar se tem permissão para acessar dados sensíveis (nível >= 7)
    IF v_nivel_acesso < 7 THEN
        RAISE EXCEPTION 'Usuário sem permissão para acessar dados sensíveis (nível necessário: 7)';
    END IF;
    
    -- Obter chave mestra
    v_chave := public.obter_chave_mestra();
    
    -- Buscar e descriptografar dados
    SELECT jsonb_build_object(
        'id_suspeito', s.id_suspeito,
        'nome_completo', s.nome_completo,
        'apelido', s.apelido,
        'cpf', public.descriptografar_dado(s.cpf_criptografado, v_chave),
        'rg', public.descriptografar_dado(s.rg_criptografado, v_chave),
        'biometria', public.descriptografar_dado(s.biometria_criptografada, v_chave),
        'data_nascimento', s.data_nascimento,
        'sexo', s.sexo,
        'status_atual', s.status_atual,
        'nivel_periculosidade', s.nivel_periculosidade,
        'cidade', s.cidade,
        'uf', s.uf
    ) INTO v_resultado
    FROM public.suspeito s
    WHERE s.id_suspeito = p_id_suspeito AND s.deletado = FALSE;
    
    -- Registrar log de acesso
    INSERT INTO public.logs_acesso (
        id_usuario,
        acao,
        tabela,
        id_registro,
        sucesso
    ) VALUES (
        v_usuario_id,
        'DESCRIPTOGRAFAR',
        'suspeito',
        p_id_suspeito,
        TRUE
    );
    
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. VIEW PARA EXIBIÇÃO SEGURA
-- =====================================================
-- Descrição: View que exibe dados mascarados para usuários sem permissão
-- =====================================================

CREATE OR REPLACE VIEW public.vw_suspeito_seguro AS
SELECT 
    s.id_suspeito,
    s.nome_completo,
    s.apelido,
    CASE 
        WHEN (SELECT p.nivel_acesso FROM public.usuarios u 
              INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil 
              WHERE u.id = auth.uid() AND u.ativo = TRUE) >= 7 
        THEN public.descriptografar_dado(s.cpf_criptografado, public.obter_chave_mestra())
        ELSE '***.***.***-**'
    END AS cpf,
    CASE 
        WHEN (SELECT p.nivel_acesso FROM public.usuarios u 
              INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil 
              WHERE u.id = auth.uid() AND u.ativo = TRUE) >= 7 
        THEN public.descriptografar_dado(s.rg_criptografado, public.obter_chave_mestra())
        ELSE '**.***.***-*'
    END AS rg,
    s.data_nascimento,
    s.sexo,
    s.status_atual,
    s.nivel_periculosidade,
    s.cidade,
    s.uf
FROM public.suspeito s
WHERE s.deletado = FALSE;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ COLUNAS CRIPTOGRAFADAS CRIADAS' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Itens criados:' ;
    RAISE NOTICE '   - Colunas: cpf_criptografado, rg_criptografado,' ;
    RAISE NOTICE '     biometria_criptografada' ;
    RAISE NOTICE '   - Trigger: criptografar_suspeito_trigger' ;
    RAISE NOTICE '   - Função: descriptografar_suspeito' ;
    RAISE NOTICE '   - View: vw_suspeito_seguro' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔐 Próximo passo: Configurar MFA/OTP' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
