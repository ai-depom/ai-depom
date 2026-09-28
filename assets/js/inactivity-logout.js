/* ============================================
   AI-DEPOM - LOGOUT POR INATIVIDADE
   ============================================
   Arquivo: assets/js/inactivity-logout.js
   Versao: 1.2.0
   Data: 28/09/2026 - 12:00
   Autor: AI-DEPOM Team
   ============================================
   REGRA DE OURO:
   1. Zero placeholders quebrados
   2. Zero TODOs esquecidos
   3. Zero duplicações
   4. Toda função referenciada DEVE existir
   5. Todo botão DEVE ter handler real
   6. Todo módulo DEVE estar conectado
   7. Nenhuma linha deve ser removida sem substituição
   ============================================
   COMPORTAMENTO FINAL (definido pelo Souza):

   • Usuário ativo        → timer reinicia a cada interação
   • 4 min sem atividade  → toast amarelo com contagem + botão
                            [Continuar logado]
   • Usuário clica        → timer reinicia, toast some
   • Usuário NÃO clica    → aos 5 min, LOGOUT AUTOMÁTICO
                            → supabaseClient.auth.signOut()
                            → window.location.href = '02-login.html'
   • Usuário loga de novo → nova sessão do zero

   ALTERAÇÕES v1.2.0 (28/09/2026 12:00):
   - ✅ COMPORTAMENTO FINAL:
     - Toast de 4min TEM o botão "Continuar logado"
     - Sem modal de confirmação aos 5min
     - Logout é direto aos 5min
   - ✅ Toast de aviso é fixo no topo, visível em qualquer página
   - ✅ Contagem regressiva em tempo real
   - ✅ Sincronização entre abas
   - ✅ Redireciona para 02-login.html SEMPRE

   ALTERAÇÕES v1.1.0 (28/09/2026 11:00):
   - Logout direto (sem botão no aviso)

   ALTERAÇÕES v1.0.0 (28/09/2026 10:00):
   - Sistema inicial com modal
   ============================================ */

