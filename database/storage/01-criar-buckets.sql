-- =====================================================
-- AI-DEPOM - FASE 3: STORAGE
-- =====================================================
-- Caminho: database/storage/01-criar-buckets.sql
-- Data: 08/09/2026 - 16:00
-- Versão: 1.0.0
-- Descrição: Criação de buckets para armazenamento de mídias
-- =====================================================

-- =====================================================
-- 1. CRIAR BUCKETS VIA SUPABASE
-- =====================================================
-- NOTA: Execute no Storage do Supabase
-- =====================================================

-- Os buckets devem ser criados manualmente no painel do Supabase:
-- 1. Acesse Storage
-- 2. Clique em "Create new bucket"
-- 3. Preencha os dados abaixo

-- =====================================================
-- 2. TABELA PARA GERENCIAR MÍDIAS
-- =====================================================
-- Descrição: Registro de todas as mídias armazenadas
-- =====================================================

CREATE TABLE IF NOT EXISTS public.midias (
    id_midia SERIAL PRIMARY KEY,
    id_entidade INTEGER NOT NULL,
    tipo_entidade VARCHAR(30) NOT NULL,
    nome_original VARCHAR(255) NOT NULL,
    nome_seguro VARCHAR(255) NOT NULL,
    bucket VARCHAR(50) NOT NULL,
    caminho VARCHAR(500) NOT NULL,
    tipo_midia VARCHAR(20) NOT NULL CHECK (tipo_midia IN ('FOTO', 'VIDEO', 'AUDIO', 'DOCUMENTO', 'BIOMETRIA', 'EVIDENCIA')),
    formato VARCHAR(10) NOT NULL,
    tamanho_bytes BIGINT NOT NULL,
    hash_sha256 VARCHAR(64) NOT NULL,
    metadata JSONB,
    nivel_seguranca VARCHAR(20) DEFAULT 'PUBLICO'
        CHECK (nivel_seguranca IN ('PUBLICO', 'RESTRITO', 'SIGILOSO', 'ULTRASSECRETO')),
    status VARCHAR(20) DEFAULT 'ATIVO'
        CHECK (status IN ('ATIVO', 'ARQUIVADO', 'EM_ANALISE', 'DELETADO')),
    id_usuario_upload UUID REFERENCES public.usuarios(id),
    data_upload TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assinatura_digital TEXT,
    deletado BOOLEAN DEFAULT FALSE,
    observacoes TEXT
);

-- =====================================================
-- 3. ÍNDICES PARA PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_midias_entidade ON public.midias(id_entidade, tipo_entidade);
CREATE INDEX IF NOT EXISTS idx_midias_bucket ON public.midias(bucket);
CREATE INDEX IF NOT EXISTS idx_midias_tipo ON public.midias(tipo_midia);
CREATE INDEX IF NOT EXISTS idx_midias_data ON public.midias(data_upload DESC);
CREATE INDEX IF NOT EXISTS idx_midias_hash ON public.midias(hash_sha256);

-- =====================================================
-- 4. POLÍTICAS DE SEGURANÇA PARA TABELA MIDIAS
-- =====================================================

-- Habilitar RLS
ALTER TABLE public.midias ENABLE ROW LEVEL SECURITY;

-- Política de SELECT: Usuários podem ver apenas mídias de entidades que têm acesso
CREATE POLICY midias_select_policy ON public.midias
FOR SELECT
USING (
    deletado = FALSE AND (
        EXISTS (
            SELECT 1 FROM public.usuarios u
            INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
            WHERE u.id = auth.uid() AND p.nivel_acesso >= 5
        )
    )
);

-- Política de INSERT: Apenas usuários com nível >= 6 podem fazer upload
CREATE POLICY midias_insert_policy ON public.midias
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 6
    )
);

-- Política de UPDATE: Apenas quem fez upload pode atualizar
CREATE POLICY midias_update_policy ON public.midias
FOR UPDATE
USING (
    id_usuario_upload = auth.uid() OR
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 8
    )
);

-- Política de DELETE (lógico): Apenas administradores ou quem fez upload
CREATE POLICY midias_delete_policy ON public.midias
FOR DELETE
USING (
    id_usuario_upload = auth.uid() OR
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.is_master = TRUE
    )
);

-- =====================================================
-- 5. FUNÇÃO PARA GERAR NOME SEGURO
-- =====================================================
-- Descrição: Gera um nome único e seguro para arquivos
-- =====================================================

CREATE OR REPLACE FUNCTION public.gerar_nome_seguro(
    p_nome_original VARCHAR,
    p_id_entidade INTEGER,
    p_tipo_entidade VARCHAR
)
RETURNS VARCHAR AS $$
DECLARE
    v_extensao VARCHAR(10);
    v_hash VARCHAR(64);
    v_nome_seguro VARCHAR(255);
BEGIN
    -- Extrair extensão
    v_extensao := SUBSTRING(p_nome_original FROM '\.([^\.]+)$');
    
    -- Gerar hash único
    v_hash := encode(gen_random_bytes(32), 'hex');
    
    -- Construir nome seguro
    v_nome_seguro := p_tipo_entidade || '_' || p_id_entidade || '_' || v_hash || '.' || v_extensao;
    
    RETURN v_nome_seguro;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNÇÃO PARA REGISTRAR UPLOAD
-- =====================================================
-- Descrição: Registra o upload de uma mídia
-- =====================================================

