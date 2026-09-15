 /* ============================================
   AI-DEPOM - TEMPORIZADOR DE INATIVIDADE
   ============================================
   Arquivo: assets/js/inactivity-lock.js
   Versao: 1.1.1
   Data: 15/09/2026 - 15:45
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

   ALTERAÇÕES v1.1.1 (15/09/2026 15:45):
   - 🐛 Só inicializa se usuário estiver logado (NÃO bloqueia 02-login.html)
   - 🐛 Logout usa AIDEPOM.logout() (limpeza total)
   - 🐛 blocarTela() limpa TODOS os timers (evita re-disparo)
   - 🐛 Guarda contra duplicação de listeners (evita 2x)
   - 🐛 Aguarda window.supabaseClient estar pronto
   - 🐛 visibilitychange registra atividade ao voltar pra aba
   - 📜 Cabeçalho Regra de Ouro
   - ✅ Mantidas: 5min timeout, aviso 1min, senha, usuário logado, logout
   ============================================ */

(function() {
    'use strict';

    // ============================================
    // [NOVO v1.1.1] GUARDA — evita dupla inicialização
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
    const CHECK_INTERVAL_MS = 1000;        // Verifica a cada 1 segundo

    let timeoutId = null;
    let warningId = null;
    let countdownId = null;
    let ultimaAtividade = Date.now();
    let bloqueado = false;
    let segundosRestantes = 0;

    // ============================================
    // CRIAR ELEMENTOS DINAMICAMENTE
    // ============================================
    function criarElementos() {
        // [v1.1.1] Evita duplicar se já existe
        if (document.getElementById('inactivity-lock-container')) {
            return;
        }

        // 1. CSS
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

        // 2. HTML
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
                            <input type="password" id="lockSenha" placeholder="Digite sua senha" autocomplete="current-password">
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
    // [NOVO v1.1.1] Verifica se está logado
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
    // [NOVO v1.1.1] Aguarda window.supabaseClient
    // ============================================
    function aguardarSupabaseClient(callback, tentativas = 0) {
        if (window.supabaseClient && window.supabaseClient.auth) {
            callback();
            return;
        }
        if (tentativas > 50) { // ~5s
            console.warn('⚠️ inactivity-lock: supabaseClient não disponível após 5s');
            callback();
            return;
        }
        setTimeout(() => aguardarSupabaseClient(callback, tentativas + 1), 100);
    }

    // ============================================
    // INICIALIZACAO
    // ============================================
    function init() {
        // [NOVO v1.1.1] Não roda em páginas sem login (ex: 02-login.html)
        if (!estaLogado()) {
            console.log('ℹ️ inactivity-lock: usuário não logado, timers não iniciados.');
            return;
        }

        // Criar elementos
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
        // REGISTRAR ATIVIDADE
        // ============================================
        function registrarAtividade() {
            if (bloqueado) return;
            ultimaAtividade = Date.now();
            resetarTimers();
        }

        // [NOVO v1.1.1] Limpa TODOS os timers (usar antes de bloquear/resetar)
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
            if (bloqueado) return; // [NOVO v1.1.1] guarda contra dupla execução

            bloqueado = true;

            // [NOVO v1.1.1] Limpa TODOS os timers
            limparTodosTimers();

            lockScreen.classList.add('show');
            warningToast.classList.remove('show');

            const agora = new Date();
            lockTime.textContent = agora.toLocaleTimeString('pt-BR');

            // Mostra dados do usuário logado
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

            lockError.classList.remove('show');
            lockSenha.value = '';

            setTimeout(() => lockSenha.focus(), 300);

            console.log('🔒 Tela bloqueada por inatividade');
        }

        // ============================================
        // DESBLOQUEAR — só com senha
        // ============================================
        async function desbloquear() {
            const senha = lockSenha.value.trim();

            lockError.classList.remove('show');

            if (!senha) {
                lockError.textContent = 'Digite sua senha.';
                lockError.classList.add('show');
                return;
            }

            if (!window.supabaseClient) {
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
                    console.warn('Erro ao ler usuário do localStorage:', e);
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
                    lockError.textContent = 'Senha incorreta. Tente novamente.';
                    lockError.classList.add('show');
                    return;
                }

                bloqueado = false;
                lockScreen.classList.remove('show');
                resetarTimers();

                console.log('🔓 Tela desbloqueada');

            } catch (error) {
                lockError.textContent = 'Erro: ' + error.message;
                lockError.classList.add('show');
            } finally {
                lockBtn.disabled = false;
                lockBtn.innerHTML = '<i class="fas fa-unlock"></i> DESBLOQUEAR';
            }
        }

        // ============================================
        // EVENT LISTENERS
        // ============================================
        ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart', 'click'].forEach(evento => {
            document.addEventListener(evento, registrarAtividade, { passive: true });
        });

        // [NOVO v1.1.1] Detecta retorno à aba
        document.addEventListener('visibilitychange', function() {
            if (!document.hidden) {
                registrarAtividade();
            }
        });

        lockBtn.addEventListener('click', desbloquear);
        lockSenha.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') desbloquear();
        });

        // [ALTERADO v1.1.1] Logout robusto
        lockLogout.addEventListener('click', async function() {
            if (!confirm('Deseja realmente sair do sistema?')) return;

            try {
                // [v1.1.1] Usa AIDEPOM.logout() se disponível (limpa TUDO)
                if (typeof AIDEPOM !== 'undefined' && typeof AIDEPOM.logout === 'function') {
                    await AIDEPOM.logout();
                    return;
                }
            } catch (e) {
                console.warn('⚠️ AIDEPOM.logout() falhou, usando fallback:', e);
            }

            // Fallback
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
            } catch (e) { /* ignore */ }

            window.location.href = '02-login.html';
        });

        // Iniciar timers
        resetarTimers();

        // Marca como inicializado
        window.__AIDEPOM_INACTIVITY_LOCK_INIT__ = true;

        console.log('✅ Temporizador de inatividade ativo (5 minutos)');
    }

    // ============================================
    // AGUARDAR DOM + SUPABASE
    // ============================================
    function bootstrap() {
        // [NOVO v1.1.1] Aguarda window.supabaseClient antes de inicializar
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
