/* ============================================
   AI-DEPOM - Configuracao Supabase
   Versao: 2.0.0
   ============================================ */

const SUPABASE_URL = 'https://szkgaqouivsvlyujfvmz.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6a2dhcW91aXZzdmx5dWpmdm16Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MzY0MjksImV4cCI6MjEwNDExMjQyOX0.4KBCiRxjZZrfaEBqfiFVSp9ECOy37brn1JFC7ga_2Hc';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

window.AIDEPOM = {

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

    async logout(redirecionarPara = '02-login.html') {
        try {
            await window.supabaseClient.auth.signOut();
        } catch (e) {
            console.warn('Erro no logout:', e);
        }
        this.limparSessao();
        window.location.href = redirecionarPara;
    },

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

    async criarUsuario(dados) {
        try {
            const { data, error } = await window.supabaseClient.functions.invoke('criar-usuario', {
                body: dados
            });

            if (error) {
                console.error('Erro na Edge Function:', error);
                return { sucesso: false, erro: error.message || 'Erro ao criar usuario' };
            }

            return data;
        } catch (error) {
            console.error('Erro inesperado ao criar usuario:', error);
            return { sucesso: false, erro: 'Erro inesperado: ' + error.message };
        }
    },

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

console.log('AI-DEPOM: Supabase configurado (v2.0.0)');
