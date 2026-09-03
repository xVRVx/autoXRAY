#!/bin/bash

TARGET_DIR=$1

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_directory>"
    exit 1
fi

mkdir -p "$TARGET_DIR"

# ==========================================
# 1. ТЕМАТИКИ ПОРТАЛОВ (22 РЕАЛИСТИЧНЫХ ТИПА)
# Формат: Заголовок | Подзаголовок | Бейдж | Placeholder логина | Тип поля
# ==========================================
PORTAL_TYPES=(
    "Corporate SSO Portal|Unified authentication gateway for enterprise applications|Single Sign-On|domain\\username|text"
    "Cloud Object Storage|Authenticate to access private storage clusters & buckets|Storage Node|account-id / access-key|text"
    "Zero Trust Network Access|Continuous verification governed by corporate security policies|Zero Trust|corp-id@domain.com|email"
    "DevOps Infrastructure Hub|Private registry & artifact repository access gateway|Dev Platform|dev-user / email|text"
    "Secure Mail Gateway|Encrypted enterprise messaging & secure webmail bridge|Secure Mail|name@company.com|email"
    "Enterprise Git Service|Restricted developer workspace & repository synchronization|Code Vault|git-handle|text"
    "Privileged Access Manager|Bastion gateway authentication for tier-0/1 infrastructure|PAM Gateway|admin-principal|text"
    "Corporate Wiki & Knowledge Base|Confidential internal documentation & standard operating procedures|Enterprise Wiki|employee-id|text"
    "Edge Cache & CDN Controller|Origin routing policy & distributed edge gateway console|Edge Control|node-operator|text"
    "Telemetry & Monitoring Center|High-availability metrics, trace ingestion & alerts dashboard|Ops Hub|monitoring-user|text"
    "Secure File Exchange|Air-gapped file delivery & transit verification node|File Vault|transfer-key / email|text"
    "Kubernetes Control Plane|RBAC authentication endpoint for managed worker clusters|K8s Dashboard|service-account|text"
    "API Gateway Management|OAuth2 / OIDC token issuance & credential management console|API Portal|client-id|text"
    "VPN & IPsec Concentrator|Encrypted perimeter tunnel for authorized corporate workforce|Network Gateway|vpn-username|text"
    "CI/CD Pipeline Coordinator|Automated runner orchestration & artifact distribution store|Build Farm|pipeline-agent|text"
    "Database Security Proxy|Connection pooling & query audit layer for internal clusters|DB Proxy|cluster-admin|text"
    "Compliance & Audit Vault|Immutable event ledger & compliance record archive|Audit System|compliance-officer|text"
    "Identity & Governance (IAM)|Centralized directory federation & role lifecycle manager|IAM Core|identity-id|text"
    "ERP Operations Hub|Enterprise resource management & financial ledger portal|Enterprise ERP|staff-id|text"
    "Support Escalation Console|Internal tier-3 technical diagnostics & resolution board|Service Desk|tech-agent@support.local|email"
    "Snapshot & Backup Depot|Air-gapped disaster recovery & cold snapshot storage cluster|Backup Node|operator-id|text"
    "Virtual Desktop Gateway|Remote desktop infrastructure & application delivery bridge|VDI Portal|corp\\vdi-user|text"
)

# ==========================================
# 2. ТЕКСТЫ ДЛЯ КНОПОК (32 ВАРИАНТА)
# ==========================================
BUTTON_TEXTS=(
    "Sign In" "Log In" "Authenticate" "Authorize" "Verify Identity"
    "Access Portal" "Proceed to Workspace" "Enter Console" "Confirm & Proceed"
    "Secure Sign In" "Establish Session" "Connect to Gateway" "Sign In to Continue"
    "Verify Credentials" "Access Dashboard" "Unlock Console" "Submit Identification"
    "Continue with SSO" "Go to Dashboard" "Enter System" "Open Workspace"
    "Authenticate Session" "Log In to Account" "Secure Connect" "Verify & Enter"
    "Authorize Access" "Initiate Session" "Launch Console" "Access System"
    "Start Session" "Validate Identity" "Connect"
)

