 // ============================================================
// AI-DEPOM - CONFIGURAÇÃO SUPABASE
// ============================================================
// Arquivo: assets/js/supabase-config.js
// Versão: 2.3.1
// Data: 15/09/2026 - 15:30
// Autor: AI-DEPOM Team
// ============================================================
// REGRA DE OURO:
// 1. Zero placeholders quebrados
// 2. Zero TODOs esquecidos
// 3. Zero duplicações
// 4. Toda função referenciada DEVE existir
// 5. Todo botão DEVE ter handler real
// 6. Todo módulo DEVE estar conectado
// 7. Nenhuma linha deve ser removida sem substituição
//
// ALTERAÇÕES v2.3.1 (15/09/2026 15:30):
// - 🛡️ supabaseClient só criado se ainda não existir
// - 🐛 getUsuario() trata "null" string
// - 🐛 logout() limpa TODAS as chaves AIDEPOM + supabase
// - 🐛 isAdminMaster() com fallback duplo (usuarios + usuarios_autorizados)
// - ➕ isAuthenticated()
// - ➕ getIniciais()
// - ➕ getPerfilId() / getPerfilNome()
// - ➕ refreshUsuario() (re-lê do Supabase)
// - 📜 Cabeçalho Regra de Ouro
// - ✅ Mantidas: todas as funções v2.3.0 (compatibilidade 100%)
// ============================================================

const SUPABASE_URL = 'https://szkgaqouivsvlyujfvmz.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6a2dhcW91aXZzdmx5dWpmdm16Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MzY0MjksImV4cCI6MjEwNDExMjQyOX0.4KBCiRxjZZrfaEBqfiFVSp9ECOy37brn1JFC7ga_2Hc';

// [v2.3.1] Só cria o cliente se ainda não existir (evita sobrescrever)
(function() {
    if (!window.supabaseClient && typeof window.supabase !== 'undefined' && window.supabase.createClient) {
        window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        console.log('✅ AI-DEPOM: supabaseClient criado');
    } else if (window.supabaseClient) {
        console.log('ℹ️ AI-DEPOM: supabaseClient já existia, mantido');
    } else {
        console.error('❌ AI-DEPOM: window.supabase NÃO carregado! Inclua o CDN antes deste arquivo.');
    }
})();

