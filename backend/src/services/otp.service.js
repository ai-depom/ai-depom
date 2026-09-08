/**
 * ============================================================
 * AI-DEPOM - WEB SERVICE: VALIDAÇÃO OTP
 * ============================================================
 * Caminho: backend/src/services/otp.service.js
 * Versão: 1.0.0
 * Data: 08/09/2026
 * Horário: 23:30
 * Autor: Admin Master
 * ============================================================
 * DESCRIÇÃO:
 * Serviço para validação de OTP usando a biblioteca speakeasy.
 * Implementação alternativa para Web Service no Render.
 * ============================================================
 * ALTERAÇÕES:
 * v1.0.0 - 08/09/2026 - 23:30 - Admin Master
 *   - Criação inicial do serviço
 *   - Validação real com speakeasy
 *   - Conexão com Supabase
 *   - Registro de logs
 * ============================================================
 */

const { createClient } = require('@supabase/supabase-js');
const speakeasy = require('speakeasy');

// ============================================================
// CONFIGURAÇÃO DO SUPABASE
// ============================================================
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error('Variáveis de ambiente SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são obrigatórias');
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// ============================================================
// FUNÇÃO: VALIDAR OTP
// ============================================================
async function validarOTP(usuarioId, codigo) {
    // ============================================
    // 1. VALIDAR PARÂMETROS
    // ============================================
    if (!usuarioId || !codigo) {
        return { 
            valido: false, 
            mensagem: 'Campos obrigatórios: usuarioId e codigo' 
        };
    }

    if (!/^\d{6}$/.test(codigo)) {
        return { 
            valido: false, 
            mensagem: 'Código OTP deve ter 6 dígitos' 
        };
    }

    try {
        // ============================================
        // 2. BUSCAR USUÁRIO NO BANCO
        // ============================================
        const { data: usuario, error } = await supabase
            .from('usuarios')
            .select('id, nome_completo, email, otp_secret, otp_habilitado, ativo, deletado')
            .eq('id', usuarioId)
            .single();

        if (error || !usuario) {
            await supabase
                .from('logs_detalhados')
                .insert({
                    nivel: 'WARNING',
                    categoria: 'SEGURANCA',
                    mensagem: 'Tentativa de validação OTP - Usuário não encontrado',
                    detalhes: { usuario_id: usuarioId }
                });

            return { 
                valido: false, 
                mensagem: 'Usuário não encontrado' 
            };
        }

        // ============================================
        // 3. VERIFICAR SE USUÁRIO ESTÁ ATIVO
        // ============================================
        if (!usuario.ativo || usuario.deletado) {
            await supabase
                .from('logs_detalhados')
                .insert({
                    id_usuario: usuarioId,
                    nivel: 'WARNING',
                    categoria: 'SEGURANCA',
                    mensagem: 'Tentativa de validação OTP - Usuário inativo',
                    detalhes: { usuario_id: usuarioId }
                });

            return { 
                valido: false, 
                mensagem: 'Usuário inativo' 
            };
        }

        // ============================================
        // 4. VERIFICAR SE OTP ESTÁ CONFIGURADO
        // ============================================
        if (!usuario.otp_habilitado || !usuario.otp_secret) {
            await supabase
                .from('logs_detalhados')
                .insert({
                    id_usuario: usuarioId,
                    nivel: 'INFO',
                    categoria: 'SEGURANCA',
                    mensagem: 'Tentativa de validação OTP - OTP não configurado',
                    detalhes: { 
                        usuario_id: usuarioId,
                        nome: usuario.nome_completo
                    }
                });

            return { 
                valido: false, 
                mensagem: 'OTP não configurado para este usuário' 
            };
        }

        // ============================================
        // 5. VALIDAR OTP COM SPEAKEASY
        // ============================================
        const valido = speakeasy.totp.verify({
            secret: usuario.otp_secret,
            encoding: 'base32',
            token: codigo,
            window: 1 // Permite 1 passo de tolerância (30 segundos)
        });

        // ============================================
        // 6. REGISTRAR LOG
        // ============================================
        await supabase
            .from('logs_detalhados')
            .insert({
                id_usuario: usuarioId,
                nivel: valido ? 'INFO' : 'WARNING',
                categoria: 'SEGURANCA',
                mensagem: valido 
                    ? 'OTP validado com sucesso' 
                    : 'Tentativa de validação OTP - Código inválido',
                detalhes: { 
                    usuario_id: usuarioId,
                    nome: usuario.nome_completo,
                    valido
                }
            });

        // ============================================
        // 7. RETORNAR RESULTADO
        // ============================================
        return {
            valido,
            mensagem: valido 
                ? 'Código OTP válido' 
                : 'Código OTP inválido. Tente novamente.',
            detalhes: valido ? {
                nome: usuario.nome_completo,
                email: usuario.email
            } : undefined
        };

    } catch (error) {
        console.error('Erro na validação OTP:', error);
        return {
            valido: false,
            mensagem: 'Erro ao validar OTP: ' + error.message
        };
    }
}

// ============================================================
// FUNÇÃO: GERAR SECRET
// ============================================================
function gerarSecret() {
    return speakeasy.generateSecret({
        length: 20,
        name: 'AI-DEPOM'
    });
}

// ============================================================
// EXPORTAR FUNÇÕES
// ============================================================
module.exports = {
    validarOTP,
    gerarSecret
};
