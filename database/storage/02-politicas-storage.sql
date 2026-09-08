-- =====================================================
-- AI-DEPOM - FASE 3: POLÍTICAS DE STORAGE
-- =====================================================
-- Caminho: database/storage/02-politicas-storage.sql
-- Data: 08/09/2026 - 16:15
-- Versão: 1.0.0
-- Descrição: Políticas de segurança para buckets do Supabase Storage
-- =====================================================

-- =====================================================
-- 1. HABILITAR RLS NO STORAGE
-- =====================================================
-- NOTA: Execute no SQL Editor do Supabase
-- As políticas abaixo devem ser aplicadas para cada bucket
-- =====================================================

-- =====================================================
-- 2. POLÍTICAS PARA BUCKET: fotos-suspeitos
-- =====================================================

-- 2.1 Upload de fotos (apenas usuários com nível >= 6)
CREATE POLICY "Usuários podem fazer upload de fotos" ON storage.objects
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id = 'fotos-suspeitos' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 6
    )
);

-- 2.2 Visualizar fotos (apenas usuários com nível >= 5)
CREATE POLICY "Usuários podem visualizar fotos" ON storage.objects
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'fotos-suspeitos' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 5
    )
);

-- 2.3 Atualizar fotos (apenas quem fez upload ou admin)
CREATE POLICY "Usuários podem atualizar suas fotos" ON storage.objects
FOR UPDATE
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'fotos-suspeitos' AND
    (owner = auth.uid() OR 
     EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.is_master = TRUE
     ))
);

-- 2.4 Excluir fotos (apenas admin)
CREATE POLICY "Administradores podem excluir fotos" ON storage.objects
FOR DELETE
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'fotos-suspeitos' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.is_master = TRUE
    )
);

-- =====================================================
-- 3. POLÍTICAS PARA BUCKET: videos-investigacoes
-- =====================================================

-- 3.1 Upload de vídeos (apenas usuários com nível >= 7)
CREATE POLICY "Usuários podem fazer upload de vídeos" ON storage.objects
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id = 'videos-investigacoes' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 7
    )
);

-- 3.2 Visualizar vídeos (apenas usuários com nível >= 6)
CREATE POLICY "Usuários podem visualizar vídeos" ON storage.objects
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'videos-investigacoes' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 6
    )
);

-- =====================================================
-- 4. POLÍTICAS PARA BUCKET: documentos-oficiais
-- =====================================================

-- 4.1 Upload de documentos (apenas usuários com nível >= 6)
CREATE POLICY "Usuários podem fazer upload de documentos" ON storage.objects
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id = 'documentos-oficiais' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 6
    )
);

-- 4.2 Visualizar documentos (apenas usuários com nível >= 5)
CREATE POLICY "Usuários podem visualizar documentos" ON storage.objects
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'documentos-oficiais' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 5
    )
);

-- =====================================================
-- 5. POLÍTICAS PARA BUCKET: biometria-dados
-- =====================================================

-- 5.1 Upload de biometria (apenas usuários com nível >= 8)
CREATE POLICY "Usuários podem fazer upload de biometria" ON storage.objects
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id = 'biometria-dados' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 8
    )
);

-- 5.2 Visualizar biometria (apenas usuários com nível >= 8)
CREATE POLICY "Usuários podem visualizar biometria" ON storage.objects
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'biometria-dados' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 8
    )
);

-- =====================================================
-- 6. POLÍTICAS PARA BUCKET: evidencias-crime
-- =====================================================

-- 6.1 Upload de evidências (apenas usuários com nível >= 7)
CREATE POLICY "Usuários podem fazer upload de evidências" ON storage.objects
FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated' AND
    bucket_id = 'evidencias-crime' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 7
    )
);

-- 6.2 Visualizar evidências (apenas usuários com nível >= 6)
CREATE POLICY "Usuários podem visualizar evidências" ON storage.objects
FOR SELECT
USING (
    auth.role() = 'authenticated' AND
    bucket_id = 'evidencias-crime' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND p.nivel_acesso >= 6
    )
);

-- =====================================================
-- 7. FUNÇÃO PARA VALIDAR PERMISSÃO DE UPLOAD
-- =====================================================

