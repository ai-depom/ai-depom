 /* ============================================
   AI-DEPOM - TEMPORIZADOR DE INATIVIDADE
   ============================================
   Arquivo: assets/js/inactivity-lock.js
   Versao: 2.1.1
   Data: 24/09/2026 - 16:30
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

   ALTERAÇÕES v2.1.1 (24/09/2026 16:30):
   - 🐛 CORRIGIDO: Bug do recarregar (🔄) com tela bloqueada
     CAUSA: beforeunload limpava a flag RELOADING_KEY mesmo
     quando a tela estava bloqueada, fazendo o verificarLockPendente()
     não re-aplicar o lock.
     FIX (3 pontos, cirúrgico):
     1. registrarBeforeUnload() — só limpa a flag se o valor
        for 'unlocked' (nunca se for 'true')
     2. desbloquear() — marca flag como 'unlocked' em vez de
        removeItem (sinaliza que o usuário desbloqueou de propósito)
     3. bloqueado() — continua marcando 'true' (comportamento correto)
   - ✅ PRESERVADO: TUDO da v2.1.0

   ALTERAÇÕES v2.1.0 (24/09/2026 15:30):
   - 🐛 CORRIGIDO: Bug do botão 🔄 (recarregar) do browser
     quando a tela NÃO estava bloqueada.
     - Causa: LOCK_KEY persistia em localStorage e era
       re-aplicado sem validar se havia reload real.
     - Fix: nova flag sessionStorage 'aidepom_reloading'
       que só é marcada quando o beforeunload é acionado
       COM bloqueio ativo.
     - Fix: verificarLockPendente() valida a flag antes
       de re-aplicar o lock.
     - Fix: lock "grudado" (>5min) é ignorado e limpo.
   - 🐛 CORRIGIDO: Aviso chato do browser em todo reload
     (beforeunload sempre ativo). Agora só ativa quando
     bloqueado.
   - 🐛 CORRIGIDO: Resíduos no desbloqueio.
     Agora limpa LOCK_KEY + LOCK_AT_KEY + aidepom_reloading.
   - ✨ NOVO: Modo Dev (localStorage.aidepom_dev_mode)
     libera F12 e DevTools para desenvolvimento.
   - ✅ PRESERVADO: TUDO da v2.0.0 (F5, Ctrl+R, F12,
     sincronização entre abas, anti-autofill, guards).

   ALTERAÇÕES v2.0.0 (21/09/2026 13:00):
   - F5 / Ctrl+R / Ctrl+Shift+R / Ctrl+F5 bloqueados
   - beforeunload avisa ao recarregar bloqueado
   - MutationObserver detecta remoção COMPLETA do DOM
   - Bloqueio de F12 / Ctrl+Shift+I / Ctrl+Shift+J / Ctrl+U
   - Sincronização entre abas via storage event
   - Guarda ativa com getElementById a cada tick
   ============================================ */

