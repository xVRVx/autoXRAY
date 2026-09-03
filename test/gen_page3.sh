#!/bin/bash

TARGET_DIR=$1

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_directory>"
    exit 1
fi

mkdir -p "$TARGET_DIR"

# ==========================================
# 1. ТЕМАТИКИ ПОРТАЛОВ (22 ТИПА)
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
    "Database Security|Connection pooling & query audit layer for internal clusters|DB SEC|cluster-admin|text"
    "Compliance & Audit Vault|Immutable event ledger & compliance record archive|Audit System|compliance-officer|text"
    "Identity & Governance (IAM)|Centralized directory federation & role lifecycle manager|IAM Core|identity-id|text"
    "ERP Operations Hub|Enterprise resource management & financial ledger portal|Enterprise ERP|staff-id|text"
    "Support Escalation Console|Internal tier-3 technical diagnostics & resolution board|Service Desk|tech-agent@support.local|email"
    "Snapshot & Backup Depot|Air-gapped disaster recovery & cold snapshot storage cluster|Backup Node|operator-id|text"
    "Virtual Desktop Gateway|Remote desktop infrastructure & application delivery bridge|VDI Portal|corp\\vdi-user|text"
)

# ==========================================
# 2. КНОПКИ (32 ВАРИАНТА)
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
# 3. ВАРИАЦИИ ССЫЛКИ И ОТВЕТОВ СБРОСА
# ==========================================
FORGOT_TEXTS=(
    "Forgot Key?" "Forgot Password?" "Reset Key" "Lost Credential?"
    "Trouble signing in?" "Reset Access" "Lost Security Key?" "Can't sign in?"
    "Account Recovery" "Forgot credentials?"
)

RECOVERY_NOTICES=(
    "Self-service key recovery is restricted by security policy. Contact your system administrator."
    "Automated password reset is disabled for this security realm. Submit a ticket to IT Support."
    "Privileged account unlock requires manual approval by the Security Operations Center (SOC)."
    "Key rotation must be initiated directly through internal directory services (LDAP/Active Directory)."
    "Self-service reset is not permitted from outside the corporate perimeter."
    "Credential recovery challenge must be authorized by your organizational unit supervisor."
    "Hardware security token required for identity recovery. Contact Tier-2/3 Helpdesk."
    "Remote account recovery has been administratively disabled on this edge node."
)

# ==========================================
# 4. ОШИБКИ АУТЕНТИФИКАЦИИ (20 ВАРИАНТОВ)
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
# 5. КОМПАНИИ В ФУТЕР
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
# 6. ИКОНКИ (SVG BASE64)
# ==========================================
FAVICONS=(
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMjU2M0VCIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0xNy41IDE5YTMuNSAzLjUgMCAwIDAgMC03aC01YTQuNSA0LjUgMCAwIDAtOC44IDIuMUEgNCA0IDAgMCAwIDYgMjFoMTEuNXoiLz48L3N2Zz4="
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDU5NjY5IiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0xMiAyMmw4LTRsLTgtMThsLTggMThsOCA0eiIvPjwvc3ZnPg=="
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMEY3NjZFIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0yMSAybC0yIDJtLTcuNjEgNy42MWE1LjUgNS41IDAgMSAxLTcuNzc4IDcuNzc4IDUuNSA1LjUgMCAwIDEgNy43NzctNy43Nzd6bTAgMEwxNS41IDcuNW0wIDBsMyAzTDIyIDdsLTMtM20tMy41IDMuNUwxOSA0Ii8+PC9zdmc+"
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjN0MzM0VBIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0yMSAxNlY4YTIgMiAwIDAgMC0xLTEuNzNsLTctNGEyIDIgMCAwIDAtMiAwbC03IDRBMiAyIDAgMCAwIDMgOHY4YTIgMiAwIDAgMCAxIDEuNzNsNyA0YTIgMiAwIDAgMCAyIDBsNy00QTIgMiAwIDAgMCAyMSAxNnoiLz48L3N2Zz4="
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNDc1NTY5IiBzdHJva2Utd2lkdGg9IjIiPjxyZWN0IHg9IjIiIHk9IjIiIHdpZHRoPSIyMCIgaGVpZ2h0PSI4IiByeD0iMiIvPjxyZWN0IHg9IjIiIHk9IjE0IiB3aWR0aD0iMjAiIGhlaWdodD0iOCIgcng9IjIiLz48L3N2Zz4="
    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDhBMUIyIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PGxpbmUgeDE9IjIiIHkxPSIxMiIgeDI9IjIyIiB5Mj0iMTIiLz48L3N2Zz4="
)

