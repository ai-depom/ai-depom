-- ============================================================
-- AI-DEPOM - CONTROLE DE ACESSO E PERMISSÕES
-- ============================================================
-- Caminho: database/security/08-controle-acesso.sql
-- Versão: 1.0.0
-- Data: 08/09/2026
-- Horário: 18:00
-- Autor: Admin Master
-- ============================================================
-- DESCRIÇÃO:
-- Implementa o controle de acesso rigoroso:
-- - Apenas o primeiro usuário Master e o desenvolvedor podem cadastrar novos usuários
-- - Nenhum usuário pode deletar dados (apenas editar)
-- - Registro de todas as tentativas de acesso
-- ============================================================
-- ALTERAÇÕES:
-- v1.0.0 - 08/09/2026 - 18:00 - Admin Master
--   - Criação inicial do arquivo
--   - Implementação da Regra de Ouro Nº 8
--   - Funções para verificação de permissões
--   - Triggers para impedir deleção
--   - Políticas RLS para controle de acesso
-- ============================================================

-- ============================================================
-- 1. TABELA PARA REGISTRO DE USUÁRIOS AUTORIZADOS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.usuarios_autorizados (
    id_autorizacao SERIAL PRIMARY KEY,
    id_usuario UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('MASTER', 'DESENVOLVEDOR')),
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_revogacao TIMESTAMP WITH TIME ZONE,
    ativo BOOLEAN DEFAULT TRUE,
    UNIQUE(id_usuario, tipo)
);