(function() {
    'use strict';

    // ============================================
    // GUARDA — evita dupla inicialização
    // ============================================
    if (window.__AIDEPOM_INACTIVITY_LOGOUT_INIT__) {
        console.log('ℹ️ inactivity-logout.js já foi inicializado. Ignorando.');
        return;
    }

    // ============================================
    // CONFIGURAÇÕES
    // ============================================
    const TIMEOUT_MS  = 5 * 60 * 1000;      // 5 minutos de inatividade
    const WARNING_MS  = 1 * 60 * 1000;      // Aviso 1 minuto antes
    const LOGIN_URL   = '02-login.html';    // Página de destino

    const LOGOUT_SIGNAL_KEY = 'aidepom_logout_signal';
    const ACTIVITY_KEY      = 'aidepom_last_activity';

    let ultimaAtividade  = Date.now();
    let timeoutId        = null;
    let warningId        = null;
    let countdownId      = null;
    let logoutEmAndamento = false;
    let segundosRestantes = 60;

    // ============================================
    // VERIFICA SE ESTÁ LOGADO
    // ============================================
    function estaLogado() {
        try {
            const u = localStorage.getItem('usuario');
            if (!u || u === 'null' || u === 'undefined') return false;
            const parsed = JSON.parse(u);
            return !!(parsed && parsed.id);
        } catch (e) {
            return false;
        }
    }

    // ============================================
    // CRIAR ELEMENTOS (APENAS O TOAST)
    // ============================================
    function criarElementos() {
        if (document.getElementById('logout-warning-toast')) return;

        // ---------- CSS ----------
        const style = document.createElement('style');
        style.id = 'inactivity-logout-style';
        style.textContent = `
            .logout-warning-toast {
                position: fixed;
                top: 65px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(255, 193, 7, 0.15);
                border: 1px solid #ffc107;
                color: #ffc107;
                padding: 14px 22px;
                border-radius: 10px;
                font-size: 14px;
                z-index: 2147483646;
                display: none;
                backdrop-filter: blur(20px);
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.8);
                align-items: center;
                gap: 15px;
                font-weight: 600;
                flex-wrap: wrap;
                justify-content: center;
                max-width: calc(100vw - 40px);
                animation: logoutSlideDown 0.3s ease;
            }
            .logout-warning-toast.show { display: flex; }
            .logout-warning-toast i.fa-exclamation-triangle {
                font-size: 20px;
            }
            .logout-warning-toast .logout-btn-continuar {
                background: rgba(255, 193, 7, 0.2);
                border: 1px solid #ffc107;
                color: #ffc107;
                padding: 7px 16px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 12px;
                font-weight: 700;
                transition: all 0.3s;
                white-space: nowrap;
                font-family: inherit;
            }
            .logout-warning-toast .logout-btn-continuar:hover {
                background: #ffc107;
                color: #000;
                transform: translateY(-1px);
            }
            .logout-warning-toast .logout-btn-continuar:active {
                transform: translateY(0);
            }
            @keyframes logoutSlideDown {
                from { transform: translateX(-50%) translateY(-20px); opacity: 0; }
                to   { transform: translateX(-50%) translateY(0);     opacity: 1; }
            }
        `;
        document.head.appendChild(style);

        // ---------- TOAST ----------
        const toast = document.createElement('div');
        toast.id = 'logout-warning-toast';
        toast.className = 'logout-warning-toast';
        toast.innerHTML = `
            <i class="fas fa-exclamation-triangle"></i>
            <span>Sua sessão será encerrada em <strong id="logout-countdown">1:00</strong></span>
            <button type="button" class="logout-btn-continuar" id="logoutBtnContinuar">
                Continuar logado
            </button>
        `;
        document.body.appendChild(toast);

        // Bind do botão
        document.getElementById('logoutBtnContinuar').addEventListener('click', continuarLogado);
    }

    // ============================================
    // REGISTRAR ATIVIDADE
    // ============================================
    function registrarAtividade() {
        if (logoutEmAndamento) return;
        ultimaAtividade = Date.now();
        try {
            localStorage.setItem(ACTIVITY_KEY, Date.now().toString());
        } catch (e) { /* ignore */ }
        resetarTimers();
    }

    function limparTimers() {
        clearTimeout(timeoutId);
        clearTimeout(warningId);
        clearInterval(countdownId);
        timeoutId   = null;
        warningId   = null;
        countdownId = null;
    }

    function resetarTimers() {
        limparTimers();

        // Esconde toast se estiver visível
        const toast = document.getElementById('logout-warning-toast');
        if (toast) toast.classList.remove('show');

        // Aviso em 4 min
        warningId = setTimeout(() => {
            mostrarAviso();
        }, TIMEOUT_MS - WARNING_MS);

        // Logout em 5 min
        timeoutId = setTimeout(() => {
            executarLogout();
        }, TIMEOUT_MS);
    }

    // ============================================
    // MOSTRAR AVISO (4 MIN)
    // ============================================
    function mostrarAviso() {
        if (logoutEmAndamento) return;

        const toast     = document.getElementById('logout-warning-toast');
        const countdown = document.getElementById('logout-countdown');
        if (!toast || !countdown) return;

        toast.classList.add('show');
        segundosRestantes = 60;

        function atualizar() {
            const m = Math.floor(segundosRestantes / 60);
            const s = segundosRestantes % 60;
            countdown.textContent = `${m}:${s.toString().padStart(2, '0')}`;
        }

        atualizar();

        countdownId = setInterval(() => {
            segundosRestantes--;
            if (segundosRestantes > 0) {
                atualizar();
            } else {
                clearInterval(countdownId);
                countdownId = null;
            }
        }, 1000);
    }

    // ============================================
    // CONTINUAR LOGADO (BOTÃO DO TOAST)
    // ============================================
    function continuarLogado() {
        if (logoutEmAndamento) return;
        console.log('🔄 [inactivity-logout] Usuário clicou em "Continuar logado"');

        const toast = document.getElementById('logout-warning-toast');
        if (toast) toast.classList.remove('show');

        // Reset completo: reinicia os timers e zera a contagem
        ultimaAtividade = Date.now();
        try {
            localStorage.setItem(ACTIVITY_KEY, Date.now().toString());
        } catch (e) { /* ignore */ }

        resetarTimers();
        console.log('✅ [inactivity-logout] Sessão estendida por mais 5 minutos');
    }

    // ============================================
    // EXECUTAR LOGOUT (5 MIN) — SEM MODAL
    // ============================================
    async function executarLogout() {
        if (logoutEmAndamento) return;
        logoutEmAndamento = true;
        limparTimers();

        console.log('🚪 [inactivity-logout] Logout automático por inatividade (5 min)...');

        try {
            // 1. Sinaliza para outras abas
            try {
                localStorage.setItem(LOGOUT_SIGNAL_KEY, Date.now().toString());
            } catch (e) { /* ignore */ }

            // 2. Limpa sessão do Supabase
            if (window.supabaseClient && window.supabaseClient.auth) {
                await window.supabaseClient.auth.signOut();
            }

            // 3. Limpa storage local
            try {
                localStorage.removeItem('usuario');
                localStorage.removeItem('authData');
                localStorage.removeItem('usuarioId');
                localStorage.removeItem('logado');
                localStorage.removeItem(LOGOUT_SIGNAL_KEY);
                localStorage.removeItem(ACTIVITY_KEY);
                sessionStorage.clear();
            } catch (e) { /* ignore */ }

            // 4. Redireciona para login
            console.log('🔒 Redirecionando para', LOGIN_URL);
            window.location.href = LOGIN_URL;

        } catch (e) {
            console.error('❌ [inactivity-logout] Erro no logout:', e);
            window.location.href = LOGIN_URL;   // fallback
        }
    }

    // ============================================
    // SINCRONIZAÇÃO ENTRE ABAS
    // ============================================
    window.addEventListener('storage', function(e) {
        if (e.key === LOGOUT_SIGNAL_KEY && e.newValue && !logoutEmAndamento) {
            console.log('🔓 [inactivity-logout] Outra aba fez logout. Sincronizando...');
            logoutEmAndamento = true;
            limparTimers();
            try {
                localStorage.removeItem('usuario');
                localStorage.removeItem('authData');
                localStorage.removeItem('usuarioId');
                localStorage.removeItem('logado');
                sessionStorage.clear();
            } catch (err) { /* ignore */ }
            window.location.href = LOGIN_URL;
        }

        if (e.key === ACTIVITY_KEY && e.newValue && !logoutEmAndamento) {
            const activityTime = parseInt(e.newValue);
            if (activityTime > ultimaAtividade) {
                ultimaAtividade = activityTime;
                resetarTimers();
            }
        }
    });

    // ============================================
    // INICIALIZAÇÃO
    // ============================================
    function init() {
        if (!estaLogado()) {
            console.log('ℹ️ inactivity-logout: usuário não logado.');
            return;
        }

        criarElementos();
        registrarAtividade();

        ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart', 'click'].forEach(evento => {
            document.addEventListener(evento, registrarAtividade, { passive: true });
        });

        document.addEventListener('visibilitychange', function() {
            if (!document.hidden && !logoutEmAndamento) {
                registrarAtividade();
            }
        });

        window.__AIDEPOM_INACTIVITY_LOGOUT_INIT__ = true;
        console.log('✅ Logout por inatividade ativo (5 minutos) [v1.2.0]');
    }

    function aguardarSupabaseClient(callback, tentativas = 0) {
        if (window.supabaseClient && window.supabaseClient.auth) {
            callback();
            return;
        }
        if (tentativas > 50) {
            console.warn('⚠️ inactivity-logout: supabaseClient não disponível após 5s');
            callback();
            return;
        }
        setTimeout(() => aguardarSupabaseClient(callback, tentativas + 1), 100);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            aguardarSupabaseClient(init);
        });
    } else {
        aguardarSupabaseClient(init);
    }
})();