# ==========================================
# 3. ОШИБКИ АУТЕНТИФИКАЦИИ (20 ВАРИАНТОВ)
# ==========================================
ERROR_MESSAGES=(
    "The identity or security key you provided is invalid."
    "Directory service (LDAP/AD) refused the authentication request."
    "Security policy violation: Endpoint not recognized in trust matrix."
    "The requested user principal does not exist in this security realm."
    "Session initialization failed: Certificate thumbprint mismatch."
    "Access denied: Account temporarily locked due to policy thresholds."
    "Network authentication handshake timed out. Please retry."
    "Pre-authentication challenge expired. Refresh and authenticate again."
    "Kerberos ticket validation failed against local realm."
    "IP address restricted by corporate access control list (ACL)."
    "Identity provider node is currently synchronizing. Try again shortly."
    "Unauthorized realm access. Please verify your domain prefix."
    "Cryptographic challenge response was invalid."
    "SAML assertion signature is invalid or expired."
    "User account requires administrator unlock before session binding."
    "Gateway timeout while communicating with identity federation provider."
    "Insufficient privileges to establish session in this operational zone."
    "Clock skew detected between client and identity server."
    "Hardware credential or security certificate not accepted."
    "Authorization payload failed integrity validation check."
)

# ==========================================
# 4. ФИКТИВНЫЕ КОМПАНИИ В ФУТЕР
# ==========================================
COMPANIES=(
    "Global Cloud Infrastructure Systems Ltd."
    "Enterprise Security & Access Technologies Inc."
    "Unified Directory & Identity Platforms"
    "SecureData Telecommunications Group"
    "ZeroTrust Network Architecture International"
    "DataCore Technologies Global Services"
    "OmniVault Enterprise Solutions Corp."
    "HyperScale Systems & Security GmbH"
    "Nexus Identity Management Alliance"
    "Cortex Infrastructure Security Services"
)

# ==========================================
# 5. ИКОНКИ (SVG BASE64)
# ==========================================
FAVICONS=(
    # 1. Cloud
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMjU2M0VCIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0xNy41IDE5YTMuNSAzLjUgMCAwIDAgMC03aC01YTQuNSA0LjUgMCAwIDAtOC44IDIuMUEgNCA0IDAgMCAwIDYgMjFoMTEuNXoiLz48L3N2Zz4="
    # 2. Shield Lock
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDU5NjY5IiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0xMiAyMmw4LTRsLTgtMThsLTggMThsOCA0eiIvPjwvc3ZnPg=="
    # 3. Modern Key
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMEY3NjZFIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0yMSAybC0yIDJtLTcuNjEgNy42MWE1LjUgNS41IDAgMSAxLTcuNzc4IDcuNzc4IDUuNSA1LjUgMCAwIDEgNy43NzctNy43Nzd6bTAgMEwxNS41IDcuNW0wIDBsMyAzTDIyIDdsLTMtM20tMy41IDMuNUwxOSA0Ii8+PC9zdmc+"
    # 4. Cube / Box
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjN0MzM0VBIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0yMSAxNlY4YTIgMiAwIDAgMC0xLTEuNzNsLTctNGEyIDIgMCAwIDAtMiAwbC03IDRBMiAyIDAgMCAwIDMgOHY4YTIgMiAwIDAgMCAxIDEuNzNsNyA0YTIgMiAwIDAgMCAyIDBsNy00QTIgMiAwIDAgMCAyMSAxNnoiLz48L3N2Zz4="
    # 5. Server Rack
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNDc1NTY5IiBzdHJva2Utd2lkdGg9IjIiPjxyZWN0IHg9IjIiIHk9IjIiIHdpZHRoPSIyMCIgaGVpZ2h0PSI4IiByeD0iMiIvPjxyZWN0IHg9IjIiIHk9IjE0IiB3aWR0aD0iMjAiIGhlaWdodD0iOCIgcng9IjIiLz48L3N2Zz4="
    # 6. Terminal Console
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjM0I4MkY2IiBzdHJva2Utd2lkdGg9IjIiPjxwb2x5bGluZSBwb2ludHM9IjQgMTcgMTAgMTEgNCA1Ii8+PGxpbmUgeDE9IjEyIiB5MT0iMTkiIHgyPSIyMCIgeTI9IjE5Ii8+PC9zdmc+"
    # 7. Database
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjRUExODNEIiBzdHJva2Utd2lkdGg9IjIiPjxlbGxpcHNlIGN4PSIxMiIgY3k9IjUiIHJ4PSI5IiByeT0iMyIvPjxwYXRoIGQ9Ik0yMSA4LjVjMCAxLjY2LTQgMy05IDNzLTktMS4zNC05LTMiLz48cGF0aCBkPSJNMjEgMTJjMCAxLjY2LTQgMy05IDNzLTktMS4zNC05LTMiLz48cGF0aCBkPSJNMjEgMTUuNWMwIDEuNjYtNCAzLTkgM3MtOS0xLjM0LTktMyIvPjwvc3ZnPg=="
    # 8. Network Node
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDhBMUIyIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PGxpbmUgeDE9IjIiIHkxPSIxMiIgeDI9IjIyIiB5Mj0iMTIiLz48L3N2Zz4="
)