CREATE OR REPLACE FUNCTION public.validar_permissao_upload(
    p_bucket VARCHAR,
    p_nivel_requerido INTEGER DEFAULT 6
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.usuarios u
        INNER JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
        WHERE u.id = auth.uid() 
        AND u.ativo = TRUE 
        AND u.deletado = FALSE
        AND p.nivel_acesso >= p_nivel_requerido
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 8. FUNÇÃO PARA VERIFICAR TAMANHO DO ARQUIVO
-- =====================================================

CREATE OR REPLACE FUNCTION public.validar_tamanho_arquivo(
    p_tamanho_bytes BIGINT,
    p_maximo_mb INTEGER DEFAULT 10
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_tamanho_bytes <= (p_maximo_mb * 1024 * 1024);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 9. FUNÇÃO PARA VERIFICAR EXTENSÃO PERMITIDA
-- =====================================================

CREATE OR REPLACE FUNCTION public.validar_extensao_arquivo(
    p_nome VARCHAR,
    p_extensoes_permitidas TEXT[] DEFAULT ARRAY['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'mov']
)
RETURNS BOOLEAN AS $$
DECLARE
    v_extensao VARCHAR(10);
BEGIN
    v_extensao := LOWER(SUBSTRING(p_nome FROM '\.([^\.]+)$'));
    RETURN v_extensao = ANY(p_extensoes_permitidas);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 10. FUNÇÃO PARA VALIDAR ARQUIVO COMPLETO
-- =====================================================

CREATE OR REPLACE FUNCTION public.validar_arquivo(
    p_nome VARCHAR,
    p_tamanho_bytes BIGINT,
    p_bucket VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_extensoes_permitidas TEXT[];
    v_maximo_mb INTEGER;
BEGIN
    -- Definir regras por bucket
    CASE p_bucket
        WHEN 'fotos-suspeitos' THEN
            v_extensoes_permitidas := ARRAY['jpg', 'jpeg', 'png', 'webp'];
            v_maximo_mb := 5;
        WHEN 'videos-investigacoes' THEN
            v_extensoes_permitidas := ARRAY['mp4', 'mov', 'avi', 'webm'];
            v_maximo_mb := 100;
        WHEN 'documentos-oficiais' THEN
            v_extensoes_permitidas := ARRAY['pdf', 'jpg', 'jpeg', 'png'];
            v_maximo_mb := 20;
        WHEN 'biometria-dados' THEN
            v_extensoes_permitidas := ARRAY['csv', 'json', 'xml'];
            v_maximo_mb := 10;
        WHEN 'evidencias-crime' THEN
            v_extensoes_permitidas := ARRAY['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'];
            v_maximo_mb := 50;
        ELSE
            v_extensoes_permitidas := ARRAY['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'mov'];
            v_maximo_mb := 10;
    END CASE;
    
    -- Validar
    IF NOT public.validar_extensao_arquivo(p_nome, v_extensoes_permitidas) THEN
        RETURN jsonb_build_object(
            'valido', FALSE,
            'mensagem', 'Extensão não permitida. Extensões permitidas: ' || array_to_string(v_extensoes_permitidas, ', ')
        );
    END IF;
    
    IF NOT public.validar_tamanho_arquivo(p_tamanho_bytes, v_maximo_mb) THEN
        RETURN jsonb_build_object(
            'valido', FALSE,
            'mensagem', 'Tamanho máximo permitido: ' || v_maximo_mb || ' MB'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'valido', TRUE,
        'mensagem', 'Arquivo válido'
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ POLÍTICAS DE STORAGE CONFIGURADAS' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Políticas criadas para:' ;
    RAISE NOTICE '   - fotos-suspeitos' ;
    RAISE NOTICE '   - videos-investigacoes' ;
    RAISE NOTICE '   - documentos-oficiais' ;
    RAISE NOTICE '   - biometria-dados' ;
    RAISE NOTICE '   - evidencias-crime' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '📋 Funções auxiliares:' ;
    RAISE NOTICE '   - validar_permissao_upload' ;
    RAISE NOTICE '   - validar_tamanho_arquivo' ;
    RAISE NOTICE '   - validar_extensao_arquivo' ;
    RAISE NOTICE '   - validar_arquivo' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔐 Próximo passo: Implementar upload no frontend' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
