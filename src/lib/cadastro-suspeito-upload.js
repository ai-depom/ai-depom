// ============================================================
// CADASTRO DE SUSPEITO — UPLOAD DE FOTO (BUCKET PRIVADO)
// Caminho: src/lib/cadastro-suspeito-upload.js
// ============================================================

import { supabase } from './supabaseClient.js';

const BUCKET_FOTOS = 'fotos-suspeitos';

/**
 * Calcula hash SHA-256 do arquivo
 */
async function calcularHashSHA256(file) {
    const buffer = await file.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Faz upload da foto no Storage (bucket privado) e registra em arquivo_midia
 */
export async function salvarFotoSuspeito(file, idSuspeito, idUsuario) {
    if (!file) return null;

    const extensao = file.name.split('.').pop().toLowerCase();
    const nomeSeguro = `suspeito_${idSuspeito}_${Date.now()}.${extensao}`;

    // 1. Upload no bucket privado
    const { error: uploadError } = await supabase.storage
        .from(BUCKET_FOTOS)
        .upload(nomeSeguro, file, {
            cacheControl: '3600',
            upsert: false,
            contentType: file.type,
        });

    if (uploadError) {
        console.error('❌ Erro no upload:', uploadError);
        throw uploadError;
    }

    // 2. Hash
    const hash = await calcularHashSHA256(file);

    // 3. Registra em arquivo_midia
    const { data, error: dbError } = await supabase
        .from('arquivo_midia')
        .insert({
            id_entidade:       idSuspeito,
            tipo_entidade:     'SUSPEITO',
            nome_original:     file.name,
            nome_seguro:       nomeSeguro,
            tipo_midia:        'FOTO',
            formato:           file.type,
            tamanho_bytes:     file.size,
            hash_sha256:       hash,
            caminho_fisico:    nomeSeguro,
            nivel_seguranca:   'PADRAO',
            status:            'ATIVO',
            id_usuario_upload: idUsuario,
            deletado:          false,
        })
        .select()
        .single();

    if (dbError) {
        console.error('❌ Erro ao registrar mídia:', dbError);
        await supabase.storage.from(BUCKET_FOTOS).remove([nomeSeguro]);
        throw dbError;
    }

    return data;
}

/**
 * Fluxo completo do cadastro
 */
export async function cadastrarSuspeitoComFoto(dadosSuspeito, arquivoFoto, idUsuario) {
    // 1. Insere o suspeito
    const { data: suspeito, error: erroSuspeito } = await supabase
        .from('suspeito')
        .insert({
            nome_completo:        dadosSuspeito.nome_completo,
            apelido:              dadosSuspeito.apelido,
            cpf:                  dadosSuspeito.cpf,
            data_nascimento:      dadosSuspeito.data_nascimento,
            status_atual:         dadosSuspeito.status_atual,
            nivel_periculosidade: dadosSuspeito.nivel_periculosidade,
            id_usuario_cadastro:  idUsuario,
            deletado:             false,
        })
        .select()
        .single();

    if (erroSuspeito) throw erroSuspeito;

    // 2. Sobe foto (se houver)
    if (arquivoFoto) {
        await salvarFotoSuspeito(arquivoFoto, suspeito.id_suspeito, idUsuario);
    }

    return suspeito;
}