# ==========================================
# 6. ШРИФТЫ GOOGLE
# ==========================================
FONTS_DATA=(
    "Inter|Inter:wght@400;500;600;700"
    "Plus Jakarta Sans|Plus+Jakarta+Sans:wght@400;500;600;700"
    "Roboto|Roboto:wght@400;500;700"
    "Outfit|Outfit:wght@400;500;600;700"
    "DM Sans|DM+Sans:wght@400;500;700"
    "IBM Plex Sans|IBM+Plex+Sans:wght@400;500;600;700"
    "Open Sans|Open+Sans:wght@400;600;700"
    "Montserrat|Montserrat:wght@400;500;600;700"
)

# ==========================================
# 7. ФОНЫ (12 ТЕМ)
# ==========================================
BG_GRADIENTS=(
    "bg-slate-950 text-slate-100"
    "bg-gray-950 text-gray-100"
    "bg-gradient-to-br from-slate-900 via-gray-900 to-black text-white"
    "bg-gradient-to-tr from-gray-900 via-slate-800 to-slate-950 text-white"
    "bg-gradient-to-br from-slate-950 via-blue-950/40 to-slate-900 text-slate-100"
    "bg-gradient-to-bl from-zinc-900 via-neutral-900 to-black text-neutral-100"
    "bg-gray-50 text-gray-900"
    "bg-slate-50 text-slate-900"
    "bg-gradient-to-br from-slate-50 via-gray-100 to-slate-100 text-gray-900"
    "bg-gradient-to-br from-slate-50 via-blue-50/40 to-indigo-50/30 text-gray-900"
    "bg-gradient-to-tr from-zinc-100 via-stone-50 to-neutral-100 text-neutral-900"
    "bg-gradient-to-b from-slate-900 to-slate-950 text-slate-100"
)

# ==========================================
# 8. КНОПКИ (10 ЦВЕТОВ)
# ==========================================
BUTTON_COLORS=(
    "bg-blue-600 hover:bg-blue-700"
    "bg-indigo-600 hover:bg-indigo-700"
    "bg-teal-600 hover:bg-teal-700"
    "bg-emerald-600 hover:bg-emerald-700"
    "bg-slate-800 hover:bg-slate-900"
    "bg-violet-600 hover:bg-violet-700"
    "bg-cyan-600 hover:bg-cyan-700"
    "bg-sky-600 hover:bg-sky-700"
    "bg-blue-700 hover:bg-blue-800"
    "bg-neutral-800 hover:bg-neutral-900"
)

# ==========================================
# 9. СЛУЧАЙНЫЕ ID (АНТИ-СИГНАТУРА)
# ==========================================
RND_HASH=$(openssl rand -hex 4)
ID_FORM="f_$RND_HASH"
ID_USER="u_$(openssl rand -hex 3)"
ID_PASS="p_$(openssl rand -hex 3)"
ID_REMEMBER="r_$(openssl rand -hex 3)"
ID_BTN="b_$(openssl rand -hex 3)"
ID_TXT="t_$(openssl rand -hex 3)"
ID_ALERT="a_$(openssl rand -hex 3)"
ID_ALERT_TXT="at_$(openssl rand -hex 3)"
CSRF_PARAM="csrf_$(openssl rand -hex 3)"
CSRF_VAL=$(openssl rand -hex 16)

