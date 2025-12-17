#!/bin/bash

# Создание директории
WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"

# Установка прав
#chown -R $USER:$USER "$WEB_PATH"
#chmod -R 755 "$WEB_PATH"


# --- CONTENT ARRAYS ---
TITLES=("FileShare" "CloudBox" "DataVault" "SecureShare" "EasyFiles" "QuickAccess" "VaultZone" "SkyDrive" "SafeData" "FlexShare" "DropZone" "SecureStorage" "FastFiles" "SharePoint" "MegaVault" "Boxify" "DataBank" "DriveSecure" "FileStream" "AccessHub")

HEADERS=("Welcome to FileShare" "Login to Your CloudBox" "Enter Your Secure Vault" "Access Your DataVault" "Sign in to EasyFiles" "Connect to QuickAccess" "Welcome to VaultZone" "Login to SkyDrive" "Enter Your SafeData" "Sign in to FlexShare" "Access Your DropZone" "Welcome to SecureStorage" "Login to FastFiles" "Enter Your SharePoint" "Welcome to MegaVault" "Sign in to Boxify" "Access Your DataBank" "Welcome to DriveSecure" "Login to FileStream" "Connect to AccessHub")

BUTTON_TEXTS=("Sign In" "Log In" "Login" "Access Account" "Enter Account" "Sign In to Continue" "Sign In to Dashboard" "Log In to Your Account" "Continue to Account" "Access Your Dashboard" "Let’s Go" "Welcome Back!" "Get Started" "Join Us Again" "Back Again? Sign In" "Secure Sign In" "Protected Login" "Sign In Securely" "Enter" "Go")

# --- STYLE ARRAYS ---

# Google Fonts (Name|URL_Part)
FONTS_DATA=(
    "Inter|Inter:wght@400;600;700"
    "Poppins|Poppins:wght@400;600;700"
    "Roboto|Roboto:wght@400;500;700"
    "Lato|Lato:wght@400;700"
    "Montserrat|Montserrat:wght@400;600;700"
    "Open Sans|Open+Sans:wght@400;600;700"
    "Raleway|Raleway:wght@400;600;700"
)

# Border Radius Options (Tailwind classes)
ROUNDNESS_OPTS=("rounded-none" "rounded-lg" "rounded-xl" "rounded-2xl" "rounded-3xl" "rounded-[2rem]")

# Button Colors (Tailwind classes with gradients for better look)
BUTTON_COLORS=("bg-blue-600 hover:bg-blue-700" "bg-green-600 hover:bg-green-700" "bg-red-600 hover:bg-red-700" "bg-purple-600 hover:bg-purple-700" "bg-indigo-600 hover:bg-indigo-700" "bg-teal-600 hover:bg-teal-700" "bg-orange-600 hover:bg-orange-700" "bg-pink-600 hover:bg-pink-700" "bg-cyan-600 hover:bg-cyan-700" "bg-emerald-600 hover:bg-emerald-700" "bg-rose-600 hover:bg-rose-700" "bg-slate-800 hover:bg-slate-900" "bg-violet-600 hover:bg-violet-700" "bg-gradient-to-r from-blue-500 to-cyan-500 hover:opacity-90" "bg-gradient-to-r from-purple-500 to-pink-500 hover:opacity-90" "bg-gradient-to-r from-orange-400 to-red-500 hover:opacity-90")

# Background Gradients (Tailwind classes)
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
)

# --- RANDOM SELECTION LOGIC ---