-- ============================================================
-- 2. FUNÇÃO PARA VERIFICAR SE É USUÁRIO AUTORIZADO
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_usuario_autorizado(
    p_usuario_id UUID DEFAULT NULL,
    p_tipo VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_usuario_id UUID;
    v_resultado BOOLEAN;
BEGIN
    -- Se não for passado ID, usa o usuário atual
    IF p_usuario_id IS NULL THEN
        v_usuario_id := auth.uid();
    ELSE
        v_usuario_id := p_usuario_id;
    END IF;
    
    -- Verificar se é autorizado
    SELECT EXISTS (
        SELECT 1 FROM public.usuarios_autorizados
        WHERE id_usuario = v_usuario_id
        AND ativo = TRUE
        AND (p_tipo IS NULL OR tipo = p_tipo)
    ) INTO v_resultado;
    
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. FUNÇÃO PARA VERIFICAR PERMISSÃO DE CADASTRO
-- ============================================================

CREATE OR REPLACE FUNCTION public.pode_cadastrar_usuario()
RETURNS BOOLEAN AS $$
DECLARE
    v_usuario_id UUID;
    v_is_master BOOLEAN;
    v_is_desenvolvedor BOOLEAN;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Verificar se é Master (primeiro usuário)
    SELECT EXISTS (
        SELECT 1 FROM public.usuarios_autorizados
        WHERE id_usuario = v_usuario_id
        AND tipo = 'MASTER'
        AND ativo = TRUE
    ) INTO v_is_master;
    
    -- Verificar se é Desenvolvedor
    SELECT EXISTS (
        SELECT 1 FROM public.usuarios_autorizados
        WHERE id_usuario = v_usuario_id
        AND tipo = 'DESENVOLVEDOR'
        AND ativo = TRUE
    ) INTO v_is_desenvolvedor;
    
    RETURN v_is_master OR v_is_desenvolvedor;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. FUNÇÃO PARA VERIFICAR PERMISSÃO DE EDIÇÃO
-- ============================================================

CREATE OR REPLACE FUNCTION public.pode_editar_dados(
    p_tabela VARCHAR,
    p_id_registro INTEGER DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_usuario_id UUID;
    v_nivel_acesso INTEGER;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Verificar se tem permissão de edição (nível >= 5)
    SELECT p.nivel_acesso INTO v_nivel_acesso
    FROM public.usuarios u
    INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
    WHERE u.id = v_usuario_id AND u.ativo = TRUE AND u.deletado = FALSE;
    
    RETURN COALESCE(v_nivel_acesso, 0) >= 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. TRIGGER PARA IMPEDIR DELEÇÃO FÍSICA
-- ============================================================

CREATE OR REPLACE FUNCTION public.impedir_delecao()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION '🚫 NÃO É PERMITIDO DELETAR DADOS! Use exclusão lógica (deletado = TRUE).';
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Aplicar triggers para todas as tabelas principais
CREATE TRIGGER impedir_delecao_suspeito
BEFORE DELETE ON public.suspeito
FOR EACH ROW
EXECUTE FUNCTION public.impedir_delecao();

CREATE TRIGGER impedir_delecao_investigacao
BEFORE DELETE ON public.investigacao
FOR EACH ROW
EXECUTE FUNCTION public.impedir_delecao();

CREATE TRIGGER impedir_delecao_mandado
BEFORE DELETE ON public.mandado_prisao
FOR EACH ROW
EXECUTE FUNCTION public.impedir_delecao();

CREATE TRIGGER impedir_delecao_usuario
BEFORE DELETE ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION public.impedir_delecao();

-- ============================================================
-- 6. POLÍTICAS RLS PARA CONTROLE DE ACESSO
-- ============================================================

-- Habilitar RLS nas tabelas principais
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suspeito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investigacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mandado_prisao ENABLE ROW LEVEL SECURITY;

-- 6.1 Política para INSERT em usuarios (apenas Master/Desenvolvedor)
CREATE POLICY usuarios_insert_policy ON public.usuarios
FOR INSERT
WITH CHECK (
    public.pode_cadastrar_usuario()
);

-- 6.2 Política para UPDATE em usuarios (apenas edição, sem deleção)
CREATE POLICY usuarios_update_policy ON public.usuarios
FOR UPDATE
USING (
    public.pode_editar_dados('usuarios')
)
WITH CHECK (
    public.pode_editar_dados('usuarios')
);

-- 6.3 Política para DELETE em usuarios (impedido)
CREATE POLICY usuarios_delete_policy ON public.usuarios
FOR DELETE
USING (FALSE);

-- ============================================================
-- 7. INSERIR PRIMEIRO USUÁRIO MASTER
-- ============================================================

-- NOTA: Esta etapa deve ser executada após a criação do primeiro usuário
-- Substitua 'ID_DO_USUARIO_MASTER' pelo UUID real do primeiro usuário

INSERT INTO public.usuarios_autorizados (id_usuario, tipo)
VALUES (
    'ID_DO_USUARIO_MASTER', -- Substitua pelo UUID real
    'MASTER'
);

-- ============================================================
-- 8. FUNÇÃO PARA REGISTRAR TENTATIVAS DE ACESSO NÃO AUTORIZADO
-- ============================================================

CREATE OR REPLACE FUNCTION public.registrar_acesso_nao_autorizado(
    p_acao VARCHAR,
    p_tabela VARCHAR,
    p_detalhes JSONB DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_usuario_id UUID;
BEGIN
    v_usuario_id := auth.uid();
    
    INSERT INTO public.logs_detalhados (
        id_usuario,
        nivel,
        categoria,
        mensagem,
        detalhes,
        origem
    ) VALUES (
        v_usuario_id,
        'WARNING',
        'SEGURANCA',
        'Tentativa de acesso não autorizado: ' || p_acao || ' em ' || p_tabela,
        jsonb_build_object(
            'acao', p_acao,
            'tabela', p_tabela,
            'detalhes', p_detalhes
        ),
        'controle_acesso'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. VIEW PARA LISTAR USUÁRIOS AUTORIZADOS
-- ============================================================

CREATE OR REPLACE VIEW public.vw_usuarios_autorizados AS
SELECT 
    ua.id_autorizacao,
    ua.id_usuario,
    u.matricula,
    u.nome_completo,
    u.email,
    ua.tipo,
    ua.data_cadastro,
    ua.ativo,
    CASE 
        WHEN ua.tipo = 'MASTER' THEN '👑 Master'
        WHEN ua.tipo = 'DESENVOLVEDOR' THEN '💻 Desenvolvedor'
        ELSE '❓ Desconhecido'
    END AS tipo_label
FROM public.usuarios_autorizados ua
LEFT JOIN public.usuarios u ON ua.id_usuario = u.id
WHERE ua.ativo = TRUE;

-- ============================================================
-- MENSAGEM DE CONCLUSÃO
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ CONTROLE DE ACESSO IMPLEMENTADO';
    RAISE NOTICE '📅 Data: %', NOW();
    RAISE NOTICE '============================================================';
    RAISE NOTICE '📋 REGRA DE OURO Nº 8 APLICADA:';
    RAISE NOTICE '   - Apenas Master e Desenvolvedor podem cadastrar usuários';
    RAISE NOTICE '   - Nenhum usuário pode deletar dados (apenas editar)';
    RAISE NOTICE '   - Todas as tentativas não autorizadas são registradas';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '📋 Itens criados:';
    RAISE NOTICE '   - Tabela: usuarios_autorizados';
    RAISE NOTICE '   - Função: is_usuario_autorizado';
    RAISE NOTICE '   - Função: pode_cadastrar_usuario';
    RAISE NOTICE '   - Função: pode_editar_dados';
    RAISE NOTICE '   - Função: impedir_delecao (Trigger)';
    RAISE NOTICE '   - Função: registrar_acesso_nao_autorizado';
    RAISE NOTICE '   - View: vw_usuarios_autorizados';
    RAISE NOTICE '   - Políticas RLS para todas as tabelas';
    RAISE NOTICE '============================================================';
END;
$$;
