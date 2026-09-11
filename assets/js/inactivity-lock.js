/* ============================================
   AI-DEPOM - TEMPORIZADOR DE INATIVIDADE
   ============================================
   Arquivo: assets/js/inactivity-lock.js
   Versao: 1.0.0
   Data: 11/09/2026
   ============================================
   Bloqueia a tela apos 5 minutos de inatividade
   Desbloqueio com matricula + senha
   ============================================ */

(function() {
    'use strict';

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
                    <div class="lock-timer">
                        <i class="fas fa-clock"></i> Bloqueado em <strong id="lockTime">--:--</strong>
                    </div>

                    <div class="lock-error" id="lockError"></div>

                    <div class="lock-form">
                        <div class="form-group">
                            <label for="lockMatricula">Matricula</label>
                            <input type="text" id="lockMatricula" placeholder="Digite sua matricula" autocomplete="off">
                        </div>
                        <div class="form-group">
                            <label for="lockSenha">Senha</label>
                            <input type="password" id="lockSenha" placeholder="Digite sua senha">
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
    // INICIALIZACAO
    // ============================================
    function init() {
        // Criar elementos
        criarElementos();

        const lockScreen = document.getElementById('lockScreen');
        const warningToast = document.getElementById('lockWarningToast');
        const warningText = document.getElementById('lockWarningText');
        const lockTime = document.getElementById('lockTime');
        const lockError = document.getElementById('lockError');
        const lockBtn = document.getElementById('lockBtn');
        const lockLogout = document.getElementById('lockLogout');
        const lockMatricula = document.getElementById('lockMatricula');
        const lockSenha = document.getElementById('lockSenha');

        // ============================================
        // REGISTRAR ATIVIDADE
        // ============================================
        function registrarAtividade() {
            if (bloqueado) return;
            ultimaAtividade = Date.now();
            resetarTimers();
        }

        function resetarTimers() {
            clearTimeout(timeoutId);
            clearTimeout(warningId);
            clearInterval(countdownId);
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
            bloqueado = true;
            lockScreen.classList.add('show');
            warningToast.classList.remove('show');
            clearInterval(countdownId);

            const agora = new Date();
            lockTime.textContent = agora.toLocaleTimeString('pt-BR');

            lockError.classList.remove('show');
            lockMatricula.value = '';
            lockSenha.value = '';

            setTimeout(() => lockMatricula.focus(), 300);

            console.log('🔒 Tela bloqueada por inatividade');
        }

        // ============================================
        // DESBLOQUEAR
        // ============================================
        async function desbloquear() {
            const matricula = lockMatricula.value.trim();
            const senha = lockSenha.value.trim();

            lockError.classList.remove('show');

            if (!matricula || !senha) {
                lockError.textContent = 'Preencha matricula e senha.';
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
                // 1. Buscar usuario
                const { data: usuario, error: buscaError } = await window.supabaseClient
                    .from('usuarios')
                    .select('id, matricula, nome_completo, email, ativo, deletado')
                    .eq('matricula', matricula)
                    .maybeSingle();

                if (buscaError || !usuario) {
                    lockError.textContent = 'Matricula nao encontrada.';
                    lockError.classList.add('show');
                    return;
                }

                if (usuario.deletado === true || usuario.ativo !== true) {
                    lockError.textContent = 'Usuario inativo ou deletado.';
                    lockError.classList.add('show');
                    return;
                }

                // 2. Autenticar
                const { error: authError } = await window.supabaseClient.auth.signInWithPassword({
                    email: usuario.email,
                    password: senha
                });

                if (authError) {
                    lockError.textContent = 'Senha incorreta.';
                    lockError.classList.add('show');
                    return;
                }

                // 3. Desbloquear
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

        lockBtn.addEventListener('click', desbloquear);
        lockSenha.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') desbloquear();
        });
        lockMatricula.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') lockSenha.focus();
        });

        lockLogout.addEventListener('click', async function() {
            if (confirm('Deseja realmente sair do sistema?')) {
                try {
                    if (window.supabaseClient) {
                        await window.supabaseClient.auth.signOut();
                    }
                } catch(e) {}
                sessionStorage.clear();
                localStorage.removeItem('usuario');
                window.location.href = '02-login.html';
            }
        });

        // Iniciar timers
        resetarTimers();

        console.log('✅ Temporizador de inatividade ativo (5 minutos)');
    }

    // ============================================
    // AGUARDAR DOM
    // ============================================
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
