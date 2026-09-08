/**
 * ============================================================
 * AI-DEPOM - EDGE FUNCTION: VALIDAR OTP
 * ============================================================
 * Caminho: supabase/functions/validar-otp/index.ts
 * Versão: 1.0.0
 * Data: 08/09/2026
 * Horário: 23:15
 * Autor: Admin Master
 * ============================================================
 * DESCRIÇÃO:
 * Edge Function para validar OTP (One-Time Password) com a biblioteca otpauth.
 * Esta é a implementação REAL de validação OTP.
 * ============================================================
 * ALTERAÇÕES:
 * v1.0.0 - 08/09/2026 - 23:15 - Admin Master
 *   - Criação inicial da Edge Function
 *   - Validação real com biblioteca otpauth
 *   - Verificação de secret do usuário
 *   - Registro de logs
 * ============================================================
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as OTPAuth from 'https://esm.sh/otpauth@7.0.1';

// ============================================================
// CONFIGURAÇÃO DO SUPABASE
// ============================================================
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// ============================================================
// INTERFACES
// ============================================================
interface ValidarOTPRequest {
    usuario_id: string;
    codigo: string;
}

interface ValidarOTPResponse {
    valido: boolean;
    mensagem?: string;
    detalhes?: {
        nome?: string;
        email?: string;
    };
}

// ============================================================
// FUNÇÃO PRINCIPAL
// ============================================================
Deno.serve(async (req: Request): Promise<Response> => {
    // ============================================
    // 1. VALIDAR MÉTODO
    // ============================================
    if (req.method !== 'POST') {
        return new Response(
            JSON.stringify({ 
                erro: 'Método não permitido. Use POST.' 
            }),
            { 
                status: 405,
                headers: { 'Content-Type': 'application/json' }
            }
        );
    }

    try {
        // ============================================
        // 2. OBTER DADOS DA REQUISIÇÃO
        // ============================================
        const body: ValidarOTPRequest = await req.json();
        const { usuario_id, codigo } = body;

        // ============================================
        // 3. VALIDAR CAMPOS OBRIGATÓRIOS
        // ============================================
        if (!usuario_id || !codigo) {
            return new Response(
                JSON.stringify({
                    valido: false,
                    mensagem: 'Campos obrigatórios: usuario_id e codigo'
                }),
                { 
                    status: 400,
                    headers: { 'Content-Type': 'application/json' }
                }
            );
        }

        // ============================================
        // 4. VALIDAR FORMATO DO CÓDIGO
        // ============================================
        if (!/^\d{6}$/.test(codigo)) {
            return new Response(
                JSON.stringify({
                    valido: false,
                    mensagem: 'Código OTP deve ter 6 dígitos'
                }),
                { 
                    status: 400,
                    headers: { 'Content-Type': 'application/json' }
                }
            );
        }

        // ============================================
        // 5. BUSCAR USUÁRIO NO BANCO
        // ============================================
        const { data: usuario, error } = await supabase
            .from('usuarios')
            .select('id, nome_completo, email, otp_secret, otp_habilitado, ativo, deletado')
            .eq('id', usuario_id)
            .single();

        if (error || !usuario) {
            // Registrar tentativa com usuário inexistente
            await supabase
                .from('logs_detalhados')
                .insert({
                    nivel: 'WARNING',
                    categoria: 'SEGURANCA',
                    mensagem: 'Tentativa de validação OTP - Usuário não encontrado',
                    detalhes: { usuario_id, codigo }
                });

            return new Response(
                JSON.stringify({
                    valido: false,
                    mensagem: 'Usuário não encontrado'
                }),
                { 
                    status: 404,
                    headers: { 'Content-Type': 'application/json' }
                }
            );
        }

        // ============================================
        // 6. VERIFICAR SE USUÁRIO ESTÁ ATIVO
        // ============================================
        if (!usuario.ativo || usuario.deletado) {
            await supabase
                .from('logs_detalhados')
                .insert({
                    id_usuario: usuario_id,
                    nivel: 'WARNING',
                    categoria: 'SEGURANCA',
                    mensagem: 'Tentativa de validação OTP - Usuário inativo',
                    detalhes: { usuario_id, codigo }
                });

            return new Response(
                JSON.stringify({
                    valido: false,
                    mensagem: 'Usuário inativo'
                }),
                { 
                    status: 403,
                    headers: { 'Content-Type': 'application/json' }
                }
            );
        }

        // ============================================
        // 7. VERIFICAR SE OTP ESTÁ CONFIGURADO
        // ============================================
        if (!usuario.otp_habilitado || !usuario.otp_secret) {
            await supabase
                .from('logs_detalhados')
                .insert({
                    id_usuario: usuario_id,
                    nivel: 'INFO',
                    categoria: 'SEGURANCA',
                    mensagem: 'Tentativa de validação OTP - OTP não configurado',
                    detalhes: { 
                        usuario_id, 
                        codigo,
                        nome: usuario.nome_completo
                    }
                });

            return new Response(
                JSON.stringify({
                    valido: false,
                    mensagem: 'OTP não configurado para este usuário',
                    detalhes: {
                        nome: usuario.nome_completo,
                        email: usuario.email
                    }
                }),
                { 
                    status: 400,
                    headers: { 'Content-Type': 'application/json' }
                }
            );
        }

        // ============================================
        // 8. VALIDAR OTP COM A BIBLIOTECA
        // ============================================
        const totp = new OTPAuth.TOTP({
            secret: usuario.otp_secret,
            algorithm: 'SHA1',
            digits: 6,
            period: 30
        });

        // Validar o código
        // O método validate() retorna null se inválido, ou o timestamp se válido
        const valido = totp.validate({ token: codigo, window: 1 }) !== null;

        // ============================================
        // 9. REGISTRAR LOG
        // ============================================
        await supabase
            .from('logs_detalhados')
            .insert({
                id_usuario: usuario_id,
                nivel: valido ? 'INFO' : 'WARNING',
                categoria: 'SEGURANCA',
                mensagem: valido 
                    ? 'OTP validado com sucesso' 
                    : 'Tentativa de validação OTP - Código inválido',
                detalhes: { 
                    usuario_id, 
                    codigo,
                    nome: usuario.nome_completo,
                    valido
                }
            });

        // ============================================
        // 10. RETORNAR RESULTADO
        // ============================================
        const response: ValidarOTPResponse = {
            valido,
            mensagem: valido 
                ? 'Código OTP válido' 
                : 'Código OTP inválido. Tente novamente.',
            detalhes: valido ? {
                nome: usuario.nome_completo,
                email: usuario.email
            } : undefined
        };

        return new Response(
            JSON.stringify(response),
            { 
                status: valido ? 200 : 401,
                headers: { 'Content-Type': 'application/json' }
            }
        );

    } catch (error) {
        // ============================================
        // 11. TRATAR ERROS
        // ============================================
        console.error('Erro na validação OTP:', error);

        return new Response(
            JSON.stringify({
                valido: false,
                mensagem: 'Erro interno ao validar OTP',
                erro: error.message
            }),
            { 
                status: 500,
                headers: { 'Content-Type': 'application/json' }
            }
        );
    }
});
