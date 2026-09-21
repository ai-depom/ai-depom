 /* ============================================
   AI-DEPOM - TEMPORIZADOR DE INATIVIDADE
   ============================================
   Arquivo: assets/js/inactivity-lock.js
   Versao: 2.0.0
   Data: 21/09/2026 - 13:00
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

   ALTERAÇÕES v2.0.0 (21/09/2026 13:00):
   - 🚨 CORRIGIDO (Furo 1): F5 / Ctrl+R / Ctrl+Shift+R / Ctrl+F5
     agora SÃO BLOQUEADOS quando a tela está bloqueada
   - 🚨 CORRIGIDO (Furo 2): beforeunload avisa ao tentar recarregar
   - 🚨 CORRIGIDO (Furo 3): MutationObserver detecta remoção COMPLETA
     do nó DOM (não só da classe .show) e recria o overlay
   - ✨ NOVO: bloqueio de F12 / Ctrl+Shift+I / Ctrl+Shift+J / Ctrl+U
     quando a tela está bloqueada (anti-DevTools)
   - ✨ NOVO: sincronização entre abas via storage event
     - Se uma aba bloqueia, TODAS bloqueiam
     - Se uma aba desbloqueia, TODAS desbloqueiam
   - ✨ NOVO: guarda ativa agora usa `getElementById` a cada tick
     (imune a nó detached)
   - ✅ PRESERVADO: todas as proteções da v1.2.3
     (persistência, anti-autofill, classList hook, relógio HH:MM:SS)

   ALTERAÇÕES v1.2.3 (16/09/2026 14:30):
   - 🐛 CORRIGIDO: relógio do lock não exibia a hora do bloqueio
   - ✨ NOVO: exibe hora/minuto/segundo (HH:MM:SS) no momento do bloqueio
   - ✨ NOVO: log no console confirmando o relógio preenchido
   - ✅ Mantidas: todas as proteções da v1.2.2

   ALTERAÇÕES v1.2.2 (16/09/2026 12:30):
   - 🚨 CORRIGIDO: F5 burlava o lock screen (bug crítico)
   - 🛡️ NOVO: estado de bloqueio persistido em localStorage
   - 🛡️ NOVO: re-aplica lock automaticamente ao recarregar
   - 🛡️ NOVO: força logout se lock ficou ativo >24h

   ALTERAÇÕES v1.2.1 (16/09/2026 09:30):
   - 🐛 CORRIGIDO: autofill do navegador preenchia a senha
   - 🐛 CORRIGIDO: campo exige digitação manual (readonly + flag)
   - 🛡️ NOVO: rastreia se o usuário DIGITOU (evento input)

   ALTERAÇÕES v1.2.0 (16/09/2026 09:00):
   - 🐛 CORRIGIDO: desbloquear() valida senha ANTES de remover lock
   - 🛡️ NOVO: guarda ativa re-aplica o lock se removido
   - 🛡️ NOVO: intercepta classList.remove/toggle do lockScreen
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

    // Chaves do localStorage
    const LOCK_KEY = 'aidepom_locked';
    const LOCK_AT_KEY = 'aidepom_locked_at';
    const LOCK_SIGNAL_KEY = 'aidepom_lock_signal';
    const UNLOCK_SIGNAL_KEY = 'aidepom_unlock_signal';

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
    // Verifica se havia lock pendente (F5 bypass)
    // ============================================
    function verificarLockPendente() {
        try {
            const locked = localStorage.getItem(LOCK_KEY);
            if (locked !== 'true') return false;

            const lockedAt = parseInt(localStorage.getItem(LOCK_AT_KEY) || '0');
            const agora = Date.now();
            const tempoDecorrido = agora - lockedAt;

            if (tempoDecorrido > LOCK_MAX_AGE_MS || lockedAt === 0) {
                console.warn('🛡️ [v2.0.0] Lock expirado (>24h). Forçando logout.');
                try {
                    localStorage.removeItem(LOCK_KEY);
                    localStorage.removeItem(LOCK_AT_KEY);
                    localStorage.removeItem('usuario');
                    localStorage.removeItem('authData');
                    localStorage.removeItem('usuarioId');
                    localStorage.removeItem('logado');
                } catch (e) { /* ignore */ }
                window.location.href = '02-login.html';
                return false;
            }

            console.log('🔒 [v2.0.0] Lock pendente detectado. Re-aplicando...');
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
    // [v2.0.0] PROTEÇÃO CONTRA TECLAS DE RELOAD
    // ============================================
    function bloquearTeclasQuandoBloqueado() {
        document.addEventListener('keydown', function(e) {
            if (!bloqueado) return;

            // F5
            if (e.key === 'F5' || e.keyCode === 116) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.0.0] F5 bloqueado (tela bloqueada)');
                return false;
            }

            // Ctrl+F5 (hard reload)
            if (e.ctrlKey && e.key === 'F5') {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }

            // Ctrl+R / Cmd+R
            if ((e.ctrlKey || e.metaKey) && !e.shiftKey && (e.key === 'r' || e.key === 'R')) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.0.0] Ctrl+R bloqueado (tela bloqueada)');
                return false;
            }

            // Ctrl+Shift+R / Cmd+Shift+R (hard reload)
            if ((e.ctrlKey || e.metaKey) && e.shiftKey && (e.key === 'r' || e.key === 'R')) {
                e.preventDefault();
                e.stopPropagation();
                console.warn('🛡️ [v2.0.0] Ctrl+Shift+R bloqueado (tela bloqueada)');
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
                console.warn('🛡️ [v2.0.0] DevTools bloqueado (tela bloqueada)');
                return false;
            }
        }, true); // ← fase de CAPTURA
    }

    // ============================================
    // [v2.0.0] AVISO AO RECARREGAR BLOQUEADO
    // ============================================
    function registrarBeforeUnload() {
        window.addEventListener('beforeunload', function(e) {
            if (bloqueado) {
                e.preventDefault();
                e.returnValue = 'A sessão está bloqueada. Recarregar NÃO irá desbloquear.';
                return e.returnValue;
            }
        });
    }

    // ============================================
    // [v2.0.0] MUTATION OBSERVER (detecta remoção do nó DOM)
    // ============================================
    function registrarDomObserver() {
        if (domObserver) return;

        domObserver = new MutationObserver(function() {
            if (!bloqueado) return;
            const overlay = document.getElementById('lockScreen');
            if (!overlay) {
                console.warn('🛡️ [v2.0.0] Overlay REMOVIDO do DOM. Recriando...');
                criarElementos();
                const novo = document.getElementById('lockScreen');
                if (novo) novo.classList.add('show');
                // Re-bind dos handlers
                rebindHandlersAposRecriar();
            } else if (!overlay.classList.contains('show')) {
                console.warn('🛡️ [v2.0.0] Classe .show removida. Re-aplicando...');
                overlay.classList.add('show');
            }
        });

        domObserver.observe(document.body, { childList: true, subtree: true });
    }

    // Placeholder — será redefinido dentro do init()
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

                // Re-query SEMPRE (imune a nó detached)
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
                console.log('🔓 [v2.0.0] readonly removido, pode digitar');
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
                console.log('🛡️ [v2.0.0] Estado de bloqueio persistido');
                // [v2.0.0] Sinaliza para outras abas
                localStorage.setItem(LOCK_SIGNAL_KEY, Date.now().toString());
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
        // DESBLOQUEAR — valida senha + digitação real
        // ============================================
        async function desbloquear() {
            const senha = (lockSenha.value || '').trim();

            lockError.classList.remove('show');
            lockError.textContent = '';

            if (lockSenha.hasAttribute('readonly')) {
                console.warn('🛡️ [v2.0.0] Tentativa de desbloquear sem clicar no campo');
                lockError.textContent = 'Clique no campo de senha e digite sua senha.';
                lockError.classList.add('show');
                return;
            }

            if (!senhaDigitadaPeloUsuario) {
                console.warn('🛡️ [v2.0.0] Tentativa de desbloquear sem digitar (autofill?)');
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
                    localStorage.removeItem(LOCK_KEY);
                    localStorage.removeItem(LOCK_AT_KEY);
                    // [v2.0.0] Sinaliza para outras abas desbloquearem
                    localStorage.setItem(UNLOCK_SIGNAL_KEY, Date.now().toString());
                    console.log('🛡️ [v2.0.0] Estado de bloqueio limpo');
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
        // [v2.0.0] Rebind de handlers após recriar overlay
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

            // Foca no campo
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
            } catch (e) { /* ignore */ }

            window.location.href = '02-login.html';
        });

        // ============================================
        // [v2.0.0] SINCRONIZAÇÃO ENTRE ABAS
        // ============================================
        window.addEventListener('storage', function(e) {
            if (e.key === LOCK_SIGNAL_KEY && e.newValue && !bloqueado) {
                console.log('🔒 [v2.0.0] Outra aba bloqueou. Sincronizando...');
                bloquearTela();
            }
            if (e.key === UNLOCK_SIGNAL_KEY && e.newValue && bloqueado) {
                console.log('🔓 [v2.0.0] Outra aba desbloqueou. Sincronizando...');
                bloqueado = false;
                desativarGuarda();
                lockScreen.classList.remove('show');
                resetarFlagDigitacao();
                resetarTimers();
            }
        });

        // ============================================
        // [v2.0.0] Registra proteções adicionais
        // ============================================
        bloquearTeclasQuandoBloqueado();
        registrarBeforeUnload();
        registrarDomObserver();

        // ============================================
        // Inicialização: verifica lock pendente (F5)
        // ============================================
        const lockPendente = verificarLockPendente();

        if (lockPendente) {
            console.log('🛡️ [v2.0.0] Re-aplicando bloqueio após reload...');
            bloquearTela();
        } else {
            resetarTimers();
        }

        window.__AIDEPOM_INACTIVITY_LOCK_INIT__ = true;

        console.log('✅ Temporizador de inatividade ativo (5 minutos) [v2.0.0]');
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
