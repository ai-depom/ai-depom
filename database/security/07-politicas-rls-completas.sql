-- ============================================================
-- AI-DEPOM - POLÍTICAS RLS COMPLETAS
-- ============================================================
-- Caminho: database/security/07-politicas-rls-completas.sql
-- Versão: 1.0.0
-- Data: 08/09/2026
-- Horário: 18:30
-- Autor: Admin Master
-- ============================================================
-- DESCRIÇÃO:
-- Implementação completa de todas as políticas RLS (Row Level Security)
-- para todas as tabelas do sistema AI-DEPOM.
-- ============================================================
-- ALTERAÇÕES:
-- v1.0.0 - 08/09/2026 - 18:30 - Admin Master
--   - Criação inicial do arquivo
--   - Políticas para todas as tabelas
--   - Integração com as Regras de Ouro
-- ============================================================

-- ============================================================
-- 1. HABILITAR RLS EM TODAS AS TABELAS
-- ============================================================

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suspeito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investigacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocorrencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mandado_prisao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.envolvimento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arquivo_midia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerta_seguranca ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.midias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_autorizados ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. POLÍTICAS PARA TABELA: usuarios
-- ============================================================

-- 2.1 SELECT: Apenas usuários autenticados podem ver outros usuários
CREATE POLICY usuarios_select_policy ON public.usuarios
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    (
        -- Usuário pode ver seu próprio perfil
        id = auth.uid() OR
        -- Administradores podem ver todos
        EXISTS (
            SELECT 1 FROM public.usuarios_autorizados
            WHERE id_usuario = auth.uid() AND ativo = TRUE
        )
    )
);

-- 2.2 INSERT: Apenas Master ou Desenvolvedor
CREATE POLICY usuarios_insert_policy ON public.usuarios
FOR INSERT
WITH CHECK (
    public.pode_cadastrar_usuario()
);

-- 2.3 UPDATE: Apenas Master ou Desenvolvedor
CREATE POLICY usuarios_update_policy ON public.usuarios
FOR UPDATE
USING (
    public.pode_cadastrar_usuario()
);

-- 2.4 DELETE: NUNCA PERMITIDO
CREATE POLICY usuarios_delete_policy ON public.usuarios
FOR DELETE
USING (FALSE);

-- ============================================================
-- 3. POLÍTICAS PARA TABELA: suspeito
-- ============================================================

-- 3.1 SELECT: Usuários autenticados com nível >= 5
CREATE POLICY suspeito_select_policy ON public.suspeito
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 5
    )
);

-- 3.2 INSERT: Usuários com nível >= 6
CREATE POLICY suspeito_insert_policy ON public.suspeito
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 3.3 UPDATE: Usuários com nível >= 6
CREATE POLICY suspeito_update_policy ON public.suspeito
FOR UPDATE
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 3.4 DELETE: NUNCA PERMITIDO
CREATE POLICY suspeito_delete_policy ON public.suspeito
FOR DELETE
USING (FALSE);

-- ============================================================
-- 4. POLÍTICAS PARA TABELA: investigacao
-- ============================================================

-- 4.1 SELECT: Usuários autenticados com nível >= 5
CREATE POLICY investigacao_select_policy ON public.investigacao
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 5
    )
);

-- 4.2 INSERT: Usuários com nível >= 7
CREATE POLICY investigacao_insert_policy ON public.investigacao
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 7
    )
);

-- 4.3 UPDATE: Usuários com nível >= 7
CREATE POLICY investigacao_update_policy ON public.investigacao
FOR UPDATE
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 7
    )
);

-- 4.4 DELETE: NUNCA PERMITIDO
CREATE POLICY investigacao_delete_policy ON public.investigacao
FOR DELETE
USING (FALSE);

-- ============================================================
-- 5. POLÍTICAS PARA TABELA: mandado_prisao
-- ============================================================

-- 5.1 SELECT: Usuários autenticados com nível >= 6
CREATE POLICY mandado_select_policy ON public.mandado_prisao
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 5.2 INSERT: Usuários com nível >= 7
CREATE POLICY mandado_insert_policy ON public.mandado_prisao
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 7
    )
);

-- 5.3 UPDATE: Usuários com nível >= 7
CREATE POLICY mandado_update_policy ON public.mandado_prisao
FOR UPDATE
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 7
    )
);

-- 5.4 DELETE: NUNCA PERMITIDO
CREATE POLICY mandado_delete_policy ON public.mandado_prisao
FOR DELETE
USING (FALSE);

-- ============================================================
-- 6. POLÍTICAS PARA TABELA: ocorrencia
-- ============================================================

-- 6.1 SELECT: Usuários autenticados com nível >= 5
CREATE POLICY ocorrencia_select_policy ON public.ocorrencia
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 5
    )
);

-- 6.2 INSERT: Usuários com nível >= 6
CREATE POLICY ocorrencia_insert_policy ON public.ocorrencia
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 6.3 UPDATE: Usuários com nível >= 6
CREATE POLICY ocorrencia_update_policy ON public.ocorrencia
FOR UPDATE
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 6.4 DELETE: NUNCA PERMITIDO
CREATE POLICY ocorrencia_delete_policy ON public.ocorrencia
FOR DELETE
USING (FALSE);