window.AIDEPOM = {

    // ============================================================
    // SESSÃO — usa localStorage
    // ============================================================
    getUsuario() {
        try {
            const u = localStorage.getItem('usuario');
            // [v2.3.1] Trata "null" string e vazio
            if (!u || u === 'null' || u === 'undefined') return null;
            return JSON.parse(u);
        } catch (e) {
            console.warn('⚠️ Erro ao ler usuario do localStorage:', e);
            return null;
        }
    },

    setUsuario(usuario) {
        if (!usuario) {
            console.warn('⚠️ setUsuario(null) — use limparSessao() para apagar');
            return;
        }
        localStorage.setItem('usuario', JSON.stringify(usuario));
    },

    limparSessao() {
        localStorage.removeItem('usuario');
        localStorage.removeItem('authData');
        localStorage.removeItem('usuarioId');
        localStorage.removeItem('logado');
    },

    // [v2.3.1] Atalho booleano
    isAuthenticated() {
        return !!this.getUsuario();
    },

    verificarSessao(redirecionarPara = '02-login.html') {
        const usuario = this.getUsuario();
        if (!usuario) {
            window.location.href = redirecionarPara;
            return null;
        }
        return usuario;
    },

    // [v2.3.1] Atalho: iniciais do usuário (ex: "Admin Master" → "AM")
    getIniciais(nome) {
        const u = nome || this.getUsuario()?.nome_completo || 'U';
        const partes = u.trim().split(/\s+/);
        if (partes.length === 1) return partes[0][0].toUpperCase();
        return (partes[0][0] + partes[partes.length - 1][0]).toUpperCase();
    },

    // [v2.3.1] ID do perfil do usuário logado
    getPerfilId() {
        return this.getUsuario()?.id_perfil_acesso || null;
    },

    // [v2.3.1] Nome do perfil do usuário logado
    getPerfilNome() {
        const id = this.getPerfilId();
        return id ? this.getNomePerfil(id) : 'Desconhecido';
    },

    // [v2.3.1] Re-lê dados do usuário direto do Supabase (atualiza cache)
    async refreshUsuario() {
        try {
            const { data: { user } } = await window.supabaseClient.auth.getUser();
            if (!user) return null;

            const { data: usuario } = await window.supabaseClient
                .from('usuarios')
                .select('id, matricula, nome_completo, email, ativo, setor, id_perfil_acesso, primeiro_acesso, deletado')
                .eq('id', user.id)
                .maybeSingle();

            if (usuario) {
                this.setUsuario(usuario);
                return usuario;
            }
            return null;
        } catch (error) {
            console.error('❌ Erro ao refreshUsuario:', error);
            return null;
        }
    },

    // ============================================================
    // BUSCAR USUÁRIO POR MATRÍCULA
    // ============================================================
    async buscarUsuarioPorMatricula(matricula) {
        const { data, error } = await window.supabaseClient
            .from('usuarios')
            .select('id, matricula, nome_completo, email, ativo, setor, id_perfil_acesso, primeiro_acesso, deletado')
            .eq('matricula', matricula)
            .maybeSingle();

        if (error && error.code !== 'PGRST116') {
            console.error('Erro ao buscar usuario:', error);
        }

        return { data, error };
    },

    // ============================================================
    // LOGOUT — [ALTERADO v2.3.1] limpeza total
    // ============================================================
    async logout(redirecionarPara = '02-login.html') {
        try {
            await window.supabaseClient.auth.signOut();
        } catch (e) {
            console.warn('Erro no logout Supabase:', e);
        }

        // [v2.3.1] Limpa chaves conhecidas
        this.limparSessao();

        // [v2.3.1] Varre e remove QUALQUER chave AIDEPOM/Supabase que tenha sobrado
        try {
            const remover = [];
            for (let i = 0; i < localStorage.length; i++) {
                const k = localStorage.key(i);
                if (!k) continue;
                if (k.startsWith('aidepom:') || k.startsWith('supabase.') || k.startsWith('sb-')) {
                    remover.push(k);
                }
            }
            remover.forEach(k => localStorage.removeItem(k));
            sessionStorage.clear();
        } catch (e) { /* ignore */ }

        window.location.href = redirecionarPara;
    },

    // ============================================================
    // UI - MENSAGENS
    // ============================================================
    showError(elementId, message) {
        const el = document.getElementById(elementId);
        if (!el) return;
        const span = el.querySelector('span') || el;
        span.textContent = message;
        el.classList.add('show');
    },

    hideError(elementId) {
        const el = document.getElementById(elementId);
        if (el) el.classList.remove('show');
    },

    showSuccess(elementId, message) {
        const el = document.getElementById(elementId);
        if (!el) return;
        const span = el.querySelector('span') || el;
        span.textContent = message;
        el.classList.add('show');
    },

    hideSuccess(elementId) {
        const el = document.getElementById(elementId);
        if (el) el.classList.remove('show');
    },

    setLoading(btn, loading) {
        if (!btn) return;
        if (loading) {
            btn.classList.add('loading');
            btn.disabled = true;
        } else {
            btn.classList.remove('loading');
            btn.disabled = false;
        }
    },

    // ============================================================
    // FASE 4.1 - GERENCIAMENTO DE USUÁRIOS
    // ============================================================

    // [ALTERADO v2.3.1] Verifica MASTER em 'usuarios' (principal) e em 'usuarios_autorizados' (fallback)
    async isAdminMaster() {
        try {
            const { data: { user } } = await window.supabaseClient.auth.getUser();
            if (!user) return false;

            // 1ª tentativa: tabela principal 'usuarios' (id_perfil_acesso === 1 = MASTER)
            const { data: u } = await window.supabaseClient
                .from('usuarios')
                .select('id_perfil_acesso, ativo, deletado')
                .eq('id', user.id)
                .maybeSingle();

            if (u && u.ativo && !u.deletado && u.id_perfil_acesso === 1) {
                return true;
            }

            // 2ª tentativa: fallback tabela 'usuarios_autorizados' (compatibilidade)
            try {
                const { data } = await window.supabaseClient
                    .from('usuarios_autorizados')
                    .select('tipo')
                    .eq('id_usuario', user.id)
                    .eq('ativo', true)
                    .is('data_revogacao', null)
                    .eq('tipo', 'MASTER')
                    .maybeSingle();

                return !!data;
            } catch (e) {
                // Se tabela não existir, apenas ignora
                return false;
            }
        } catch (error) {
            console.error('Erro ao verificar permissao MASTER:', error);
            return false;
        }
    },

    // Criar usuário via Edge Function
    async criarUsuario(dados) {
        try {
            console.log('📤 Chamando Edge Function criar-usuario...');
            console.log('📦 Dados enviados:', dados);

            const { data, error } = await window.supabaseClient.functions.invoke('criar-usuario', {
                body: dados
            });

            if (error) {
                console.error('❌ Erro na Edge Function:', error);
                return { sucesso: false, erro: error.message || 'Erro ao criar usuario' };
            }

            console.log('✅ Resposta da Edge Function:', data);
            return data;
        } catch (error) {
            console.error('❌ Erro inesperado ao criar usuario:', error);
            return { sucesso: false, erro: 'Erro inesperado: ' + error.message };
        }
    },

    // Listar usuários ativos
    async listarUsuarios() {
        try {
            const { data, error } = await window.supabaseClient
                .from('usuarios')
                .select('id, matricula, nome_completo, email, setor, id_perfil_acesso, ativo, primeiro_acesso, data_cadastro')
                .eq('deletado', false)
                .order('data_cadastro', { ascending: false });

            return { data, error };
        } catch (error) {
            console.error('Erro ao listar usuarios:', error);
            return { data: null, error };
        }
    },

    // Buscar usuário por ID
    async buscarUsuarioPorId(id) {
        try {
            const { data, error } = await window.supabaseClient
                .from('usuarios')
                .select('*')
                .eq('id', id)
                .maybeSingle();

            return { data, error };
        } catch (error) {
            console.error('Erro ao buscar usuario por ID:', error);
            return { data: null, error };
        }
    },

    // Atualizar usuário
    async atualizarUsuario(id, dados) {
        try {
            const { data, error } = await window.supabaseClient
                .from('usuarios')
                .update(dados)
                .eq('id', id)
                .select()
                .maybeSingle();

            return { data, error };
        } catch (error) {
            console.error('Erro ao atualizar usuario:', error);
            return { data: null, error };
        }
    },

    // Desativar usuário (soft delete)
    async desativarUsuario(id) {
        try {
            const { data, error } = await window.supabaseClient
                .from('usuarios')
                .update({ ativo: false })
                .eq('id', id)
                .select()
                .maybeSingle();

            return { data, error };
        } catch (error) {
            console.error('Erro ao desativar usuario:', error);
            return { data: null, error };
        }
    },

    // Reativar usuário
    async reativarUsuario(id) {
        try {
            const { data, error } = await window.supabaseClient
                .from('usuarios')
                .update({ ativo: true })
                .eq('id', id)
                .select()
                .maybeSingle();

            return { data, error };
        } catch (error) {
            console.error('Erro ao reativar usuario:', error);
            return { data: null, error };
        }
    },

    // ============================================================
    // PERFIS DE ACESSO
    // ============================================================
    PERFIS: {
        1: 'Administrador Master',
        2: 'Administrador',
        3: 'Delegado',
        4: 'Investigador',
        5: 'Perito',
        6: 'Analista',
        7: 'Consulta Externa'
    },

    getNomePerfil(idPerfil) {
        return this.PERFIS[idPerfil] || 'Desconhecido';
    }
};

console.log('✅ AI-DEPOM: Supabase configurado (v2.3.1) em ' + new Date().toLocaleString('pt-BR'));