# ==========================================
# 7. ШРИФТЫ
# ==========================================
FONTS_DATA=(
    "Inter|Inter:wght@400;500;600;700"
    "Plus Jakarta Sans|Plus+Jakarta+Sans:wght@400;500;600;700"
    "Roboto|Roboto:wght@400;500;700"
    "Outfit|Outfit:wght@400;500;600;700"
    "DM Sans|DM+Sans:wght@400;500;700"
    "IBM Plex Sans|IBM+Plex+Sans:wght@400;500;600;700"
    "Open Sans|Open+Sans:wght@400;600;700"
)

# ==========================================
# 8. ДВИЖОК ДИЗАЙНА (14 РЕАЛЬНЫХ СТИЛЕЙ)
# ==========================================
# Случайный выбор: 0 = ТЕМНАЯ ТЕМА, 1 = СВЕТЛАЯ ТЕМА
THEME_MODE=$((RANDOM % 2))

if [ $THEME_MODE -eq 0 ]; then
    # --- НАБОР ТЕМНЫХ ТЕМ ---
    DARK_PRESETS=(
        # 1. Deep Slate
        "background: radial-gradient(circle at 50% 0%, #1e293b 0%, #0f172a 100%);|background-color: rgba(30, 41, 59, 0.7); border: 1px solid rgba(71, 85, 105, 0.45); box-shadow: 0 25px 50px -12px rgba(0,0,0,0.65);|#38bdf8"
        # 2. OLED Pure Black
        "background: #000000;|background-color: #0d0d0d; border: 1px solid #262626; box-shadow: 0 20px 40px rgba(0,0,0,0.9);|#ffffff"
        # 3. Cyber Navy
        "background: linear-gradient(135deg, #020617 0%, #0a192f 50%, #020617 100%);|background-color: rgba(10, 25, 47, 0.75); border: 1px solid rgba(56, 189, 248, 0.2); box-shadow: 0 25px 50px -12px rgba(2, 6, 23, 0.8);|#60a5fa"
        # 4. Amethyst Night
        "background: linear-gradient(to bottom right, #090514, #130924, #000000);|background-color: rgba(26, 16, 46, 0.7); border: 1px solid rgba(168, 85, 247, 0.25); box-shadow: 0 25px 50px -12px rgba(0,0,0,0.7);|#c084fc"
        # 5. Emerald Bastion
        "background: radial-gradient(circle at 50% 20%, #062419 0%, #020b08 100%);|background-color: rgba(6, 36, 25, 0.65); border: 1px solid rgba(52, 211, 153, 0.2); box-shadow: 0 25px 50px -12px rgba(0,0,0,0.75);|#34d399"
        # 6. Neutral Charcoal
        "background: #121212;|background-color: #1e1e1e; border: 1px solid #333333; box-shadow: 0 20px 45px rgba(0,0,0,0.8);|#e5e5e5"
        # 7. Steel Blue
        "background: linear-gradient(to bottom, #111827, #030712);|background-color: rgba(31, 41, 55, 0.75); border: 1px solid rgba(75, 85, 99, 0.4); box-shadow: 0 25px 50px -12px rgba(0,0,0,0.7);|#818cf8"
    )
    SELECTED_THEME=${DARK_PRESETS[$RANDOM % ${#DARK_PRESETS[@]}]}
    BODY_BG=$(echo "$SELECTED_THEME" | cut -d'|' -f1)
    CARD_BG=$(echo "$SELECTED_THEME" | cut -d'|' -f2)
    ACCENT_COLOR=$(echo "$SELECTED_THEME" | cut -d'|' -f3)

    TITLE_COLOR="#ffffff"
    SUBTITLE_COLOR="#94a3b8"
    LABEL_COLOR="#cbd5e1"
    FOOTER_COLOR="#64748b"
    INPUT_BG="background-color: rgba(2, 6, 23, 0.6); border: 1px solid #334155; color: #f8fafc;"
    ALERT_BG="background-color: rgba(69, 10, 10, 0.45); border: 1px solid rgba(239, 68, 68, 0.35); color: #fca5a5;"
    BADGE_BG="background: rgba(255, 255, 255, 0.05); color: $ACCENT_COLOR; border: 1px solid rgba(255, 255, 255, 0.1);"

    DARK_BTNS=(
        "background-color: #2563eb;" "background-color: #4f46e5;"
        "background-color: #0d9488;" "background-color: #059669;"
        "background-color: #7c3aed;" "background-color: #262626; border: 1px solid #404040;"
    )
    BTN_BG_STYLE=${DARK_BTNS[$RANDOM % ${#DARK_BTNS[@]}]}
else
    # --- НАБОР СВЕТЛЫХ ТЕМ ---
    LIGHT_PRESETS=(
        # 1. Clean Enterprise
        "background: #f8fafc;|background-color: #ffffff; border: 1px solid #e2e8f0; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.05), 0 8px 10px -6px rgba(0,0,0,0.02);|#2563eb"
        # 2. Warm Stripe-like Gray
        "background: linear-gradient(180deg, #f9fafb 0%, #f3f4f6 100%);|background-color: #ffffff; border: 1px solid #e5e7eb; box-shadow: 0 10px 30px rgba(0,0,0,0.04);|#111827"
        # 3. Soft Azure
        "background: radial-gradient(circle at 50% 0%, #eff6ff 0%, #f8fafc 100%);|background-color: rgba(255, 255, 255, 0.95); border: 1px solid #dbeafe; box-shadow: 0 20px 25px -5px rgba(59, 130, 246, 0.05);|#1d4ed8"
        # 4. Mint Glass
        "background: linear-gradient(135deg, #f0fdf4 0%, #f8fafc 100%);|background-color: #ffffff; border: 1px solid #dcfce7; box-shadow: 0 20px 25px -5px rgba(16, 185, 129, 0.05);|#059669"
        # 5. Minimal Slate
        "background: #f1f5f9;|background-color: #ffffff; border: 1px solid #cbd5e1; box-shadow: 0 10px 25px rgba(0,0,0,0.03);|#334155"
        # 6. Cool Indigo Tint
        "background: linear-gradient(to bottom right, #f5f3ff, #f8fafc);|background-color: #ffffff; border: 1px solid #ede9fe; box-shadow: 0 20px 30px rgba(124, 58, 237, 0.04);|#6d28d9"
        # 7. Pure Modern White
        "background: #ffffff;|background-color: #ffffff; border: 1px solid #e2e8f0; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.08);|#2563eb"
    )
    SELECTED_THEME=${LIGHT_PRESETS[$RANDOM % ${#LIGHT_PRESETS[@]}]}
    BODY_BG=$(echo "$SELECTED_THEME" | cut -d'|' -f1)
    CARD_BG=$(echo "$SELECTED_THEME" | cut -d'|' -f2)
    ACCENT_COLOR=$(echo "$SELECTED_THEME" | cut -d'|' -f3)

    TITLE_COLOR="#0f172a"
    SUBTITLE_COLOR="#475569"
    LABEL_COLOR="#334155"
    FOOTER_COLOR="#94a3b8"
    INPUT_BG="background-color: #ffffff; border: 1px solid #cbd5e1; color: #0f172a;"
    ALERT_BG="background-color: #fef2f2; border: 1px solid #fee2e2; color: #dc2626;"
    BADGE_BG="background: rgba(0, 0, 0, 0.04); color: $ACCENT_COLOR; border: 1px solid rgba(0, 0, 0, 0.08);"

    LIGHT_BTNS=(
        "background-color: #2563eb;" "background-color: #0f172a;"
        "background-color: #4f46e5;" "background-color: #0d9488;"
        "background-color: #059669;" "background-color: #1e293b;"
    )
    BTN_BG_STYLE=${LIGHT_BTNS[$RANDOM % ${#LIGHT_BTNS[@]}]}
fi

# ==========================================
# 9. СЛУЧАЙНЫЕ ID И ЗНАЧЕНИЯ
# ==========================================
ID_FORM="f_$(openssl rand -hex 4)"
ID_USER="u_$(openssl rand -hex 3)"
ID_PASS="p_$(openssl rand -hex 3)"
ID_REMEMBER="r_$(openssl rand -hex 3)"
ID_FORGOT="fk_$(openssl rand -hex 3)"
ID_BTN="b_$(openssl rand -hex 3)"
ID_TXT="t_$(openssl rand -hex 3)"
ID_ALERT="a_$(openssl rand -hex 3)"
ID_ALERT_TXT="at_$(openssl rand -hex 3)"
CSRF_PARAM="csrf_$(openssl rand -hex 3)"
CSRF_VAL=$(openssl rand -hex 16)

PORTAL_INFO=${PORTAL_TYPES[$RANDOM % ${#PORTAL_TYPES[@]}]}
HEADER=$(echo "$PORTAL_INFO" | cut -d'|' -f1)
SUBHEADER=$(echo "$PORTAL_INFO" | cut -d'|' -f2)
BADGE=$(echo "$PORTAL_INFO" | cut -d'|' -f3)
USER_PLACEHOLDER=$(echo "$PORTAL_INFO" | cut -d'|' -f4)
USER_INPUT_TYPE=$(echo "$PORTAL_INFO" | cut -d'|' -f5)

BUTTON_TEXT=${BUTTON_TEXTS[$RANDOM % ${#BUTTON_TEXTS[@]}]}
DEFAULT_ERROR=${ERROR_MESSAGES[$RANDOM % ${#ERROR_MESSAGES[@]}]}
FORGOT_TEXT=${FORGOT_TEXTS[$RANDOM % ${#FORGOT_TEXTS[@]}]}
RECOVERY_NOTICE=${RECOVERY_NOTICES[$RANDOM % ${#RECOVERY_NOTICES[@]}]}

COPYRIGHT=${COMPANIES[$RANDOM % ${#COMPANIES[@]}]}
CURRENT_YEAR=$(date +%Y)
FAVICON=${FAVICONS[$RANDOM % ${#FAVICONS[@]}]}

FONT_PAIR=${FONTS_DATA[$RANDOM % ${#FONTS_DATA[@]}]}
FONT_NAME=$(echo "$FONT_PAIR" | cut -d'|' -f1)
FONT_URL_PART=$(echo "$FONT_PAIR" | cut -d'|' -f2)

RADII=("0.5rem" "0.75rem" "1rem" "1.25rem")
CARD_RADIUS=${RADII[$RANDOM % ${#RADII[@]}]}

# ==========================================
# 10. ГЕНЕРАЦИЯ HTML (ЧЕТКИЕ СТИЛИ БЕЗ ОШИБОК)
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
        html, body { min-height: 100vh; }
        body {
            font-family: '$FONT_NAME', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 1.5rem;
            -webkit-font-smoothing: antialiased;
            $BODY_BG
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
        .portal-title {
            font-size: 1.35rem;
            font-weight: 700;
            letter-spacing: -0.015em;
            color: $TITLE_COLOR !important;
            margin: 0;
        }
        .portal-desc {
            font-size: 0.78rem;
            color: $SUBTITLE_COLOR !important;
            margin-top: 0.4rem;
            line-height: 1.25rem;
        }
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
            margin-bottom: 0.75rem;
            $BADGE_BG
        }
        .input-control {
            width: 100%;
            outline: none;
            transition: all .15s ease;
            font-size: 0.875rem;
            $INPUT_BG
        }
        .input-control:focus {
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.25);
            border-color: #3b82f6 !important;
        }
        .form-label {
            display: block;
            font-size: 0.75rem;
            font-weight: 600;
            color: $LABEL_COLOR !important;
            margin-bottom: 0.35rem;
        }
        .btn {
            display: flex;
            justify-content: center;
            align-items: center;
            width: 100%;
            border-radius: 0.5rem;
            font-size: 0.875rem;
            font-weight: 600;
            color: #ffffff !important;
            cursor: pointer;
            transition: all .15s ease;
            border: none;
            $BTN_BG_STYLE
        }
        .btn:hover { opacity: 0.92; }
        .btn:disabled { opacity: 0.65; cursor: not-allowed; }
        .btn:active:not(:disabled) { transform: scale(0.99); }
        .alert-box {
            display: none;
            margin-bottom: 1.25rem;
            border-radius: 0.5rem;
            font-size: 0.8125rem;
            line-height: 1.25rem;
            $ALERT_BG
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
            color: $FOOTER_COLOR !important;
        }
        .footer a { color: inherit; text-decoration: none; margin: 0 0.5rem; }
        .footer a:hover { text-decoration: underline; }
        .link-action { text-decoration: none; cursor: pointer; color: $SUBTITLE_COLOR; }
        .link-action:hover { text-decoration: underline; color: $TITLE_COLOR; }
        .checkbox-row {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.8125rem;
            color: $LABEL_COLOR !important;
        }
        .checkbox-row input { cursor: pointer; }
    </style>
</head>
<body>

    <div class="container-box">
        <div class="text-center mb-6">
            <span class="badge">$BADGE</span>
            <h1 class="portal-title">$HEADER</h1>
            <p class="portal-desc">$SUBHEADER</p>
        </div>

        <div id="$ID_ALERT" class="alert-box p-3" role="alert">
            <span id="$ID_ALERT_TXT"></span>
        </div>

        <form id="$ID_FORM" class="space-y-4" method="POST" action="/api/v1/authenticate">
            <input type="hidden" name="$CSRF_PARAM" value="$CSRF_VAL">

            <div>
                <label for="$ID_USER" class="form-label">Identity Principal</label>
                <input type="$USER_INPUT_TYPE" id="$ID_USER" name="identity" required class="input-control rounded-lg py-2.5 px-3.5" placeholder="$USER_PLACEHOLDER" autocomplete="username">
            </div>

            <div>
                <div class="flex justify-between items-center" style="margin-bottom: 0.35rem;">
                    <label for="$ID_PASS" class="form-label" style="margin-bottom: 0;">Credential Key</label>
                    <a href="#" id="$ID_FORGOT" class="text-xs link-action">$FORGOT_TEXT</a>
                </div>
                <input type="password" id="$ID_PASS" name="credential" required class="input-control rounded-lg py-2.5 px-3.5" placeholder="••••••••••••" autocomplete="current-password">
            </div>

            <div class="flex justify-between items-center" style="padding-top: 0.25rem;">
                <label class="checkbox-row">
                    <input type="checkbox" id="$ID_REMEMBER" name="persist_session">
                    <span>Keep session active</span>
                </label>
            </div>

            <button type="submit" id="$ID_BTN" class="btn py-2.5" style="margin-top: 1.35rem;">
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
        const forgotBtn = document.getElementById('$ID_FORGOT');
        const origBtnText = txt.textContent;

        if (forgotBtn) {
            forgotBtn.addEventListener('click', function(e) {
                e.preventDefault();
                alertTxt.textContent = "$RECOVERY_NOTICE";
                alertBox.style.display = 'block';
            });
        }

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
echo "  Mode    : $( [ $THEME_MODE -eq 0 ] && echo "Dark" || echo "Light" )"
echo "  Context : $HEADER ($BADGE)"
echo "  Action  : $BUTTON_TEXT"