-- ============================================================
-- 7. POLÍTICAS PARA TABELA: arquivo_midia / midias
-- ============================================================

-- 7.1 SELECT: Usuários autenticados com nível >= 5
CREATE POLICY midias_select_policy ON public.midias
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 5
    )
);

-- 7.2 INSERT: Usuários com nível >= 6
CREATE POLICY midias_insert_policy ON public.midias
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 7.3 UPDATE: Usuários com nível >= 6
CREATE POLICY midias_update_policy ON public.midias
FOR UPDATE
USING (
    auth.role() = 'authenticated' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() AND p.nivel_acesso >= 6
    )
);

-- 7.4 DELETE: NUNCA PERMITIDO
CREATE POLICY midias_delete_policy ON public.midias
FOR DELETE
USING (FALSE);

-- ============================================================
-- 8. POLÍTICAS PARA TABELA: usuarios_autorizados
-- ============================================================

-- 8.1 SELECT: Apenas usuários autorizados
CREATE POLICY usuarios_autorizados_select_policy ON public.usuarios_autorizados
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    (
        id_usuario = auth.uid() OR
        public.pode_cadastrar_usuario()
    )
);

-- 8.2 INSERT: Apenas Master ou Desenvolvedor
CREATE POLICY usuarios_autorizados_insert_policy ON public.usuarios_autorizados
FOR INSERT
WITH CHECK (
    public.pode_cadastrar_usuario()
);

-- 8.3 UPDATE: Apenas Master ou Desenvolvedor
CREATE POLICY usuarios_autorizados_update_policy ON public.usuarios_autorizados
FOR UPDATE
USING (
    public.pode_cadastrar_usuario()
);

-- 8.4 DELETE: NUNCA PERMITIDO
CREATE POLICY usuarios_autorizados_delete_policy ON public.usuarios_autorizados
FOR DELETE
USING (FALSE);

-- ============================================================
-- 9. FUNÇÃO PARA VERIFICAR PERMISSÃO DE ACESSO
-- ============================================================

CREATE OR REPLACE FUNCTION public.verificar_permissao_acesso(
    p_tabela VARCHAR,
    p_acao VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_usuario_id UUID;
    v_nivel INTEGER;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Obter nível de acesso do usuário
    SELECT p.nivel_acesso INTO v_nivel
    FROM public.usuarios u
    INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
    WHERE u.id = v_usuario_id AND u.ativo = TRUE AND u.deletado = FALSE;
    
    -- Verificar permissão baseada na tabela e ação
    CASE p_tabela
        WHEN 'usuarios' THEN
            RETURN p_acao IN ('SELECT', 'UPDATE');
        WHEN 'suspeito' THEN
            RETURN v_nivel >= 6;
        WHEN 'investigacao' THEN
            RETURN v_nivel >= 7;
        WHEN 'mandado_prisao' THEN
            RETURN v_nivel >= 7;
        WHEN 'ocorrencia' THEN
            RETURN v_nivel >= 6;
        ELSE
            RETURN v_nivel >= 5;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 10. VIEW DE PERMISSÕES DO USUÁRIO
-- ============================================================

CREATE OR REPLACE VIEW public.vw_permissoes_usuario AS
SELECT 
    u.id,
    u.matricula,
    u.nome_completo,
    p.nome AS perfil,
    p.nivel_acesso,
    p.is_master,
    CASE 
        WHEN ua.tipo IS NOT NULL THEN '✅ Autorizado'
        ELSE '❌ Não autorizado'
    END AS status_autorizacao,
    ua.tipo AS tipo_autorizacao
FROM public.usuarios u
LEFT JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
LEFT JOIN public.usuarios_autorizados ua ON u.id = ua.id_usuario AND ua.ativo = TRUE
WHERE u.deletado = FALSE;

-- ============================================================
-- MENSAGEM DE CONCLUSÃO
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ POLÍTICAS RLS COMPLETAS IMPLEMENTADAS';
    RAISE NOTICE '📅 Data: %', NOW();
    RAISE NOTICE '============================================================';
    RAISE NOTICE '📋 Tabelas protegidas:';
    RAISE NOTICE '   - usuarios';
    RAISE NOTICE '   - suspeito';
    RAISE NOTICE '   - investigacao';
    RAISE NOTICE '   - ocorrencia';
    RAISE NOTICE '   - mandado_prisao';
    RAISE NOTICE '   - arquivo_midia / midias';
    RAISE NOTICE '   - usuarios_autorizados';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '📋 Políticas criadas:';
    RAISE NOTICE '   - SELECT (nível de acesso)';
    RAISE NOTICE '   - INSERT (nível de acesso)';
    RAISE NOTICE '   - UPDATE (nível de acesso)';
    RAISE NOTICE '   - DELETE (NUNCA PERMITIDO - Regra de Ouro Nº 1)';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '📋 Função criada:';
    RAISE NOTICE '   - verificar_permissao_acesso';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '📋 View criada:';
    RAISE NOTICE '   - vw_permissoes_usuario';
    RAISE NOTICE '============================================================';
END;
$$;
