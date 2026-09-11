// ============================================================
// CONSULTA DE SUSPEITOS — BUCKET PRIVADO (createSignedUrl)
// Caminho: src/lib/consulta-suspeitos.js
// ============================================================

import { supabase } from './supabaseClient.js';

const BUCKET_FOTOS = 'fotos-suspeitos';

const STATUS_VALIDOS = [
    'INVESTIGADO',
    'PRESO',
    'FORAGIDO',
    'PROCURADO',
    'CONDICIONAL',
    'LIBERADO',
];

/**
 * Gera URL assinada (bucket privado) com validade padrão de 1h
 */
export async function getUrlFotoAssinada(caminhoFisico, expiresInSeconds = 3600) {
    if (!caminhoFisico) return null;

    const { data, error } = await supabase.storage
        .from(BUCKET_FOTOS)
        .createSignedUrl(caminhoFisico, expiresInSeconds);

    if (error) {
        console.error('❌ Erro ao gerar signed URL:', error);
        return null;
    }
    return data.signedUrl;
}

/**
 * Busca suspeitos com foto (todos os status) — já com URL assinada
 */
export async function buscarSuspeitosComFoto() {
    const { data, error } = await supabase
        .from('suspeito')
        .select(`
            id_suspeito,
            nome_completo,
            apelido,
            status_atual,
            nivel_periculosidade,
            arquivo_midia (
                caminho_fisico,
                nome_seguro,
                formato
            )
        `)
        .eq('deletado', false)
        .in('status_atual', STATUS_VALIDOS)
        .order('status_atual', { ascending: true })
        .order('nome_completo', { ascending: true });

    if (error) {
        console.error('❌ Erro na consulta:', error);
        throw error;
    }

    // Gera signed URL em paralelo para cada suspeito que tem foto
    const resultado = await Promise.all(
        data.map(async (s) => {
            const caminho = s.arquivo_midia?.[0]?.caminho_fisico || null;
            const fotoUrl = caminho ? await getUrlFotoAssinada(caminho, 3600) : null;

            return {
                id_suspeito:          s.id_suspeito,
                nome_completo:        s.nome_completo,
                apelido:              s.apelido,
                status_atual:         s.status_atual,
                nivel_periculosidade: s.nivel_periculosidade,
                foto_path:            caminho,
                foto_nome_seguro:     s.arquivo_midia?.[0]?.nome_seguro || null,
                foto_formato:         s.arquivo_midia?.[0]?.formato     || null,
                fotoUrl,
            };
        })
    );

    return resultado;
}