CREATE OR REPLACE FUNCTION public.registrar_upload(
    p_id_entidade INTEGER,
    p_tipo_entidade VARCHAR,
    p_nome_original VARCHAR,
    p_bucket VARCHAR,
    p_caminho VARCHAR,
    p_tipo_midia VARCHAR,
    p_tamanho_bytes BIGINT,
    p_hash_sha256 VARCHAR,
    p_metadata JSONB DEFAULT NULL,
    p_nivel_seguranca VARCHAR DEFAULT 'PUBLICO'
)
RETURNS INTEGER AS $$
DECLARE
    v_usuario_id UUID;
    v_nome_seguro VARCHAR;
    v_id_midia INTEGER;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Usuário não autenticado';
    END IF;
    
    -- Gerar nome seguro
    v_nome_seguro := public.gerar_nome_seguro(p_nome_original, p_id_entidade, p_tipo_entidade);
    
    -- Inserir registro
    INSERT INTO public.midias (
        id_entidade,
        tipo_entidade,
        nome_original,
        nome_seguro,
        bucket,
        caminho,
        tipo_midia,
        formato,
        tamanho_bytes,
        hash_sha256,
        metadata,
        nivel_seguranca,
        id_usuario_upload,
        data_upload
    ) VALUES (
        p_id_entidade,
        p_tipo_entidade,
        p_nome_original,
        v_nome_seguro,
        p_bucket,
        p_caminho,
        p_tipo_midia,
        SUBSTRING(p_nome_original FROM '\.([^\.]+)$'),
        p_tamanho_bytes,
        p_hash_sha256,
        p_metadata,
        p_nivel_seguranca,
        v_usuario_id,
        NOW()
    ) RETURNING id_midia INTO v_id_midia;
    
    -- Registrar log
    PERFORM public.log_info(
        'Upload de mídia realizado',
        jsonb_build_object(
            'id_midia', v_id_midia,
            'entidade', p_tipo_entidade || ':' || p_id_entidade,
            'tipo', p_tipo_midia,
            'tamanho', p_tamanho_bytes
        ),
        'upload'
    );
    
    RETURN v_id_midia;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. FUNÇÃO PARA EXCLUIR MÍDIA (LÓGICA)
-- =====================================================
-- Descrição: Exclui logicamente uma mídia
-- =====================================================

CREATE OR REPLACE FUNCTION public.excluir_midia(
    p_id_midia INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_usuario_id UUID;
    v_midia RECORD;
BEGIN
    -- Obter usuário atual
    v_usuario_id := auth.uid();
    
    IF v_usuario_id IS NULL THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Usuário não autenticado'
        );
    END IF;
    
    -- Buscar mídia
    SELECT * INTO v_midia
    FROM public.midias
    WHERE id_midia = p_id_midia AND deletado = FALSE;
    
    IF v_midia IS NULL THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Mídia não encontrada'
        );
    END IF;
    
    -- Verificar permissão
    IF NOT (v_midia.id_usuario_upload = v_usuario_id OR 
            EXISTS (SELECT 1 FROM public.usuarios u 
                    INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil 
                    WHERE u.id = v_usuario_id AND p.is_master = TRUE)) THEN
        RETURN jsonb_build_object(
            'sucesso', FALSE,
            'mensagem', 'Sem permissão para excluir esta mídia'
        );
    END IF;
    
    -- Excluir logicamente
    UPDATE public.midias
    SET 
        status = 'DELETADO',
        deletado = TRUE,
        data_atualizacao = NOW()
    WHERE id_midia = p_id_midia;
    
    -- Registrar log
    PERFORM public.log_seguranca(
        'Exclusão de mídia',
        'WARNING',
        jsonb_build_object(
            'id_midia', p_id_midia,
            'nome_original', v_midia.nome_original,
            'usuario', v_usuario_id
        )
    );
    
    RETURN jsonb_build_object(
        'sucesso', TRUE,
        'mensagem', 'Mídia excluída com sucesso',
        'id_midia', p_id_midia
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 8. VIEW DE MÍDIAS POR ENTIDADE
-- =====================================================
-- Descrição: Lista todas as mídias de uma entidade
-- =====================================================

CREATE OR REPLACE VIEW public.vw_midias_entidade AS
SELECT 
    m.id_midia,
    m.id_entidade,
    m.tipo_entidade,
    m.nome_original,
    m.nome_seguro,
    m.bucket,
    m.tipo_midia,
    m.formato,
    m.tamanho_bytes,
    ROUND(m.tamanho_bytes / 1024.0 / 1024.0, 2) AS tamanho_mb,
    m.hash_sha256,
    m.metadata,
    m.nivel_seguranca,
    m.status,
    u.nome_completo AS usuario_upload,
    m.data_upload,
    m.observacoes,
    CASE 
        WHEN m.tipo_midia IN ('FOTO', 'EVIDENCIA') THEN 
            'https://szkgaqouivsvlyujfvmz.supabase.co/storage/v1/object/public/' || m.bucket || '/' || m.nome_seguro
        ELSE NULL
    END AS url_preview
FROM public.midias m
LEFT JOIN public.usuarios u ON m.id_usuario_upload = u.id
WHERE m.deletado = FALSE;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ STORAGE CONFIGURADO COM SUCESSO' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Itens criados:' ;
    RAISE NOTICE '   - Tabela: midias' ;
    RAISE NOTICE '   - Função: gerar_nome_seguro' ;
    RAISE NOTICE '   - Função: registrar_upload' ;
    RAISE NOTICE '   - Função: excluir_midia' ;
    RAISE NOTICE '   - View: vw_midias_entidade' ;
    RAISE NOTICE '   - Políticas RLS para midias' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔐 Próximo passo: Configurar políticas de acesso' ;
    RAISE NOTICE '   para os buckets no Storage' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
