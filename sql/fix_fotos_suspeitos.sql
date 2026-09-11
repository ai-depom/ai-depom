-- ============================================================
-- FIX: FOTOS DOS SUSPEITOS — BUCKET PRIVADO
-- Rodar no Supabase SQL Editor
-- ============================================================

-- ============================================
-- 1. POLÍTICAS RLS DO STORAGE (bucket privado)
-- ============================================

-- Permite usuários autenticados LER arquivos do bucket
DROP POLICY IF EXISTS "authenticated pode ler fotos-suspeitos" ON storage.objects;
CREATE POLICY "authenticated pode ler fotos-suspeitos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'fotos-suspeitos');

-- Permite usuários autenticados FAZER UPLOAD no bucket
DROP POLICY IF EXISTS "authenticated pode upload fotos-suspeitos" ON storage.objects;
CREATE POLICY "authenticated pode upload fotos-suspeitos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'fotos-suspeitos');

-- Permite usuários autenticados DELETAR arquivos do bucket
DROP POLICY IF EXISTS "authenticated pode deletar fotos-suspeitos" ON storage.objects;
CREATE POLICY "authenticated pode deletar fotos-suspeitos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'fotos-suspeitos');

-- ============================================
-- 2. POLÍTICAS RLS DA TABELA arquivo_midia
-- ============================================

ALTER TABLE public.arquivo_midia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth pode ler arquivo_midia" ON public.arquivo_midia;
CREATE POLICY "auth pode ler arquivo_midia"
ON public.arquivo_midia FOR SELECT
TO authenticated
USING (deletado = false);

DROP POLICY IF EXISTS "auth pode inserir arquivo_midia" ON public.arquivo_midia;
CREATE POLICY "auth pode inserir arquivo_midia"
ON public.arquivo_midia FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "auth pode atualizar arquivo_midia" ON public.arquivo_midia;
CREATE POLICY "auth pode atualizar arquivo_midia"
ON public.arquivo_midia FOR UPDATE
TO authenticated
USING (true);

-- ============================================
-- 3. POLÍTICAS RLS DA TABELA suspeito
-- ============================================

ALTER TABLE public.suspeito ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth pode ler suspeito" ON public.suspeito;
CREATE POLICY "auth pode ler suspeito"
ON public.suspeito FOR SELECT
TO authenticated
USING (deletado = false);

DROP POLICY IF EXISTS "auth pode inserir suspeito" ON public.suspeito;
CREATE POLICY "auth pode inserir suspeito"
ON public.suspeito FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "auth pode atualizar suspeito" ON public.suspeito;
CREATE POLICY "auth pode atualizar suspeito"
ON public.suspeito FOR UPDATE
TO authenticated
USING (true);

-- ============================================
-- 4. DIAGNÓSTICO — SUSPEITOS POR STATUS
-- ============================================

SELECT
    s.status_atual,
    COUNT(DISTINCT s.id_suspeito) AS total_suspeitos,
    COUNT(am.id_arquivo)          AS com_foto
FROM public.suspeito s
LEFT JOIN public.arquivo_midia am
       ON am.id_entidade  = s.id_suspeito
      AND am.tipo_entidade = 'SUSPEITO'
      AND am.tipo_midia    = 'FOTO'
      AND am.deletado      = false
WHERE s.deletado = false
GROUP BY s.status_atual
ORDER BY s.status_atual;
