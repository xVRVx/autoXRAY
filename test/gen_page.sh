#!/bin/bash

TARGET_DIR=$1

if [ -z "$TARGET_DIR" ]; then
    echo "❌ Ошибка: домен не задан."
    exit 1
fi

echo "🎨 Запуск генератора дизайна с анимациями..."

# --- 1. МАССИВЫ ДАННЫХ ---
TITLES=("FileShare" "CloudBox" "DataVault" "SecureShare" "EasyFiles" "QuickAccess" "VaultZone" "SkyDrive" "SafeData" "FlexShare" "DropZone" "SecureStorage" "FastFiles" "SharePoint" "MegaVault" "Boxify" "DataBank" "DriveSecure" "FileStream" "AccessHub")
HEADERS=("Welcome to FileShare" "Login to Your CloudBox" "Enter Your Secure Vault" "Access Your DataVault" "Sign in to EasyFiles" "Connect to QuickAccess" "Welcome to VaultZone" "Login to SkyDrive" "Enter Your SafeData" "Sign in to FlexShare" "Access Your DropZone" "Welcome to SecureStorage" "Login to FastFiles" "Enter Your SharePoint" "Welcome to MegaVault" "Sign in to Boxify" "Access Your DataBank" "Welcome to DriveSecure" "Login to FileStream" "Connect to AccessHub")
BUTTON_TEXTS=("Sign In" "Log In" "Login" "Access Account" "Enter Account" "Sign In to Continue" "Sign In to Dashboard" "Log In to Your Account" "Continue to Account" "Access Your Dashboard" "Let’s Go" "Welcome Back!" "Get Started" "Join Us Again" "Back Again? Sign In" "Secure Sign In" "Protected Login" "Sign In Securely" "Enter" "Go")

# Массив с фейковыми ошибками
ERROR_MESSAGES=(
    "Invalid username or password."
    "Connection timeout. Please try again."
    "Access denied by security policy."
    "Account is temporarily locked."
    "Network error: Handshake failed."
    "Invalid authentication token."
    "Session expired. Please refresh."
    "Error 502: Bad Gateway."
    "LDAP Server not responding."
)

# --- 2. МАССИВЫ СТИЛЕЙ ---
FONTS_DATA=(
    "Inter|Inter:wght@400;600;700"
    "Poppins|Poppins:wght@400;600;700"
    "Roboto|Roboto:wght@400;500;700"
    "Lato|Lato:wght@400;700"
    "Montserrat|Montserrat:wght@400;600;700"
    "Open Sans|Open+Sans:wght@400;600;700"
    "Raleway|Raleway:wght@400;600;700"
)

ROUNDNESS_OPTS=("rounded-none" "rounded-lg" "rounded-xl" "rounded-2xl" "rounded-3xl" "rounded-[2rem]")

BUTTON_COLORS=("bg-blue-600 hover:bg-blue-700" "bg-green-600 hover:bg-green-700" "bg-red-600 hover:bg-red-700" "bg-purple-600 hover:bg-purple-700" "bg-indigo-600 hover:bg-indigo-700" "bg-teal-600 hover:bg-teal-700" "bg-orange-600 hover:bg-orange-700" "bg-pink-600 hover:bg-pink-700" "bg-cyan-600 hover:bg-cyan-700" "bg-emerald-600 hover:bg-emerald-700" "bg-rose-600 hover:bg-rose-700" "bg-slate-800 hover:bg-slate-900" "bg-violet-600 hover:bg-violet-700" "bg-gradient-to-r from-blue-500 to-cyan-500 hover:opacity-90" "bg-gradient-to-r from-purple-500 to-pink-500 hover:opacity-90" "bg-gradient-to-r from-orange-400 to-red-500 hover:opacity-90")