# 1. Content
TITLE=${TITLES[$RANDOM % ${#TITLES[@]}]}
HEADER=${HEADERS[$RANDOM % ${#HEADERS[@]}]}
BUTTON_TEXT=${BUTTON_TEXTS[$RANDOM % ${#BUTTON_TEXTS[@]}]}

# 2. Styling
BUTTON_COLOR=${BUTTON_COLORS[$RANDOM % ${#BUTTON_COLORS[@]}]}
BG_STYLE=${BG_GRADIENTS[$RANDOM % ${#BG_GRADIENTS[@]}]}
ROUNDING=${ROUNDNESS_OPTS[$RANDOM % ${#ROUNDNESS_OPTS[@]}]}

# 3. Fonts
FONT_PAIR=${FONTS_DATA[$RANDOM % ${#FONTS_DATA[@]}]}
FONT_NAME=$(echo $FONT_PAIR | cut -d'|' -f1)
FONT_URL_PART=$(echo $FONT_PAIR | cut -d'|' -f2)


THEME_MODE=1 # 0 = Light, 1 = Dark

TEXT_MAIN="text-white"
TEXT_MUTED="text-gray-300"
TEXT_INPUT="text-white"
CARD_BG="bg-gray-900/60 backdrop-blur-xl border border-gray-700 shadow-2xl"
INPUT_BG="bg-gray-800/50 border-gray-600 focus:border-blue-500 focus:ring-blue-500/20 placeholder-gray-400"

OVERLAY_CLASS="absolute inset-0 bg-black/40 z-0" # Adds a tint over any BG


echo "✅ Creating index.html at $WEB_PATH with theme: $FONT_NAME (Dark Mode: $THEME_MODE)"

# --- GENERATE HTML ---
cat > "$WEB_PATH/index.html" <<EOF
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>$TITLE</title><!-- Tailwind CSS --><script src="https://cdn.tailwindcss.com"></script><!-- Google Font --><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=${FONT_URL_PART}&display=swap" rel="stylesheet"><script src="https://code.jquery.com/jquery-3.7.1.js" integrity="sha256-eKhayi8LEQwp4NKxN+CfCh+3qOVUtJn3QNZ0TciWLP4=" crossorigin="anonymous"></script><style> body { font-family: '$FONT_NAME', sans-serif; } .glass-effect { backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); } </style></head><body class="relative flex items-center justify-center min-h-screen overflow-hidden $BG_STYLE transition-all duration-500"><!-- Dark Mode Overlay (if needed) --><div class="$OVERLAY_CLASS pointer-events-none"></div><!-- Main Card --><div class="relative z-10 w-full max-w-md p-8 sm:p-10 space-y-8 $CARD_BG $ROUNDING transform transition-all hover:scale-[1.01]"><div class="text-center space-y-2"><h2 class="text-3xl font-bold tracking-tight $TEXT_MAIN">$HEADER</h2><p class="text-sm $TEXT_MUTED">Please enter your credentials to continue</p></div><form action="#" method="POST" class="space-y-6"><div class="space-y-1"><label for="login" class="block text-sm font-medium $TEXT_MUTED ml-1">Username</label><input type="text" id="login" name="login" class="w-full px-4 py-3 text-base transition-colors duration-200 rounded-lg outline-none focus:ring-4 $INPUT_BG $TEXT_INPUT" placeholder="user@example.com" /></div><div class="space-y-1"><div class="flex justify-between"><label for="password" class="block text-sm font-medium $TEXT_MUTED ml-1">Password</label><a href="#" class="text-sm font-medium text-blue-500 hover:text-blue-400">Forgot?</a></div><input type="password" id="password" name="password" class="w-full px-4 py-3 text-base transition-colors duration-200 rounded-lg outline-none focus:ring-4 $INPUT_BG $TEXT_INPUT" placeholder="••••••••" /></div><button type="submit" class="w-full py-3.5 text-base font-bold text-white shadow-lg transition-all duration-200 transform hover:-translate-y-0.5 active:translate-y-0 $BUTTON_COLOR $ROUNDING focus:outline-none focus:ring-4 focus:ring-opacity-50"> $BUTTON_TEXT </button></form><div class="text-center text-xs $TEXT_MUTED"> &copy; $(date +%Y) $TITLE. All rights reserved. </div></div></body></html>
EOF