(function() {
    'use strict';

    // ============================================
    // GUARDA — evita dupla inicialização
    // ============================================
    if (window.__AIDEPOM_INACTIVITY_LOCK_INIT__) {
        console.log('ℹ️ inactivity-lock.js já foi inicializado. Ignorando.');
        return;
    }

    // ============================================
    // CONFIGURACOES
    // ============================================
    const TIMEOUT_MS = 5 * 60 * 1000;      // 5 minutos
    const WARNING_MS = 1 * 60 * 1000;      // Aviso 1 minuto antes
    const CHECK_INTERVAL_MS = 1000;
    const LOCK_MAX_AGE_MS = 24 * 60 * 60 * 1000;  // 24 horas
    const LOCK_STUCK_MS = 5 * 60 * 1000;   // Lock "grudado" após 5min

    // Chaves do localStorage
    const LOCK_KEY = 'aidepom_locked';
    const LOCK_AT_KEY = 'aidepom_locked_at';
    const LOCK_SIGNAL_KEY = 'aidepom_lock_signal';
    const UNLOCK_SIGNAL_KEY = 'aidepom_unlock_signal';
    const RELOADING_KEY = 'aidepom_reloading';

    // [v2.1.0] Modo Dev — libera F12 / DevTools
    const MODO_DEV = (function() {
        try { return localStorage.getItem('aidepom_dev_mode') === 'true'; }
        catch (e) { return false; }
    })();

    let timeoutId = null;
    let warningId = null;
    let countdownId = null;
    let lockGuardId = null;
    let domObserver = null;
    let ultimaAtividade = Date.now();
    let bloqueado = false;
    let segundosRestantes = 0;

    // Flag: o usuário DIGITOU a senha ou foi autofill?
    let senhaDigitadaPeloUsuario = false;

    // ============================================
    // CRIAR ELEMENTOS DINAMICAMENTE
    // ============================================
    function criarElementos() {
        if (document.getElementById('inactivity-lock-container')) {
            return;
        }

        const style = document.createElement('style');
        style.id = 'inactivity-lock-style';
        style.textContent = `
            .lock-screen {
                position: fixed;
                top: 0; left: 0; right: 0; bottom: 0;
                background: rgba(0, 0, 0, 0.98);
                backdrop-filter: blur(20px);
                z-index: 99999;
                display: none;
                align-items: center;
                justify-content: center;
                padding: 20px;
                animation: lockFadeIn 0.3s ease;
            }
            .lock-screen.show { display: flex; }

            @keyframes lockFadeIn {
                from { opacity: 0; }
                to { opacity: 1; }
            }

            .lock-box {
                background: #0a0a0a;
                border: 1px solid #003322;
                border-radius: 20px;
                padding: 40px 35px;
                max-width: 420px;
                width: 100%;
                text-align: center;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.8);
                position: relative;
                overflow: hidden;
            }
            .lock-box::before {
                content: '';
                position: absolute;
                top: 0; left: 0; right: 0;
                height: 4px;
                background: linear-gradient(135deg, #00ff88 0%, #00cc77 100%);
                background-size: 200% 100%;
                animation: lockGradientMove 3s ease infinite;
            }
            @keyframes lockGradientMove {
                0%, 100% { background-position: 0% 50%; }
                50% { background-position: 100% 50%; }
            }

            .lock-icon {
                font-size: 60px;
                color: #00ff88;
                margin-bottom: 15px;
                animation: lockPulse 2s ease-in-out infinite;
            }
            @keyframes lockPulse {
                0%, 100% { transform: scale(1); opacity: 1; }
                50% { transform: scale(1.1); opacity: 0.7; }
            }

            .lock-title {
                color: #00ff88;
                font-size: 22px;
                font-weight: 700;
                letter-spacing: 2px;
                margin-bottom: 8px;
            }
            .lock-subtitle {
                color: rgba(0, 255, 136, 0.4);
                font-size: 13px;
                letter-spacing: 1px;
                margin-bottom: 25px;
            }
            .lock-user-info {
                background: rgba(0, 255, 136, 0.03);
                border: 1px solid #003322;
                border-radius: 10px;
                padding: 12px;
                margin-bottom: 20px;
                display: flex;
                align-items: center;
                gap: 12px;
                text-align: left;
            }
            .lock-user-info .avatar {
                width: 40px;
                height: 40px;
                border-radius: 50%;
                background: linear-gradient(135deg, #00ff88 0%, #00cc77 100%);
                display: flex;
                align-items: center;
                justify-content: center;
                font-weight: 700;
                font-size: 16px;
                color: #000;
                flex-shrink: 0;
            }
            .lock-user-info .info {
                flex: 1;
                min-width: 0;
            }
            .lock-user-info .name {
                color: #00ff88;
                font-size: 14px;
                font-weight: 600;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
            }
            .lock-user-info .email {
                color: rgba(0, 255, 136, 0.4);
                font-size: 11px;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
            }

            .lock-timer {
                color: rgba(0, 255, 136, 0.3);
                font-size: 12px;
                letter-spacing: 1px;
                margin-bottom: 20px;
                padding: 10px;
                background: rgba(0, 0, 0, 0.3);
                border-radius: 8px;
                border: 1px solid #003322;
            }
            .lock-timer strong {
                color: #00ff88;
                font-size: 14px;
            }
            .lock-form { text-align: left; }
            .lock-form .form-group { margin-bottom: 15px; }
            .lock-form label {
                display: block;
                font-size: 12px;
                font-weight: 600;
                color: rgba(0, 255, 136, 0.5);
                margin-bottom: 8px;
                letter-spacing: 1px;
                text-transform: uppercase;
            }
            .lock-form input {
                width: 100%;
                padding: 12px 16px;
                background: rgba(0, 0, 0, 0.5);
                border: 1px solid #003322;
                border-radius: 10px;
                color: #00ff88;
                font-size: 14px;
                transition: all 0.3s;
            }
            .lock-form input:focus {
                outline: none;
                border-color: #00ff88;
                box-shadow: 0 0 0 4px rgba(0, 255, 136, 0.08);
            }
            .lock-form input::placeholder {
                color: rgba(0, 255, 136, 0.15);
            }
            .lock-form input[readonly] {
                background: rgba(0, 0, 0, 0.7);
                cursor: pointer;
                border-color: rgba(0, 255, 136, 0.2);
            }
            .lock-form input[readonly]::placeholder {
                color: rgba(0, 255, 136, 0.5);
            }
            .lock-btn {
                width: 100%;
                padding: 14px;
                background: linear-gradient(135deg, #00ff88 0%, #00cc77 100%);
                color: #000;
                border: none;
                border-radius: 10px;
                font-size: 15px;
                font-weight: 700;
                cursor: pointer;
                transition: all 0.3s;
                letter-spacing: 1px;
                margin-top: 10px;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 10px;
            }
            .lock-btn:hover:not(:disabled) {
                transform: translateY(-2px);
                box-shadow: 0 10px 30px rgba(0, 255, 136, 0.3);
            }
            .lock-btn:disabled {
                opacity: 0.5;
                cursor: not-allowed;
            }
            .lock-error {
                display: none;
                background: rgba(220, 53, 69, 0.1);
                color: #dc3545;
                padding: 10px 14px;
                border-radius: 8px;
                font-size: 13px;
                margin-bottom: 15px;
                border-left: 3px solid #dc3545;
                text-align: left;
            }
            .lock-error.show { display: block; }
            .lock-logout {
                background: none;
                border: none;
                color: rgba(0, 255, 136, 0.3);
                font-size: 12px;
                cursor: pointer;
                margin-top: 15px;
                letter-spacing: 1px;
            }
            .lock-logout:hover {
                color: #dc3545;
                text-decoration: underline;
            }
            .lock-warning-toast {
                position: fixed;
                top: 65px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(255, 193, 7, 0.15);
                border: 1px solid #ffc107;
                color: #ffc107;
                padding: 12px 25px;
                border-radius: 10px;
                font-size: 13px;
                z-index: 99998;
                display: none;
                backdrop-filter: blur(20px);
                animation: lockSlideDown 0.3s ease;
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.8);
            }
            .lock-warning-toast.show { display: block; }
            @keyframes lockSlideDown {
                from { transform: translateX(-50%) translateY(-20px); opacity: 0; }
                to { transform: translateX(-50%) translateY(0); opacity: 1; }
            }
        `;
        document.head.appendChild(style);

        const html = document.createElement('div');
        html.id = 'inactivity-lock-container';
        html.innerHTML = `
            <div class="lock-warning-toast" id="lockWarningToast">
                <i class="fas fa-exclamation-triangle"></i>
                <span id="lockWarningText">Sessao expira em <strong>1 minuto</strong></span>
            </div>

            <div class="lock-screen" id="lockScreen">
                <div class="lock-box">
                    <div class="lock-icon"><i class="fas fa-lock"></i></div>
                    <div class="lock-title">SESSAO BLOQUEADA</div>
                    <div class="lock-subtitle">Por inatividade</div>

                    <div class="lock-user-info">
                        <div class="avatar" id="lockUserAvatar">?</div>
                        <div class="info">
                            <div class="name" id="lockUserName">Usuario</div>
                            <div class="email" id="lockUserEmail">email@exemplo.com</div>
                        </div>
                    </div>

                    <div class="lock-timer">
                        <i class="fas fa-clock"></i> Bloqueado em <strong id="lockTime">--:--</strong>
                    </div>

                    <div class="lock-error" id="lockError"></div>

                    <div class="lock-form">
                        <div class="form-group">
                            <label for="lockSenha">Digite sua senha para desbloquear</label>
                            <input type="password" id="lockSenha" placeholder="Clique aqui e digite sua senha" autocomplete="new-password" readonly>
                        </div>
                        <button type="button" class="lock-btn" id="lockBtn">
                            <i class="fas fa-unlock"></i> DESBLOQUEAR
                        </button>
                        <button type="button" class="lock-logout" id="lockLogout">
                            <i class="fas fa-sign-out-alt"></i> Sair do sistema
                        </button>
                    </div>
                </div>
            </div>
        `;
        document.body.appendChild(html);
    }

    // ============================================
    // Verifica se está logado
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
    // [v2.1.1] Verifica lock pendente (com validação de reload)
    // ============================================
    function verificarLockPendente() {
        try {
            const locked = localStorage.getItem(LOCK_KEY);
            if (locked !== 'true') return false;

            const lockedAt = parseInt(localStorage.getItem(LOCK_AT_KEY) || '0');
            const agora = Date.now();
            const tempoDecorrido = agora - lockedAt;

            // Lock "grudado" há mais de 5min? Ignora e limpa.
            if (tempoDecorrido > LOCK_STUCK_MS) {
                console.warn('🛡️ [v2.1.1] Lock antigo detectado (>5min). Limpando...');
                try {
                    localStorage.removeItem(LOCK_KEY);
                    localStorage.removeItem(LOCK_AT_KEY);
                    sessionStorage.removeItem(RELOADING_KEY);
                } catch (e) { /* ignore */ }
                return false;
            }

            // Lock expirado (>24h)? Force logout.
            if (tempoDecorrido > LOCK_MAX_AGE_MS || lockedAt === 0) {
                console.warn('🛡️ [v2.1.1] Lock expirado (>24h). Forçando logout.');
                try {
                    localStorage.removeItem(LOCK_KEY);
                    localStorage.removeItem(LOCK_AT_KEY);
                    localStorage.removeItem('usuario');
                    localStorage.removeItem('authData');
                    localStorage.removeItem('usuarioId');
                    localStorage.removeItem('logado');
                    sessionStorage.removeItem(RELOADING_KEY);
                } catch (e) { /* ignore */ }
                window.location.href = '02-login.html';
                return false;
            }

            // [v2.1.1] Só re-aplica se a flag estiver EXATAMENTE como 'true'
            // (nunca se for 'unlocked' ou null)
            const estadoReload = sessionStorage.getItem(RELOADING_KEY);
            if (estadoReload !== 'true') {
                console.log('🛡️ [v2.1.1] Flag de reload não está como "true" (valor:', estadoReload, '). Ignorando.');
                try {
                    localStorage.removeItem(LOCK_KEY);
                    localStorage.removeItem(LOCK_AT_KEY);
                    sessionStorage.removeItem(RELOADING_KEY);
                } catch (e) { /* ignore */ }
                return false;
            }

            console.log('🔒 [v2.1.1] Lock pendente VÁLIDO. Re-aplicando...');
            console.log('⏱️ Bloqueado há', Math.round(tempoDecorrido / 1000), 'segundos');
            return true;

        } catch (e) {
            console.warn('⚠️ Erro ao verificar lock pendente:', e);
            return false;
        }
    }

    function aguardarSupabaseClient(callback, tentativas = 0) {
        if (window.supabaseClient && window.supabaseClient.auth) {
            callback();
            return;
        }
        if (tentativas > 50) {
            console.warn('⚠️ inactivity-lock: supabaseClient não disponível após 5s');
            callback();
            return;
        }
        setTimeout(() => aguardarSupabaseClient(callback, tentativas + 1), 100);
    }

    // ============================================
    // PROTEÇÃO CONTRA TECLAS DE RELOAD
    // ============================================
    function bloquearTeclasQuandoBloqueado() {
        // [v2.1.0] Modo Dev — libera F12 se ativado
        if (MODO_DEV) {
            console.log('🧪 [v2.1.1] Modo Dev ativo — DevTools liberado');
            return;
        }

        document.addEventListener('keydown', function(e) {
            if (!bloqueado) return;

            // F5
            if (e.key === 'F5' || e.keyCode === 116) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.1.1] F5 bloqueado');
                return false;
            }

            // Ctrl+F5 (hard reload)
            if ((e.ctrlKey || e.metaKey) && e.key === 'F5') {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }

            // Ctrl+R / Cmd+R
            if ((e.ctrlKey || e.metaKey) && !e.shiftKey && (e.key === 'r' || e.key === 'R')) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.1.1] Ctrl+R bloqueado');
                return false;
            }

            // Ctrl+Shift+R / Cmd+Shift+R (hard reload)
            if ((e.ctrlKey || e.metaKey) && e.shiftKey && (e.key === 'r' || e.key === 'R')) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.1.1] Ctrl+Shift+R bloqueado');
                return false;
            }

            // F12 / Ctrl+Shift+I / Ctrl+Shift+J / Ctrl+U (anti-DevTools)
            if (
                e.key === 'F12' ||
                ((e.ctrlKey || e.metaKey) && e.shiftKey && ['I', 'i', 'J', 'j'].includes(e.key)) ||
                ((e.ctrlKey || e.metaKey) && (e.key === 'u' || e.key === 'U'))
            ) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.1.1] DevTools bloqueado');
                return false;
            }
        }, true);
    }

    // ============================================
    // [v2.1.1] AVISO AO RECARREGAR BLOQUEADO
    // ------------------------------------------------------------
    // FIX CIRÚRGICO: só limpa a flag se o valor for 'unlocked'.
    // Se for 'true' (bloqueado), NUNCA limpa — deixa persistir.
    // ============================================
    function registrarBeforeUnload() {
        window.addEventListener('beforeunload', function(e) {
            if (bloqueado) {
                // Marca que está saindo COM bloqueio ativo
                try {
                    sessionStorage.setItem(RELOADING_KEY, 'true');
                } catch (err) { /* ignore */ }

                e.preventDefault();
                e.returnValue = 'A sessão está bloqueada. Recarregar NÃO irá desbloquear.';
                return e.returnValue;
            }
            // [v2.1.1] Só limpa se o usuário desbloqueou de propósito
            // (flag === 'unlocked'). Se for 'true', deixa persistir.
            try {
                if (sessionStorage.getItem(RELOADING_KEY) === 'unlocked') {
                    sessionStorage.removeItem(RELOADING_KEY);
                    console.log('🛡️ [v2.1.1] Flag "unlocked" limpa no beforeunload');
                }
                // Se for 'true', NÃO faz nada — deixa o lock persistir
            } catch (err) { /* ignore */ }
        });
    }

    // ============================================
    // MUTATION OBSERVER (detecta remoção do nó DOM)
    // ============================================
    function registrarDomObserver() {
        if (domObserver) return;

        domObserver = new MutationObserver(function() {
            if (!bloqueado) return;
            const overlay = document.getElementById('lockScreen');
            if (!overlay) {
                console.warn('🛡️ [v2.1.1] Overlay REMOVIDO do DOM. Recriando...');
                criarElementos();
                const novo = document.getElementById('lockScreen');
                if (novo) novo.classList.add('show');
                rebindHandlersAposRecriar();
            } else if (!overlay.classList.contains('show')) {
                console.warn('🛡️ [v2.1.1] Classe .show removida. Re-aplicando...');
                overlay.classList.add('show');
            }
        });

        domObserver.observe(document.body, { childList: true, subtree: true });
    }

    let rebindHandlersAposRecriar = function() {
        console.warn('⚠️ Handlers ainda não foram bindados (init não rodou).');
    };

    // ============================================
    // INICIALIZACAO
    // ============================================
    function init() {
        if (!estaLogado()) {
            console.log('ℹ️ inactivity-lock: usuário não logado, timers não iniciados.');
            return;
        }

        criarElementos();

        const lockScreen = document.getElementById('lockScreen');
        const warningToast = document.getElementById('lockWarningToast');
        const warningText = document.getElementById('lockWarningText');
        const lockTime = document.getElementById('lockTime');
        const lockError = document.getElementById('lockError');
        const lockBtn = document.getElementById('lockBtn');
        const lockLogout = document.getElementById('lockLogout');
        const lockSenha = document.getElementById('lockSenha');
        const lockUserAvatar = document.getElementById('lockUserAvatar');
        const lockUserName = document.getElementById('lockUserName');
        const lockUserEmail = document.getElementById('lockUserEmail');

        // ============================================
        // 🛡️ PROTEÇÃO: intercepta classList.remove/toggle
        // ============================================
        const _originalRemove = DOMTokenList.prototype.remove;
        const _originalToggle = DOMTokenList.prototype.toggle;
        const _originalAdd = DOMTokenList.prototype.add;

        DOMTokenList.prototype.remove = function(...args) {
            if (this === lockScreen.classList && args.includes('show') && bloqueado) {
                console.warn('🛡️ [lock] Tentativa de remover .show bloqueada');
                return;
            }
            return _originalRemove.apply(this, args);
        };

        DOMTokenList.prototype.toggle = function(...args) {
            if (this === lockScreen.classList && args[0] === 'show' && bloqueado) {
                console.warn('🛡️ [lock] Tentativa de toggle .show bloqueada');
                return;
            }
            return _originalToggle.apply(this, args);
        };

        // ============================================
        // 🛡️ GUARDA ATIVA (re-query a cada tick)
        // ============================================
        function ativarGuarda() {
            if (lockGuardId) return;
            lockGuardId = setInterval(() => {
                if (!bloqueado) return;

                const overlay = document.getElementById('lockScreen');

                if (!overlay) {
                    console.warn('🛡️ [guarda] Overlay ausente. Recriando...');
                    criarElementos();
                    const novo = document.getElementById('lockScreen');
                    if (novo) novo.classList.add('show');
                    return;
                }

                if (!overlay.classList.contains('show')) {
                    console.warn('🛡️ [guarda] Classe .show removida. Re-aplicando...');
                    overlay.classList.add('show');
                }
            }, 500);
        }

        function desativarGuarda() {
            if (lockGuardId) {
                clearInterval(lockGuardId);
                lockGuardId = null;
            }
        }

        // ============================================
        // Controle de digitação real (anti-autofill)
        // ============================================
        function resetarFlagDigitacao() {
            senhaDigitadaPeloUsuario = false;
            lockSenha.value = '';
            lockSenha.setAttribute('readonly', 'true');
            lockSenha.placeholder = 'Clique aqui e digite sua senha';
        }

        lockSenha.addEventListener('focus', function() {
            if (lockSenha.hasAttribute('readonly')) {
                lockSenha.removeAttribute('readonly');
                lockSenha.placeholder = 'Digite sua senha';
                console.log('🔓 [v2.1.1] readonly removido, pode digitar');
            }
        });

        lockSenha.addEventListener('click', function() {
            if (lockSenha.hasAttribute('readonly')) {
                lockSenha.removeAttribute('readonly');
                lockSenha.placeholder = 'Digite sua senha';
            }
        });

        lockSenha.addEventListener('input', function() {
            senhaDigitadaPeloUsuario = true;
        });

        lockSenha.addEventListener('keydown', function(e) {
            if (e.key.length === 1 || e.key === 'Backspace' || e.key === 'Delete') {
                senhaDigitadaPeloUsuario = true;
            }
        });

        // ============================================
        // REGISTRAR ATIVIDADE
        // ============================================
        function registrarAtividade(e) {
            if (bloqueado) return;
            if (e && e.target && lockScreen.contains(e.target)) return;
            ultimaAtividade = Date.now();
            resetarTimers();
        }

        function limparTodosTimers() {
            clearTimeout(timeoutId);
            clearTimeout(warningId);
            clearInterval(countdownId);
            timeoutId = null;
            warningId = null;
            countdownId = null;
        }

        function resetarTimers() {
            limparTodosTimers();
            warningToast.classList.remove('show');

            warningId = setTimeout(() => {
                warningToast.classList.add('show');
                iniciarContagemRegressiva();
            }, TIMEOUT_MS - WARNING_MS);

            timeoutId = setTimeout(() => {
                bloquearTela();
            }, TIMEOUT_MS);
        }

        function iniciarContagemRegressiva() {
            segundosRestantes = Math.floor(WARNING_MS / 1000);
            atualizarContagem();

            countdownId = setInterval(() => {
                segundosRestantes--;
                if (segundosRestantes > 0) {
                    atualizarContagem();
                } else {
                    clearInterval(countdownId);
                }
            }, 1000);
        }

        function atualizarContagem() {
            const minutos = Math.floor(segundosRestantes / 60);
            const segundos = segundosRestantes % 60;
            const tempoFormatado = `${minutos}:${segundos.toString().padStart(2, '0')}`;
            warningText.innerHTML = `Sessao expira em <strong>${tempoFormatado}</strong>`;
        }

        // ============================================
        // BLOQUEAR TELA
        // ============================================
        function bloquearTela() {
            if (bloqueado) return;

            bloqueado = true;
            limparTodosTimers();

            // Persiste o estado de bloqueio no localStorage
            try {
                localStorage.setItem(LOCK_KEY, 'true');
                localStorage.setItem(LOCK_AT_KEY, Date.now().toString());
                // [v2.1.0] Sinaliza para outras abas
                localStorage.setItem(LOCK_SIGNAL_KEY, Date.now().toString());
                // [v2.1.1] Marca flag de reload como 'true' (bloqueado de verdade)
                sessionStorage.setItem(RELOADING_KEY, 'true');
                console.log('🛡️ [v2.1.1] Estado de bloqueio persistido + flag = "true"');
            } catch (e) {
                console.warn('⚠️ Não foi possível persistir lock:', e);
            }

            // Preenche dados do usuário
            try {
                const usuarioStr = localStorage.getItem('usuario');
                if (usuarioStr) {
                    const usuario = JSON.parse(usuarioStr);
                    const inicial = (usuario.nome_completo || 'U')[0].toUpperCase();
                    lockUserAvatar.textContent = inicial;
                    lockUserName.textContent = usuario.nome_completo || 'Usuário';
                    lockUserEmail.textContent = usuario.email || usuario.matricula || '';
                }
            } catch (e) {
                console.warn('Erro ao carregar dados do usuário:', e);
            }

            // Preenche o relógio com a hora do bloqueio
            try {
                const agora = new Date();
                lockTime.textContent = agora.toLocaleTimeString('pt-BR', {
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit'
                });
                console.log('🕐 Relógio do bloqueio:', lockTime.textContent);
            } catch (e) {
                console.warn('⚠️ Erro ao preencher relógio:', e);
            }

            lockError.classList.remove('show');
            lockError.textContent = '';

            resetarFlagDigitacao();

            lockScreen.classList.add('show');
            warningToast.classList.remove('show');

            ativarGuarda();

            console.log('🔒 Tela bloqueada por inatividade');
        }

        // ============================================
        // [v2.1.1] DESBLOQUEAR — valida senha + limpa resíduos
        // ------------------------------------------------------------
        // FIX CIRÚRGICO: marca flag como 'unlocked' (não remove).
        // Isso sinaliza pro beforeunload que o usuário desbloqueou
        // de propósito, e pode limpar no próximo reload.
        // ============================================
        async function desbloquear() {
            const senha = (lockSenha.value || '').trim();

            lockError.classList.remove('show');
            lockError.textContent = '';

            if (lockSenha.hasAttribute('readonly')) {
                console.warn('🛡️ [v2.1.1] Tentativa de desbloquear sem clicar no campo');
                lockError.textContent = 'Clique no campo de senha e digite sua senha.';
                lockError.classList.add('show');
                return;
            }

            if (!senhaDigitadaPeloUsuario) {
                console.warn('🛡️ [v2.1.1] Tentativa de desbloquear sem digitar (autofill?)');
                lockError.textContent = 'Digite sua senha manualmente.';
                lockError.classList.add('show');
                lockSenha.value = '';
                lockSenha.focus();
                return;
            }

            if (!senha) {
                console.warn('🛡️ Tentativa de desbloquear com senha vazia');
                lockError.textContent = 'Digite sua senha.';
                lockError.classList.add('show');
                lockSenha.focus();
                return;
            }

            if (!window.supabaseClient || !window.supabaseClient.auth) {
                lockError.textContent = 'Sistema nao conectado. Recarregue a pagina.';
                lockError.classList.add('show');
                return;
            }

            lockBtn.disabled = true;
            lockBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> VERIFICANDO...';

            try {
                let emailUsuario = null;
                try {
                    const usuarioStr = localStorage.getItem('usuario');
                    if (usuarioStr) {
                        const usuario = JSON.parse(usuarioStr);
                        emailUsuario = usuario.email;
                    }
                } catch (e) {
                    console.warn('Erro ao ler usuário:', e);
                }

                if (!emailUsuario && window.supabaseClient.auth) {
                    const { data: { user } } = await window.supabaseClient.auth.getUser();
                    if (user) emailUsuario = user.email;
                }

                if (!emailUsuario) {
                    lockError.textContent = 'Usuário não identificado. Faça login novamente.';
                    lockError.classList.add('show');
                    return;
                }

                const { error: authError } = await window.supabaseClient.auth.signInWithPassword({
                    email: emailUsuario,
                    password: senha
                });

                if (authError) {
                    console.warn('🛡️ Senha incorreta');
                    lockError.textContent = 'Senha incorreta. Tente novamente.';
                    lockError.classList.add('show');
                    lockSenha.value = '';
                    senhaDigitadaPeloUsuario = false;
                    lockSenha.focus();
                    return;
                }

                console.log('🔓 Senha correta, desbloqueando...');
                bloqueado = false;
                desativarGuarda();
                lockScreen.classList.remove('show');
                resetarFlagDigitacao();

                try {
                    // [v2.1.1] Limpa lock, marca flag como 'unlocked'
                    localStorage.removeItem(LOCK_KEY);
                    localStorage.removeItem(LOCK_AT_KEY);
                    localStorage.setItem(UNLOCK_SIGNAL_KEY, Date.now().toString());
                    sessionStorage.setItem(RELOADING_KEY, 'unlocked');  // ← FIX CIRÚRGICO
                    console.log('🛡️ [v2.1.1] Resíduos limpos, flag = "unlocked"');
                } catch (e) {
                    console.warn('⚠️ Erro ao limpar lock:', e);
                }

                resetarTimers();

                console.log('✅ Tela desbloqueada');

            } catch (error) {
                console.error('❌ Erro no desbloqueio:', error);
                lockError.textContent = 'Erro: ' + error.message;
                lockError.classList.add('show');
            } finally {
                lockBtn.disabled = false;
                lockBtn.innerHTML = '<i class="fas fa-unlock"></i> DESBLOQUEAR';
            }
        }

        // ============================================
        // [v2.1.0] Rebind de handlers após recriar overlay
        // ============================================
        rebindHandlersAposRecriar = function() {
            const novoLockScreen = document.getElementById('lockScreen');
            const novoLockBtn = document.getElementById('lockBtn');
            const novoLockLogout = document.getElementById('lockLogout');
            const novoLockSenha = document.getElementById('lockSenha');

            if (novoLockBtn) {
                novoLockBtn.addEventListener('click', desbloquear);
            }
            if (novoLockSenha) {
                novoLockSenha.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter') {
                        e.preventDefault();
                        desbloquear();
                    }
                });
                novoLockSenha.addEventListener('focus', function() {
                    if (novoLockSenha.hasAttribute('readonly')) {
                        novoLockSenha.removeAttribute('readonly');
                        novoLockSenha.placeholder = 'Digite sua senha';
                    }
                });
                novoLockSenha.addEventListener('input', function() {
                    senhaDigitadaPeloUsuario = true;
                });
            }
            if (novoLockLogout) {
                novoLockLogout.addEventListener('click', function() {
                    if (!confirm('Deseja realmente sair do sistema?')) return;
                    try {
                        localStorage.clear();
                        sessionStorage.clear();
                    } catch (e) {}
                    window.location.href = '02-login.html';
                });
            }

            if (novoLockSenha) setTimeout(() => novoLockSenha.focus(), 100);
        };

        // ============================================
        // EVENT LISTENERS
        // ============================================
        ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart', 'click'].forEach(evento => {
            document.addEventListener(evento, registrarAtividade, { passive: true });
        });

        document.addEventListener('visibilitychange', function() {
            if (!document.hidden && !bloqueado) {
                registrarAtividade();
            }
        });

        lockScreen.addEventListener('click', function(e) {
            if (!e.target.closest('#lockBtn') &&
                !e.target.closest('#lockSenha') &&
                !e.target.closest('#lockLogout')) {
                e.stopPropagation();
                e.preventDefault();
                console.log('🛡️ Clique fora do botão bloqueado');
            }
        }, true);

        lockBtn.addEventListener('click', desbloquear);

        lockSenha.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                desbloquear();
            }
        });

        lockLogout.addEventListener('click', async function() {
            if (!confirm('Deseja realmente sair do sistema?')) return;

            try {
                if (typeof AIDEPOM !== 'undefined' && typeof AIDEPOM.logout === 'function') {
                    await AIDEPOM.logout();
                    return;
                }
            } catch (e) {
                console.warn('⚠️ AIDEPOM.logout() falhou:', e);
            }

            try {
                if (window.supabaseClient?.auth) {
                    await window.supabaseClient.auth.signOut();
                }
            } catch(e) { /* ignore */ }

            try {
                localStorage.removeItem('usuario');
                localStorage.removeItem('authData');
                localStorage.removeItem('usuarioId');
                localStorage.removeItem('logado');
                localStorage.removeItem(LOCK_KEY);
                localStorage.removeItem(LOCK_AT_KEY);
                sessionStorage.removeItem(RELOADING_KEY);
            } catch (e) { /* ignore */ }

            window.location.href = '02-login.html';
        });

        // ============================================
        // SINCRONIZAÇÃO ENTRE ABAS
        // ============================================
        window.addEventListener('storage', function(e) {
            if (e.key === LOCK_SIGNAL_KEY && e.newValue && !bloqueado) {
                console.log('🔒 [v2.1.1] Outra aba bloqueou. Sincronizando...');
                bloquearTela();
            }
            if (e.key === UNLOCK_SIGNAL_KEY && e.newValue && bloqueado) {
                console.log('🔓 [v2.1.1] Outra aba desbloqueou. Sincronizando...');
                bloqueado = false;
                desativarGuarda();
                lockScreen.classList.remove('show');
                resetarFlagDigitacao();
                resetarTimers();
            }
        });

        // ============================================
        // Registra proteções adicionais
        // ============================================
        bloquearTeclasQuandoBloqueado();
        registrarBeforeUnload();
        registrarDomObserver();

        // ============================================
        // Inicialização: verifica lock pendente
        // ============================================
        const lockPendente = verificarLockPendente();

        if (lockPendente) {
            console.log('🛡️ [v2.1.1] Re-aplicando bloqueio após reload...');
            bloquearTela();
        } else {
            resetarTimers();
        }

        window.__AIDEPOM_INACTIVITY_LOCK_INIT__ = true;

        console.log('✅ Temporizador de inatividade ativo (5 minutos) [v2.1.1]');
    }

    function bootstrap() {
        aguardarSupabaseClient(function() {
            init();
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bootstrap);
    } else {
        bootstrap();
    }
})();