BG_GRADIENTS=(
    "bg-gradient-to-br from-blue-100 via-blue-300 to-blue-500"
    "bg-gradient-to-tr from-purple-200 via-purple-400 to-purple-800"
    "bg-gradient-to-bl from-teal-200 to-lime-200"
    "bg-gradient-to-r from-rose-100 to-teal-100"
    "bg-gradient-to-tl from-gray-700 via-gray-900 to-black"
    "bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900"
    "bg-gradient-to-tr from-indigo-500 via-purple-500 to-pink-500"
    "bg-gradient-to-b from-gray-900 to-gray-600 bg-gradient-to-r"
    "bg-gradient-to-bl from-indigo-900 via-slate-800 to-indigo-900"
    "bg-[url('https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=2000&auto=format&fit=crop')] bg-cover bg-center"
    "bg-[url('https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=2000&auto=format&fit=crop')] bg-cover bg-center"
    "bg-[url('https://images.unsplash.com/photo-1519681393798-3828fb4090bb?q=80&w=2000&auto=format&fit=crop')] bg-cover bg-center"
)

# --- 3. ВЫБОР СЛУЧАЙНЫХ ЗНАЧЕНИЙ ---
TITLE=${TITLES[$RANDOM % ${#TITLES[@]}]}
HEADER=${HEADERS[$RANDOM % ${#HEADERS[@]}]}
BUTTON_TEXT=${BUTTON_TEXTS[$RANDOM % ${#BUTTON_TEXTS[@]}]}
ERROR_TEXT=${ERROR_MESSAGES[$RANDOM % ${#ERROR_MESSAGES[@]}]}
BUTTON_COLOR=${BUTTON_COLORS[$RANDOM % ${#BUTTON_COLORS[@]}]}
BG_STYLE=${BG_GRADIENTS[$RANDOM % ${#BG_GRADIENTS[@]}]}
ROUNDING=${ROUNDNESS_OPTS[$RANDOM % ${#ROUNDNESS_OPTS[@]}]}

FONT_PAIR=${FONTS_DATA[$RANDOM % ${#FONTS_DATA[@]}]}
FONT_NAME=$(echo $FONT_PAIR | cut -d'|' -f1)
FONT_URL_PART=$(echo $FONT_PAIR | cut -d'|' -f2)

THEME_MODE=$((RANDOM % 2)) 

if [ $THEME_MODE -eq 1 ]; then
    # Dark Mode
    TEXT_MAIN="text-white"
    TEXT_MUTED="text-gray-300"
    TEXT_INPUT="text-white"
    CARD_BG="bg-gray-900/60 backdrop-blur-xl border border-gray-700 shadow-2xl"
    INPUT_BG="bg-gray-800/50 border-gray-600 focus:border-blue-500 focus:ring-blue-500/20 placeholder-gray-400"
    OVERLAY_CLASS="absolute inset-0 bg-black/40 z-0"
    ERROR_BOX="bg-red-900/50 border-red-700 text-red-200"
else
    # Light Mode
    TEXT_MAIN="text-gray-800"
    TEXT_MUTED="text-gray-500"
    TEXT_INPUT="text-gray-900"
    CARD_BG="bg-white/80 backdrop-blur-lg border border-white/50 shadow-xl"
    INPUT_BG="bg-gray-50 border-gray-200 focus:border-blue-500 focus:ring-blue-200"
    OVERLAY_CLASS="hidden"
    ERROR_BOX="bg-red-50 border-red-200 text-red-600"
fi

echo "✅ Создаю index.html в папке: $TARGET_DIR (Тема: $FONT_NAME)"

# --- 4. ГЕНЕРАЦИЯ HTML ---
# Обратите внимание: я экранирую \$ в JS коде, чтобы bash не пытался их интерпретировать
cat > "$TARGET_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$TITLE</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=${FONT_URL_PART}&display=swap" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.7.1.js" integrity="sha256-eKhayi8LEQwp4NKxN+CfCh+3qOVUtJn3QNZ0TciWLP4=" crossorigin="anonymous"></script>
    <style>
        body { font-family: '$FONT_NAME', sans-serif; }
        
        /* Анимация тряски при ошибке */
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            10%, 30%, 50%, 70%, 90% { transform: translateX(-5px); }
            20%, 40%, 60%, 80% { transform: translateX(5px); }
        }
        .shake-animation {
            animation: shake 0.5s cubic-bezier(.36,.07,.19,.97) both;
        }
        
        .fade-in {
            animation: fadeIn 0.3s ease-in-out;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }
    </style>
</head>
<body class="relative flex items-center justify-center min-h-screen overflow-hidden $BG_STYLE transition-all duration-500">
    <div class="$OVERLAY_CLASS pointer-events-none"></div>
    
    <!-- Карточка входа -->
    <div id="login-card" class="relative z-10 w-full max-w-md p-8 sm:p-10 space-y-8 $CARD_BG $ROUNDING transform transition-all hover:scale-[1.01]">
        
        <div class="text-center space-y-2">
            <h2 class="text-3xl font-bold tracking-tight $TEXT_MAIN">$HEADER</h2>
            <p class="text-sm $TEXT_MUTED">Please enter your credentials to continue</p>
        </div>

        <!-- Блок с ошибкой (скрыт по умолчанию) -->
        <div id="error-msg" class="hidden flex items-center p-4 mb-4 text-sm border rounded-lg $ERROR_BOX fade-in" role="alert">
            <svg class="flex-shrink-0 inline w-4 h-4 me-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z"/>
            </svg>
            <span class="sr-only">Info</span>
            <div>
                <span class="font-medium">Error!</span> $ERROR_TEXT
            </div>
        </div>

        <form id="login-form" action="#" method="POST" class="space-y-6">
            <div class="space-y-1">
                <label for="login" class="block text-sm font-medium $TEXT_MUTED ml-1">Username</label>
                <input type="text" id="login" name="login" required
                    class="w-full px-4 py-3 text-base transition-colors duration-200 rounded-lg outline-none focus:ring-4 $INPUT_BG $TEXT_INPUT" 
                    placeholder="user@example.com" />
            </div>
            <div class="space-y-1">
                <label for="password" class="block text-sm font-medium $TEXT_MUTED ml-1">Password</label>
                <input type="password" id="password" name="password" required
                    class="w-full px-4 py-3 text-base transition-colors duration-200 rounded-lg outline-none focus:ring-4 $INPUT_BG $TEXT_INPUT" 
                    placeholder="••••••••" />
            </div>
            
            <button type="submit" id="submit-btn" 
                class="flex justify-center items-center w-full py-3.5 text-base font-bold text-white shadow-lg transition-all duration-200 $BUTTON_COLOR $ROUNDING">
                <span>$BUTTON_TEXT</span>
            </button>
        </form>
    </div>

    <script>
        \$(document).ready(function() {
            \$('#login-form').on('submit', function(e) {
                e.preventDefault(); // Останавливаем отправку формы
                
                var \$btn = \$(this).find('button');
                var \$span = \$btn.find('span');
                var originalText = \$span.text();
                var \$errorBox = \$('#error-msg');
                var \$card = \$('#login-card');

                // 1. Скрываем старую ошибку
                \$errorBox.addClass('hidden');

                // 2. Включаем состояние загрузки
                \$btn.prop('disabled', true).addClass('opacity-75 cursor-not-allowed');
                \$span.text('Verifying...');
                // Добавляем спиннер
                \$btn.prepend('<svg id="spinner" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>');

                var delay = Math.floor(1000);

                setTimeout(function() {
                    \$btn.prop('disabled', false).removeClass('opacity-75 cursor-not-allowed');
                    \$span.text(originalText);
                    \$btn.find('#spinner').remove();

                    \$errorBox.removeClass('hidden');
                    
                    \$card.addClass('shake-animation');
                    
                    // Очищаем пароль
                    \$('#password').val('');
                    \$('#password').focus();

                    setTimeout(function() {
                        \$card.removeClass('shake-animation');
                    }, 500);

                }, delay);
            });
        });
    </script>
</body>
</html>
EOF