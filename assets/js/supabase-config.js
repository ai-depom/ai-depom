 // ============================================================
// AI-DEPOM - CONFIGURAÇÃO SUPABASE
// ============================================================
// Arquivo: assets/js/supabase-config.js
// Versão: 2.2.0
// Data: 11/09/2026 - 17:00
// Autor: AI-DEPOM Team
// ============================================================
// ALTERAÇÕES RECENTES:
// - [11/09/2026 17:00] Adicionada função criarUsuario()
// - [11/09/2026 17:00] Adicionada função listarUsuarios()
// - [11/09/2026 17:00] Adicionada função isAdminMaster()
// ============================================================

const SUPABASE_URL = 'https://szkgaqouivsvlyujfvmz.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6a2dhcW91aXZzdmx5dWpmdm16Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MzY0MjksImV4cCI6MjEwNDExMjQyOX0.4KBCiRxjZZrfaEBqfiFVSp9ECOy37brn1JFC7ga_2Hc';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

window.AIDEPOM = {

    // ============================================================
    // SESSÃO
    // Data: 11/09/2026 - 17:00
    // ============================================================
    getUsuario() {
        const u = sessionStorage.getItem('usuario');
        return u ? JSON.parse(u) : null;
    },

    setUsuario(usuario) {
        sessionStorage.setItem('usuario', JSON.stringify(usuario));
    },

    limparSessao() {
        sessionStorage.removeItem('usuario');
        sessionStorage.removeItem('authData');
        sessionStorage.removeItem('usuarioId');
        sessionStorage.removeItem('logado');
    },

    verificarSessao(redirecionarPara = '02-login.html') {
        const usuario = this.getUsuario();
        if (!usuario) {
            window.location.href = redirecionarPara;
            return null;
        }
        return usuario;
    },

    // ============================================================
    // BUSCAR USUÁRIO POR MATRÍCULA
    // Data: 11/09/2026 - 17:00
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
    // LOGOUT
    // Data: 11/09/2026 - 17:00
    // ============================================================
    async logout(redirecionarPara = '02-login.html') {
        try {
            await window.supabaseClient.auth.signOut();
        } catch (e) {
            console.warn('Erro no logout:', e);
        }
        this.limparSessao();
        window.location.href = redirecionarPara;
    },

    // ============================================================
    // UI - MENSAGENS
    // Data: 11/09/2026 - 17:00
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
    // Data: 11/09/2026 - 17:00
    // ============================================================

    // Verificar se o usuário logado é Administrador Master
    async isAdminMaster() {
        try {
            const { data: { user } } = await window.supabaseClient.auth.getUser();
            if (!user) return false;

            const { data } = await window.supabaseClient
                .from('usuarios_autorizados')
                .select('tipo')
                .eq('id_usuario', user.id)
                .eq('ativo', true)
                .is('data_revogacao', null)
                .eq('tipo', 'MASTER')
                .maybeSingle();

            return !!data;
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
    // Data: 11/09/2026 - 17:00
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

console.log('✅ AI-DEPOM: Supabase configurado (v2.2.0) em ' + new Date().toLocaleString('pt-BR'));