# Выбор случайных значений
PORTAL_INFO=${PORTAL_TYPES[$RANDOM % ${#PORTAL_TYPES[@]}]}
HEADER=$(echo "$PORTAL_INFO" | cut -d'|' -f1)
SUBHEADER=$(echo "$PORTAL_INFO" | cut -d'|' -f2)
BADGE=$(echo "$PORTAL_INFO" | cut -d'|' -f3)
USER_PLACEHOLDER=$(echo "$PORTAL_INFO" | cut -d'|' -f4)
USER_INPUT_TYPE=$(echo "$PORTAL_INFO" | cut -d'|' -f5)

BUTTON_TEXT=${BUTTON_TEXTS[$RANDOM % ${#BUTTON_TEXTS[@]}]}
DEFAULT_ERROR=${ERROR_MESSAGES[$RANDOM % ${#ERROR_MESSAGES[@]}]}
COPYRIGHT=${COMPANIES[$RANDOM % ${#COMPANIES[@]}]}
CURRENT_YEAR=$(date +%Y)

BUTTON_COLOR=${BUTTON_COLORS[$RANDOM % ${#BUTTON_COLORS[@]}]}
BG_STYLE=${BG_GRADIENTS[$RANDOM % ${#BG_GRADIENTS[@]}]}
FAVICON=${FAVICONS[$RANDOM % ${#FAVICONS[@]}]}

FONT_PAIR=${FONTS_DATA[$RANDOM % ${#FONTS_DATA[@]}]}
FONT_NAME=$(echo "$FONT_PAIR" | cut -d'|' -f1)
FONT_URL_PART=$(echo "$FONT_PAIR" | cut -d'|' -f2)

# Рандомизация радиуса скругления карточки
RADII=("0.75rem" "1rem" "1.25rem" "0.5rem")
CARD_RADIUS=${RADII[$RANDOM % ${#RADII[@]}]}

# Настройка темы
if [[ "$BG_STYLE" == *"950"* || "$BG_STYLE" == *"900"* || "$BG_STYLE" == *"black"* ]]; then
    THEME_DARK=1
    CARD_BG="background-color: rgba(15, 23, 42, 0.85); border: 1px solid rgba(51, 65, 85, 0.6); box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6);"
    INPUT_STYLE="background-color: rgba(2, 6, 23, 0.7); border: 1px solid #334155; color: #f8fafc;"
    LABEL_COLOR="#94a3b8"
    ALERT_STYLE="background-color: rgba(69, 10, 10, 0.4); border: 1px solid rgba(153, 27, 27, 0.5); color: #fca5a5;"
    FOOTER_COLOR="#64748b"
    BADGE_STYLE="background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3);"
else
    THEME_DARK=0
    CARD_BG="background-color: rgba(255, 255, 255, 0.95); border: 1px solid #e2e8f0; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.05);"
    INPUT_STYLE="background-color: #ffffff; border: 1px solid #cbd5e1; color: #0f172a;"
    LABEL_COLOR="#475569"
    ALERT_STYLE="background-color: #fef2f2; border: 1px solid #fee2e2; color: #dc2626;"
    FOOTER_COLOR="#94a3b8"
    BADGE_STYLE="background: rgba(37, 99, 235, 0.08); color: #2563eb; border: 1px solid rgba(37, 99, 235, 0.2);"
fi

# ==========================================
# 10. ГЕНЕРАЦИЯ HTML
# ==========================================
cat > "$TARGET_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <title>$HEADER</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=$FONT_URL_PART&display=swap" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="$FAVICON">
    <style>
        *, ::before, ::after { box-sizing: border-box; margin: 0; padding: 0; border: 0 solid transparent; }
        body {
            font-family: '$FONT_NAME', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 1.5rem;
            -webkit-font-smoothing: antialiased;
        }
        .container-box {
            width: 100%;
            max-width: 420px;
            border-radius: $CARD_RADIUS;
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            padding: 2.5rem 2rem;
            $CARD_BG
        }
        .flex { display: flex; }
        .items-center { align-items: center; }
        .justify-between { justify-content: space-between; }
        .space-y-4 > * + * { margin-top: 1.15rem; }
        .text-center { text-align: center; }
        .text-xs { font-size: 0.75rem; line-height: 1rem; }
        .text-sm { font-size: 0.875rem; line-height: 1.25rem; }
        .text-xl { font-size: 1.35rem; font-weight: 700; letter-spacing: -0.015em; }
        .rounded-lg { border-radius: 0.5rem; }
        .p-3 { padding: 0.75rem; }
        .py-2\.5 { padding-top: 0.65rem; padding-bottom: 0.65rem; }
        .px-3\.5 { padding-left: 0.9rem; padding-right: 0.9rem; }
        .mb-6 { margin-bottom: 1.5rem; }
        .badge {
            display: inline-flex;
            padding: 0.25rem 0.65rem;
            border-radius: 9999px;
            font-size: 0.68rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.85rem;
            $BADGE_STYLE
        }
        .input-control {
            width: 100%;
            outline: none;
            transition: all .15s ease;
            font-size: 0.875rem;
            $INPUT_STYLE
        }
        .input-control:focus {
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.25);
            border-color: #3b82f6 !important;
        }
        .btn {
            display: flex;
            justify-content: center;
            align-items: center;
            width: 100%;
            border-radius: 0.5rem;
            font-size: 0.875rem;
            font-weight: 600;
            color: #ffffff;
            cursor: pointer;
            transition: all .15s ease;
            border: none;
        }
        .btn:disabled { opacity: 0.65; cursor: not-allowed; }
        .btn:active:not(:disabled) { transform: scale(0.99); }
        .alert-box {
            display: none;
            margin-bottom: 1.25rem;
            border-radius: 0.5rem;
            font-size: 0.8125rem;
            line-height: 1.25rem;
            $ALERT_STYLE
        }
        .spinner {
            width: 1rem;
            height: 1rem;
            border: 2px solid rgba(255,255,255,0.3);
            border-top-color: #fff;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin-right: 0.5rem;
            display: inline-block;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .footer {
            margin-top: 2.25rem;
            font-size: 0.725rem;
            text-align: center;
            color: $FOOTER_COLOR;
        }
        .footer a { color: inherit; text-decoration: none; margin: 0 0.5rem; }
        .footer a:hover { text-decoration: underline; }
        .checkbox-row {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.8125rem;
            color: $LABEL_COLOR;
        }
        .checkbox-row input { cursor: pointer; }

        /* Фоновые классы */
        .bg-slate-950 { background-color: #020617; }
        .bg-gray-950 { background-color: #030712; }
        .bg-gray-50 { background-color: #f9fafb; }
        .bg-slate-50 { background-color: #f8fafc; }
        .bg-blue-600 { background-color: #2563eb; } .bg-blue-600:hover { background-color: #1d4ed8; }
        .bg-blue-700 { background-color: #1d4ed8; } .bg-blue-700:hover { background-color: #1e40af; }
        .bg-indigo-600 { background-color: #4f46e5; } .bg-indigo-600:hover { background-color: #4338ca; }
        .bg-teal-600 { background-color: #0d9488; } .bg-teal-600:hover { background-color: #0f766e; }
        .bg-emerald-600 { background-color: #059669; } .bg-emerald-600:hover { background-color: #047857; }
        .bg-slate-800 { background-color: #1e293b; } .bg-slate-800:hover { background-color: #0f172a; }
        .bg-violet-600 { background-color: #7c3aed; } .bg-violet-600:hover { background-color: #6d28d9; }
        .bg-cyan-600 { background-color: #0891b2; } .bg-cyan-600:hover { background-color: #0e7490; }
        .bg-sky-600 { background-color: #0284c7; } .bg-sky-600:hover { background-color: #0369a1; }
        .bg-neutral-800 { background-color: #262626; } .bg-neutral-800:hover { background-color: #171717; }
        
        .bg-gradient-to-br { background-image: linear-gradient(to bottom right, var(--tw-gradient-stops, #0f172a, #020617)); }
        .bg-gradient-to-tr { background-image: linear-gradient(to top right, var(--tw-gradient-stops, #111827, #0f172a)); }
    </style>
</head>
<body class="$BG_STYLE">

    <div class="container-box">
        <div class="text-center mb-6">
            <span class="badge">$BADGE</span>
            <h1 class="text-xl">$HEADER</h1>
            <p class="text-xs" style="color: $LABEL_COLOR; margin-top: 0.35rem;">$SUBHEADER</p>
        </div>

        <div id="$ID_ALERT" class="alert-box p-3" role="alert">
            <span id="$ID_ALERT_TXT"></span>
        </div>

        <form id="$ID_FORM" class="space-y-4" method="POST" action="/api/v1/authenticate">
            <input type="hidden" name="$CSRF_PARAM" value="$CSRF_VAL">

            <div>
                <label for="$ID_USER" class="text-xs" style="display:block; font-weight: 600; color: $LABEL_COLOR; margin-bottom: 0.35rem;">Identity Principal</label>
                <input type="$USER_INPUT_TYPE" id="$ID_USER" name="identity" required class="input-control rounded-lg py-2.5 px-3.5" placeholder="$USER_PLACEHOLDER" autocomplete="username">
            </div>

            <div>
                <div class="flex justify-between items-center" style="margin-bottom: 0.35rem;">
                    <label for="$ID_PASS" class="text-xs" style="font-weight: 600; color: $LABEL_COLOR;">Credential Key</label>
                    <a href="#" onclick="return false;" class="text-xs" style="color: $LABEL_COLOR; text-decoration: none;">Forgot Key?</a>
                </div>
                <input type="password" id="$ID_PASS" name="credential" required class="input-control rounded-lg py-2.5 px-3.5" placeholder="••••••••••••" autocomplete="current-password">
            </div>

            <div class="flex justify-between items-center" style="padding-top: 0.25rem;">
                <label class="checkbox-row">
                    <input type="checkbox" id="$ID_REMEMBER" name="persist_session">
                    <span>Keep session active</span>
                </label>
            </div>

            <button type="submit" id="$ID_BTN" class="btn py-2.5 $BUTTON_COLOR" style="margin-top: 1.35rem;">
                <span id="$ID_TXT">$BUTTON_TEXT</span>
            </button>
        </form>
    </div>

    <footer class="footer">
        <p>&copy; $CURRENT_YEAR $COPYRIGHT. All rights reserved.</p>
        <p style="margin-top: 0.4rem;">
            <a href="#" onclick="return false;">Security Policy</a> &bull;
            <a href="#" onclick="return false;">Privacy Regulations</a> &bull;
            <a href="#" onclick="return false;">Acceptable Use</a>
        </p>
    </footer>

    <script>
    (function(){
        const form = document.getElementById('$ID_FORM');
        const btn = document.getElementById('$ID_BTN');
        const txt = document.getElementById('$ID_TXT');
        const alertBox = document.getElementById('$ID_ALERT');
        const alertTxt = document.getElementById('$ID_ALERT_TXT');
        const pwdInput = document.getElementById('$ID_PASS');
        const origBtnText = txt.textContent;

        form.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            alertBox.style.display = 'none';
            btn.disabled = true;
            txt.innerHTML = '<span class="spinner"></span> Authenticating...';

            const payload = {
                identity: document.getElementById('$ID_USER').value,
                credential: pwdInput.value,
                csrf_token: '$CSRF_VAL',
                client_timestamp: Date.now()
            };

            let errMsg = "$DEFAULT_ERROR";

            try {
                const response = await fetch('/api/v1/authenticate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
                    body: JSON.stringify(payload)
                });

                if (response.status === 401 || response.status === 403 || response.status === 400) {
                    const data = await response.json();
                    if (data && data.message) errMsg = data.message;
                } else if (!response.ok) {
                    errMsg = "Gateway error (" + response.status + "). Identity backend unavailable.";
                }
            } catch (err) {
                errMsg = "Network timeout. Authorization node unreachable.";
            }

            // Имитация естественной задержки проверки криптографического хеша (500-1100 мс)
            await new Promise(function(r) { setTimeout(r, 500 + Math.random() * 600); });

            btn.disabled = false;
            txt.textContent = origBtnText;
            alertTxt.textContent = errMsg;
            alertBox.style.display = 'block';

            pwdInput.value = '';
            pwdInput.focus();
        });
    })();
    </script>
</body>
</html>
EOF

# ==========================================
# 11. ROBOTS.TXT
# ==========================================
cat > "$TARGET_DIR/robots.txt" <<EOF
User-agent: *
Disallow: /api/
Disallow: /admin/
Disallow: /auth/
Disallow: /gateway/
Disallow: /private/
Allow: /
EOF

echo "✓ Successfully generated decoy portal in $TARGET_DIR"
echo "  Context : $HEADER ($BADGE)"
echo "  Action  : $BUTTON_TEXT"