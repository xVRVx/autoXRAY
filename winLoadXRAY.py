import tkinter as tk
import customtkinter as ctk
from PIL import Image, ImageTk
import base64
import requests
import json
import sys
import os
import shutil
import subprocess
import winreg
import re
import webbrowser
import threading
import time
import random
import copy
import ssl
import concurrent.futures
import urllib.parse
from urllib.parse import urlparse, parse_qs, unquote
import socket

# Пытаемся подключить библиотеку для системного трея
try:
    import pystray
    from pystray import MenuItem as tray_item
    HAS_TRAY = True
except ImportError:
    HAS_TRAY = False

sys.path.append(os.path.join(os.path.dirname(__file__), 'func'))
from parsing import parse_vless, parse_hy2, parse_node_url
from configXray import generate_config
from copyPast import cmd_copy, cmd_cut, cmd_select_all

ctk.set_appearance_mode("dark")

APP_NAME = "winLoadXRAY"
APP_VERS = "v1.28-beta"
XRAY_VERS = "v26.7.28"

AUTO_CONFIG_TAG = "⚡ Автоконфиг"

xray_process = None
IS_AUTOSTART = "--autostart" in sys.argv

# --- IPC для обработки ссылок winloadxray:// и WAKEUP ---
IPC_PORT = 20810

def get_url_from_args():
    for arg in sys.argv:
        if arg.lower().startswith("winloadxray://add/"):
            return arg[18:] # Отрезаем префикс
    return None

def send_url_to_existing_instance(url):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(1)
            s.connect(("127.0.0.1", IPC_PORT))
            s.sendall(url.encode('utf-8'))
        return True
    except:
        return False

# Сразу перехватываем ссылку до инициализации графики
startup_url = get_url_from_args()
msg = startup_url if startup_url else "WAKEUP"
if send_url_to_existing_instance(msg):
    sys.exit(0) 

BASE_APP_DIR = os.path.join(os.getenv('APPDATA'), APP_NAME)
PROFILES_DIR = os.path.join(BASE_APP_DIR, 'profiles')
os.makedirs(PROFILES_DIR, exist_ok=True)

CONFIGS_DIR = ""
LINKS_FILE = ""
STATE_FILE = ""
active_profile = "Default"

active_tag = None
proxy_enabled = False
base64_urls = []
configs = {}

# Параметры автообновления
auto_update_interval = 0  # в часах (0 = отключено)
last_update_timestamp = 0 # Unix time последнего обновления

# --- Функция логов в GUI (вместо messagebox) ---
def log_message(text, color="#BDC3C7"):
    def _update():
        lbl_status.configure(text=f"• {text}", text_color=color)
    if threading.current_thread() is threading.main_thread():
        _update()
    else:
        root.after(0, _update)

# --- Инструменты ---
def sanitize_filename(name):
    return re.sub(r'[<>:"/\\|?*]', '_', name).strip()

def safe_b64decode(s):
    s = s.strip()
    return base64.b64decode(s + '=' * (-len(s) % 4)).decode('utf-8', errors='ignore')

def split_flag(tag):
    if len(tag) >= 2 and '\U0001F1E6' <= tag[0] <= '\U0001F1FF' and '\U0001F1E6' <= tag[1] <= '\U0001F1FF':
        return tag[:2], tag[2:].strip()
    if len(tag) >= 1 and ord(tag[0]) > 0x2500 and not (0x4E00 <= ord(tag[0]) <= 0x9FFF):
        return tag[0], tag[1:].strip()
    return "", tag

def is_g_node(tag_name: str) -> bool:
    """Проверяет, оканчивается ли название сервера на 'G' (для Gemini/Google-роутинга)"""
    t = tag_name.strip()
    return bool(re.search(r'(\s|[-_0-9]|^)[Gg]$', t))

# Определение типа конфига (vless reality, vless tls, hysteria2 и т.д.)
def get_config_type(data):
    try:
        if "routing" in data and "balancers" in data.get("routing", {}):
            return "БАЛАНСИР"

        proto = ""
        net = ""
        sec = ""

        # Вариант 1: Данные получены напрямую из парсера ссылки (vless://...)
        if "outbounds" not in data:
            proto = data.get("protocol", "").lower()
            net = data.get("network") or data.get("type") or "raw"
            sec = data.get("security", "").lower()
            
            if not sec:
                if data.get("pbk") or data.get("publicKey") or data.get("realitySettings"):
                    sec = "reality"
                elif data.get("tls") or data.get("tlsSettings"):
                    sec = "tls"

        # Вариант 2: Готовый JSON Xray-конфига (из файла или подписки)
        else:
            outbounds = data.get("outbounds", [])
            if not outbounds or len(outbounds) > 4:
                return "XRAY"
            
            first = outbounds[0]
            proto = first.get("protocol", "").lower()
            stream = first.get("streamSettings", {})
            net = stream.get("network", "raw")
            sec = stream.get("security", "").lower()

            if not sec:
                if "realitySettings" in stream:
                    sec = "reality"
                elif "tlsSettings" in stream:
                    sec = "tls"

        proto = proto.lower()
        net = net.lower()
        sec = sec.lower()

        # Hysteria / Hy2
        if proto in ("hysteria", "hy2", "hysteria2"):
            return "hysteria2"

        # VLESS
        if proto == "vless":
            if sec in ("reality", "tls"):
                if net in ("raw", "tcp", ""):
                    return f"vless {sec}"
                return f"vless {net} {sec}"
            return f"vless {net}"

        # Trojan
        if proto == "trojan":
            return f"trojan {sec}" if sec else "trojan tls"

        # Другие протоколы
        if proto:
            if sec in ("reality", "tls"):
                return f"{proto} {sec}"
            return proto.upper()

        return "XRAY"
    except:
        return "XRAY"

def get_server_endpoint_from_config(file_path: str):
    """Извлекает реальный адрес, порт и SNI сервера из JSON-конфига"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        if not ("outbounds" in config and len(config['outbounds']) > 0):
            return None, None, None
        outbound = config['outbounds'][0]
        settings = outbound.get('settings', {})
        stream = outbound.get('streamSettings', {})
        
        sni = None
        if 'realitySettings' in stream:
            sni = stream['realitySettings'].get('serverName')
        elif 'tlsSettings' in stream:
            sni = stream['tlsSettings'].get('serverName')

        address = None
        port = 443

        # vnext (VLESS, VMess)
        if 'vnext' in settings and len(settings['vnext']) > 0:
            vn = settings['vnext'][0]
            address = vn.get('address')
            port = vn.get('port', 443)
        # servers (Trojan, Shadowsocks)
        elif 'servers' in settings and len(settings['servers']) > 0:
            srv = settings['servers'][0]
            address = srv.get('address')
            port = srv.get('port', 443)
        # Hysteria2 / прямое указание
        elif 'address' in settings:
            address = settings.get('address')
            port = settings.get('port', 443)
        elif 'address' in outbound:
            address = outbound.get('address')
            port = outbound.get('port', 443)

        return address, port, sni
    except Exception:
        return None, None, None

def tcp_ping(host: str, port: int, timeout: float = 2.5) -> (int, str):
    """Базовый TCP пинг по рукопожатию (SYN -> SYN-ACK)"""
    if not host or not port:
        return -1, "No Host"
    try:
        t0 = time.perf_counter()
        with socket.create_connection((host, int(port)), timeout=timeout):
            pass
        latency = round((time.perf_counter() - t0) * 1000)
        return latency, "OK"
    except socket.timeout:
        return -1, "Таймаут"
    except Exception:
        return -1, "Ошибка"

def tls_ping(host: str, port: int, sni: str = None, timeout: float = 3.5) -> (int, str):
    """
    Полноценное TLS-рукопожатие с SNI и передачей HTTP-заголовков.
    Проверяет, пропускает ли ТСПУ/DPI данный VLESS Reality / TLS туннель.
    """
    if not host or not port:
        return -1, "No Host"
    sock = None
    try:
        t0 = time.perf_counter()
        sock = socket.create_connection((host, int(port)), timeout=timeout)
        
        # Настраиваем контекст TLS (без проверки сертификата, т.к. Reality маскирует сертификаты)
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        server_hostname = sni if sni else host
        with context.wrap_socket(sock, server_hostname=server_hostname) as ssock:
            # Отправляем реальный HTTP HEAD-запрос с браузерным заголовком
            http_req = (
                f"HEAD / HTTP/1.1\r\n"
                f"Host: {server_hostname}\r\n"
                f"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36\r\n"
                f"Accept: */*\r\n"
                f"Connection: close\r\n\r\n"
            ).encode('utf-8')
            ssock.sendall(http_req)
            _ = ssock.recv(256)
            
        latency = round((time.perf_counter() - t0) * 1000)
        return latency, "OK"
    except socket.timeout:
        return -1, "Таймаут"
    except ssl.SSLError:
        return -1, "TLS Сброс"
    except Exception:
        return -1, "Ошибка"
    finally:
        if sock:
            try: sock.close()
            except: pass

def smart_ping(host: str, port: int, sni: str = None, timeout: float = 3.5) -> (int, str):
    """Умная проверка: если есть SNI — проверяет через полное TLS-соединение, иначе по TCP"""
    if sni:
        res, status = tls_ping(host, port, sni, timeout=timeout)
        if res >= 0:
            return res, status
    return tcp_ping(host, port, timeout=2.5)

def real_proxy_ping(host="127.0.0.1", port=2080, timeout=4.0) -> (int, str):
    """
    Реальный сквозной пинг через локальный прокси Xray (SOCKS5 или HTTP)
    на чистых сокетах без сторонних зависимостей (PySocks).
    Отправляет полноценный HTTP GET запрос с заголовками к генератору 204 Cloudflare.
    """
    t0 = time.perf_counter()
    try:
        # 1. Сначала пробуем протокол SOCKS5 (RFC 1928)
        try:
            with socket.create_connection((host, int(port)), timeout=timeout) as s:
                s.settimeout(timeout)
                # Приветствие SOCKS5: Версия 5, 1 метод, без аутентификации (0x00)
                s.sendall(b'\x05\x01\x00')
                auth_resp = s.recv(2)
                
                if auth_resp == b'\x05\x00':
                    # CONNECT к cp.cloudflare.com:80
                    domain = b'cp.cloudflare.com'
                    connect_req = b'\x05\x01\x00\x03' + bytes([len(domain)]) + domain + (80).to_bytes(2, 'big')
                    s.sendall(connect_req)
                    conn_resp = s.recv(512)
                    
                    if conn_resp and len(conn_resp) >= 2 and conn_resp[1] == 0:
                        # Туннель готов. Шлем полноценный HTTP-запрос
                        http_req = (
                            b"GET /generate_204 HTTP/1.1\r\n"
                            b"Host: cp.cloudflare.com\r\n"
                            b"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\r\n"
                            b"Accept: */*\r\n"
                            b"Connection: close\r\n\r\n"
                        )
                        s.sendall(http_req)
                        data = s.recv(512)
                        if b"204" in data or b"200" in data or b"301" in data:
                            return round((time.perf_counter() - t0) * 1000), "OK"
                        return -1, "HTTP Err"
                    return -1, "SOCKS5 Err"
        except Exception:
            pass

        # 2. Если на порту HTTP-прокси (а не SOCKS5)
        with socket.create_connection((host, int(port)), timeout=timeout) as s:
            s.settimeout(timeout)
            http_proxy_req = (
                b"GET http://cp.cloudflare.com/generate_204 HTTP/1.1\r\n"
                b"Host: cp.cloudflare.com\r\n"
                b"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\r\n"
                b"Proxy-Connection: close\r\n\r\n"
            )
            s.sendall(http_proxy_req)
            data = s.recv(512)
            if b"204" in data or b"200" in data or b"301" in data:
                return round((time.perf_counter() - t0) * 1000), "OK"
            return -1, "HTTP Err"

    except socket.timeout:
        return -1, "Таймаут"
    except Exception:
        return -1, "Ошибка"

# --- Профили и Файлы ---
def setup_active_profile(profile_name):
    global CONFIGS_DIR, LINKS_FILE, STATE_FILE, active_profile, configs, base64_urls, auto_update_interval, last_update_timestamp, active_tag
    active_profile = profile_name
    active_tag = None
    CONFIGS_DIR = os.path.join(PROFILES_DIR, profile_name)
    os.makedirs(CONFIGS_DIR, exist_ok=True)
    LINKS_FILE = os.path.join(CONFIGS_DIR, "links.json")
    STATE_FILE = os.path.join(CONFIGS_DIR, "state.json")
    configs.clear()
    base64_urls = []
    auto_update_interval = 0
    last_update_timestamp = 0
    
    settings_path = os.path.join(BASE_APP_DIR, "settings.json")
    try:
        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump({"active_profile": active_profile}, f)
    except: pass

def get_profiles():
    profs = [d for d in os.listdir(PROFILES_DIR) if os.path.isdir(os.path.join(PROFILES_DIR, d))]
    return profs if profs else ["Default"]

def load_initial_profile():
    settings_path = os.path.join(BASE_APP_DIR, "settings.json")
    prof = "Default"
    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as f:
                prof = json.load(f).get("active_profile", "Default")
        except: pass
    if not os.path.exists(os.path.join(PROFILES_DIR, prof)): prof = "Default"
    setup_active_profile(prof)

def save_state():
    tag_to_save = active_tag if active_tag else (config_list.selected_tag if 'config_list' in globals() else None)
    state = {
        "active_tag": active_tag, 
        "selected_tag": tag_to_save,
        "proxy_enabled": proxy_enabled,
        "update_interval": auto_update_interval,
        "last_update": last_update_timestamp
    }
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except: pass

def load_state(is_initial=False):
    global active_tag, proxy_enabled, auto_update_interval, last_update_timestamp
    if not is_initial:
        active_tag = None
        if 'config_list' in globals():
            config_list.selected_tag = None
            config_list.update_colors()
        if 'btn_run' in globals():
            btn_run.configure(text="Запустить конфиг", fg_color=["#3B8ED0", "#1F6AA5"], hover_color=["#36719F", "#144870"])
        update_proxy_button_color()

    if not os.path.exists(STATE_FILE): return
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            state = json.load(f)
        saved_active_tag = state.get("active_tag")
        saved_selected_tag = state.get("selected_tag") or saved_active_tag
        saved_proxy = state.get("proxy_enabled", False)
        auto_update_interval = state.get("update_interval", 0)
        last_update_timestamp = state.get("last_update", 0)

        if is_initial:
            if saved_proxy:
                proxy_enabled = False
                toggle_system_proxy()

            if saved_active_tag and saved_active_tag in configs:
                config_list.select(saved_active_tag)
                config_path = os.path.join(CONFIGS_DIR, f"{saved_active_tag}.json")
                if os.path.exists(config_path) and os.path.exists(XRAY_EXE):
                    global xray_process
                    xray_process = subprocess.Popen([XRAY_EXE, "-config", config_path], creationflags=CREATE_NO_WINDOW)
                    highlight_active(saved_active_tag)
                    btn_run.configure(text="Остановить конфиг", fg_color="#27AE60", hover_color="#2ECC71")
                    log_message(f"Конфиг '{saved_active_tag}' запущен", "#2ECC71")
            elif saved_selected_tag and saved_selected_tag in configs:
                config_list.select(saved_selected_tag)
        else:
            # При переключении профиля Xray всегда остановлен, конфиг не должен гореть зеленым
            active_tag = None
            tag_to_select = saved_selected_tag if (saved_selected_tag and saved_selected_tag in configs) else None
            if tag_to_select:
                config_list.select(tag_to_select)
            else:
                config_list.selected_tag = None
                config_list.update_colors()
    except: pass

def load_base64_urls():
    configs.clear()
    config_list.clear()

    # Сначала загружаем Автоконфиг (если есть), чтобы он был самым первым в списке
    auto_file = f"{AUTO_CONFIG_TAG}.json"
    auto_path = os.path.join(CONFIGS_DIR, auto_file)
    if os.path.exists(auto_path):
        try:
            with open(auto_path, "r", encoding="utf-8") as f:
                config_data = json.load(f)
                tag = config_data.get("tag", AUTO_CONFIG_TAG)
                configs[tag] = config_data
                ctype = get_config_type(config_data)
                config_list.insert(tag, ctype)
        except Exception:
            pass

    for filename in os.listdir(CONFIGS_DIR):
        if filename.endswith(".json") and filename not in ("links.json", "state.json", auto_file):
            try:
                with open(os.path.join(CONFIGS_DIR, filename), "r", encoding="utf-8") as f:
                    config_data = json.load(f)
                    tag = config_data.get("tag", os.path.splitext(filename)[0])
                    configs[tag] = config_data
                    ctype = get_config_type(config_data)
                    config_list.insert(tag, ctype)
            except: pass

    global base64_urls
    if os.path.exists(LINKS_FILE):
        with open(LINKS_FILE, "r", encoding="utf-8") as f:
            links = json.load(f)
        base64_urls = links if isinstance(links, list) else []
    else:
        base64_urls = []
        
    entry.delete(0, 'end')
    if base64_urls:
        entry.insert(0, base64_urls[0])

def save_base64_urls():
    with open(LINKS_FILE, "w", encoding="utf-8") as f:
        json.dump(base64_urls, f, ensure_ascii=False, indent=2)

def clear_xray_configs():
    configs.clear()
    config_list.clear()
    for filename in os.listdir(CONFIGS_DIR):
        if filename.endswith(".json") and filename not in ("links.json", "state.json"):
            try: os.remove(os.path.join(CONFIGS_DIR, filename))
            except: pass

# --- Автобалансировщик Xray (leastPing + Gemini роутинг + Обход РФ) ---
def generate_balancer_config():
    """Собирает ноды профиля в балансировщик (leastPing) с отдельным пулом под Gemini для нод с буквой G"""
    auto_config_path = os.path.join(CONFIGS_DIR, f"{AUTO_CONFIG_TAG}.json")
    
    collected_outbounds = []
    base_inbounds = None
    g_count = 0
    main_count = 0

    for filename in os.listdir(CONFIGS_DIR):
        if not filename.endswith(".json"):
            continue
        if filename in ("links.json", "state.json", f"{AUTO_CONFIG_TAG}.json"):
            continue

        try:
            with open(os.path.join(CONFIGS_DIR, filename), "r", encoding="utf-8") as f:
                data = json.load(f)

            outbounds = data.get("outbounds", [])
            if not outbounds:
                continue

            node_outbound = copy.deepcopy(outbounds[0])
            proto = node_outbound.get("protocol", "").lower()
            if proto in ("freedom", "blackhole", "dns", ""):
                continue

            if not base_inbounds and data.get("inbounds"):
                base_inbounds = copy.deepcopy(data["inbounds"])

            # Проверяем, относится ли нода к группе 'G' (Gemini)
            tag_name = data.get("tag", os.path.splitext(filename)[0])
            if is_g_node(tag_name):
                node_outbound["tag"] = f"node-g-{g_count}"
                g_count += 1
            else:
                node_outbound["tag"] = f"node-m-{main_count}"
                main_count += 1

            collected_outbounds.append(node_outbound)
        except Exception:
            continue

    total_nodes = g_count + main_count
    if total_nodes < 2:
        return False, 0

    if not base_inbounds:
        base_inbounds = [
            {
                "tag": "socks-in",
                "port": 2080,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "settings": {"udp": True, "auth": "noauth"}
            }
        ]

    balancers = []
    rules = []

    # 1. Блокировка рекламы и телеметрии
    rules.append({
        "type": "field",
        "domain": [
            "geosite:category-ads",
            "geosite:win-spy"
        ],
        "outboundTag": "block"
    })

    # 2. Торренты мимо прокси (напрямую)
    rules.append({
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "direct"
    })

    # 3. Gemini — пускаем строго на G-балансировщик (если G-ноды есть)
    if g_count > 0:
        balancers.append({
            "tag": "gemini-balancer",
            "selector": ["node-g-"],
            "strategy": {
                "type": "leastPing"
            },
            "fallbackTag": "node-g-0"
        })
        rules.append({
            "type": "field",
            "domain": [
                "geosite:google-gemini",
                "domain:gemini.google.com",
                "domain:generativeai.google",
                "domain:proactivebackend-pa.googleapis.com",
                "domain:alkalimakersuite-pa.clients6.google.com"
            ],
            "balancerTag": "gemini-balancer"
        })

    # 4. Исключения (сайты, которые должны идти через прокси, даже если это .ru или СНГ)
    rules.append({
        "type": "field",
        "domain": [
            "habr.com",
            "apkmirror.com"
        ],
        "balancerTag": "auto-balancer"
    })

    # 5. Российские домены и сервисы — напрямую (DIRECT)
    rules.append({
        "type": "field",
        "domain": [
            "geosite:private",
            "ifconfig.me",
            "checkip.amazonaws.com",
            "pify.org",
            "domain:ru",
            "domain:su",
            "domain:xn--p1ai",
            "geosite:category-ip-geo-detect",
            "geosite:apple",
            "geosite:apple-pki",
            "geosite:yandex",
            "geosite:vk",
            "geosite:category-ru"
        ],
        "outboundTag": "direct"
    })

    # 6. Российские IP-адреса — напрямую (DIRECT)
    rules.append({
        "type": "field",
        "ip": [
            "geoip:ru",
            "geoip:private"
        ],
        "outboundTag": "direct"
    })

    # 7. Основной балансировщик для всего остального зарубежного трафика
    fallback_node = "node-g-0" if (main_count == 0 and g_count > 0) else "node-m-0"
    balancers.append({
        "tag": "auto-balancer",
        "selector": ["node-"],
        "strategy": {
            "type": "leastPing"
        },
        "fallbackTag": fallback_node
    })
    rules.append({
        "type": "field",
        "network": "tcp,udp",
        "balancerTag": "auto-balancer"
    })

    # Интервал: 120 секунд для Gemini, 90 секунд для обычных серверов
    interval = "120s" if g_count > 0 else "90s"
    probe_url = "http://www.google.com/generate_204" if g_count > 0 else "http://cp.cloudflare.com/generate_204"

    master_config = {
        "log": {"loglevel": "warning"},
        "inbounds": base_inbounds,
        "observatory": {
            "subjectSelector": ["node-"],
            "probeURL": probe_url,
            "probeInterval": interval,
            "enableConcurrency": True
        },
        "routing": {
            "domainMatcher": "hybrid",
            "domainStrategy": "IPIfNonMatch",
            "balancers": balancers,
            "rules": rules
        },
        "outbounds": collected_outbounds + [
            {"tag": "direct", "protocol": "freedom"},
            {"tag": "block", "protocol": "blackhole"}
        ]
    }

    try:
        with open(auto_config_path, "w", encoding="utf-8") as f:
            json.dump(master_config, f, indent=2, ensure_ascii=False)

        configs[AUTO_CONFIG_TAG] = master_config
        ctype = get_config_type(master_config)
        config_list.insert(AUTO_CONFIG_TAG, ctype, at_top=True)
        return True, g_count
    except Exception as e:
        log_message(f"Ошибка создания балансировщика: {e}", "#E74C3C")
        return False, 0

def on_manual_balancer_click():
    ok, g_count = generate_balancer_config()
    if ok:
        interval_str = "120с" if g_count > 0 else "90с"
        g_info = f" (Gemini -> G-ноды: {g_count}, интервал: {interval_str})" if g_count > 0 else f" (интервал: {interval_str})"
        log_message(f"⚡ Автоконфиг успешно создан/обновлен{g_info}", "#2ECC71")
    else:
        log_message("Для балансировщика нужно минимум 2 сервера", "#F39C12")

# --- Основные функции ---
def toggle_system_proxy(host="127.0.0.1", port=2080):
    global proxy_enabled
    path = r"Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path, 0, winreg.KEY_SET_VALUE) as key:
            if not proxy_enabled:
                winreg.SetValueEx(key, "ProxyEnable", 0, winreg.REG_DWORD, 1)
                winreg.SetValueEx(key, "ProxyServer", 0, winreg.REG_SZ, f"{host}:{port}")
                proxy_enabled = True
                log_message("Системный прокси включен", "#2ECC71")
            else:
                winreg.SetValueEx(key, "ProxyEnable", 0, winreg.REG_DWORD, 0)
                proxy_enabled = False
                log_message("Системный прокси выключен")
        save_state()
        update_proxy_button_color()
    except Exception as e:
        log_message(f"Не удалось переключить прокси: {e}", "#E74C3C")

def stop_system_proxy(is_quitting=False):
    global proxy_enabled
    try:
        path = r"Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path, 0, winreg.KEY_SET_VALUE) as key:
            winreg.SetValueEx(key, "ProxyEnable", 0, winreg.REG_DWORD, 0)
        if not is_quitting:
            proxy_enabled = False
            update_proxy_button_color()
            save_state()
    except: pass

def update_proxy_button_color():
    if proxy_enabled:
        btn_proxy.configure(text="Выключить системный прокси", fg_color="#D35400", hover_color="#A04000")
    else:
        btn_proxy.configure(text="Включить системный прокси", fg_color=["#3B8ED0", "#1F6AA5"], hover_color=["#36719F", "#144870"])

def paste_and_add():
    try:
        clip = root.clipboard_get()
        entry.delete(0, 'end')
        entry.insert(0, clip)
        add_from_url()
    except: pass

def add_from_url(is_refresh=False):
    global base64_urls, active_profile, auto_update_interval, last_update_timestamp
    input_text = entry.get().strip()
    if not input_text: 
        log_message("Поле ввода пусто", "#F39C12")
        return

    was_running = (xray_process is not None and xray_process.poll() is None)
    saved_tag = active_tag

    # Проверяем, существовал ли ранее Автоконфиг в текущем профиле
    had_balancer = os.path.exists(os.path.join(CONFIGS_DIR, f"{AUTO_CONFIG_TAG}.json"))

    SUPPORTED_SCHEMES = ("vless://", "hy2://", "hysteria2://")
    if any(input_text.startswith(s) for s in SUPPORTED_SCHEMES):
        stop_xray()
        stop_system_proxy()
        lines = [l.strip() for l in input_text.splitlines() if any(l.strip().startswith(s) for s in SUPPORTED_SCHEMES)]
        added = 0
        for line in lines:
            try:
                data = parse_node_url(line)
                if not data: continue
                tag = data["tag"]
                configs[tag] = data
                ctype = get_config_type(data)
                config_list.insert(tag, ctype)
                with open(os.path.join(CONFIGS_DIR, f"{tag}.json"), "w", encoding="utf-8") as f:
                    f.write(generate_config(data))
                added += 1
            except: pass

        # Если Автоконфиг уже существовал в профиле, пересобираем его
        balancer_rebuilt = False
        g_count = 0
        if had_balancer and added > 1:
            balancer_rebuilt, g_count = generate_balancer_config()

        if added > 0 and not is_refresh:
            g_str = f", G-нод: {g_count}" if g_count > 0 else ""
            balancer_info = f" + Автоконфиг пересобран{g_str}" if balancer_rebuilt else ""
            log_message(f"Добавлено конфигов в профиль: {added}{balancer_info}", "#2ECC71")
        return

    if input_text.startswith("http"):
        try:
            if not is_refresh:
                log_message("Загрузка подписки...")
            
            r = requests.get(input_text, headers={'User-Agent': f'{APP_NAME}/{APP_VERS}'}, timeout=15)
            r.raise_for_status()

            interval_hdr = r.headers.get('profile-update-interval')
            if interval_hdr:
                match = re.search(r'\d+', str(interval_hdr))
                auto_update_interval = int(match.group(0)) if match else 0
            else:
                auto_update_interval = 0

            last_update_timestamp = time.time()

            if not is_refresh:
                prof_name = None
                title_header = r.headers.get('profile-title')
                if title_header:
                    if title_header.startswith('base64:'):
                        try:
                            prof_name = safe_b64decode(title_header.split('base64:')[1])
                        except: pass
                    else:
                        prof_name = title_header
                
                if not prof_name:
                    prof_name = urllib.parse.urlparse(input_text).netloc
                
                prof_name = sanitize_filename(prof_name)
                if not prof_name: prof_name = "Subscription"

                base_prof_name = prof_name
                counter = 2
                while True:
                    prof_dir = os.path.join(PROFILES_DIR, prof_name)
                    links_file = os.path.join(prof_dir, "links.json")
                    if os.path.exists(prof_dir):
                        if os.path.exists(links_file):
                            try:
                                with open(links_file, "r", encoding="utf-8") as lf:
                                    existing_links = json.load(lf)
                                    if existing_links and existing_links[0] == input_text:
                                        break
                            except: pass
                        prof_name = f"{base_prof_name} ({counter})"
                        counter += 1
                    else:
                        break

                if prof_name != active_profile:
                    stop_xray()
                    stop_system_proxy()
                    profs = get_profiles()
                    if prof_name not in profs:
                        profs.append(prof_name)
                        profile_dropdown.configure(values=profs)
                    setup_active_profile(prof_name)
                    profile_var.set(prof_name)

            stop_xray()
            stop_system_proxy()

            # Проверяем наличие балансировщика в целевом профиле перед очисткой
            had_balancer = os.path.exists(os.path.join(CONFIGS_DIR, f"{AUTO_CONFIG_TAG}.json"))

            clear_xray_configs()
            base64_urls = [input_text]
            save_base64_urls()

            added = 0
            try:
                decoded = safe_b64decode(r.text)
                lines = [l.strip() for l in decoded.splitlines() if any(l.startswith(s) for s in SUPPORTED_SCHEMES)]
                for line in lines:
                    try:
                        data = parse_node_url(line)
                        if not data: continue
                        tag = data["tag"]
                        configs[tag] = data
                        ctype = get_config_type(data)
                        config_list.insert(tag, ctype)
                        with open(os.path.join(CONFIGS_DIR, f"{tag}.json"), "w", encoding="utf-8") as f:
                            f.write(generate_config(data))
                        added += 1
                    except: pass
            except:
                clean_content = re.sub(r'<[^>]+>', '', r.text).strip()
                try:
                    loaded_data = json.loads(clean_content)
                    items = loaded_data if isinstance(loaded_data, list) else [loaded_data]
                    for config_data in items:
                        if config_data.get("protocol") == "shadowsocks":
                            continue
                        outbounds = config_data.get("outbounds", [])
                        if outbounds and outbounds[0].get("protocol") == "shadowsocks":
                            continue

                        tag = sanitize_filename(unquote(config_data.get("remarks", config_data.get("tag", f"import_{added}"))))
                        configs[tag] = config_data
                        ctype = get_config_type(config_data)
                        config_list.insert(tag, ctype)
                        with open(os.path.join(CONFIGS_DIR, f"{tag}.json"), "w", encoding="utf-8") as cf:
                            json.dump(config_data, cf, indent=2, ensure_ascii=False)
                        added += 1
                except:
                    if not is_refresh: 
                        log_message("Не удалось распарсить подписку", "#E74C3C")
                    else:
                        log_message("Сбой парсинга подписки", "#E74C3C")
                    return

            # Если ранее в этом профиле был создан балансировщик, автоматически пересобираем его
            balancer_rebuilt = False
            g_count = 0
            if had_balancer and added > 1:
                balancer_rebuilt, g_count = generate_balancer_config()

            save_state()

            if was_running and saved_tag and saved_tag in configs:
                config_list.select(saved_tag)
                run_selected()

            interval_info = f", автообновление: {auto_update_interval}ч" if auto_update_interval > 0 else ""
            g_str = f", G-нод: {g_count}" if g_count > 0 else ""
            balancer_info = f" + Автоконфиг пересобран{g_str}" if balancer_rebuilt else ""
            log_message(f"Подписка обновлена ({added} серверов{balancer_info}{interval_info})", "#2ECC71")

        except Exception as e:
            last_update_timestamp = time.time()
            save_state()

            retry_text = f", повтор через {auto_update_interval}ч" if auto_update_interval > 0 else ""
            if is_refresh:
                log_message(f"Сервер подписки недоступен{retry_text}", "#F39C12")
            else:
                log_message(f"Ошибка загрузки подписки: {e}", "#E74C3C")
        return

    if not is_refresh: 
        log_message("Неверный формат ссылки", "#E74C3C")

def update_all_subscriptions():
    if not base64_urls:
        log_message("Нет подписок для обновления в этом профиле", "#F39C12")
        return
    url = base64_urls[0]
    entry.delete(0, 'end')
    entry.insert(0, url)
    add_from_url(is_refresh=True)

# Фоновая проверка наступления времени автообновления
def check_auto_update():
    global auto_update_interval, last_update_timestamp
    try:
        if auto_update_interval > 0 and base64_urls:
            interval_seconds = auto_update_interval * 3600
            now = time.time()
            if now - last_update_timestamp >= interval_seconds:
                log_message(f"Автообновление подписки по расписанию ({auto_update_interval}ч)...")
                update_all_subscriptions()
    except Exception:
        pass
    finally:
        root.after(60000, check_auto_update)

def run_selected():
    global xray_process
    
    tag = config_list.selected_tag
    if not tag: 
        log_message("Конфиг не выбран", "#F39C12")
        return

    if xray_process and xray_process.poll() is None:
        is_same_config = (active_tag == tag)
        stop_xray()
        if is_same_config:
            return

    config_path = os.path.join(CONFIGS_DIR, f"{tag}.json")
    if not os.path.exists(XRAY_EXE):
        log_message("Файл xray.exe не найден", "#E74C3C")
        return

    try:
        xray_process = subprocess.Popen([XRAY_EXE, "-config", config_path], creationflags=CREATE_NO_WINDOW)
        highlight_active(tag)
        btn_run.configure(text="Остановить конфиг", fg_color="#27AE60", hover_color="#2ECC71")
        log_message(f"Запущен конфиг: {tag}", "#2ECC71")
    except Exception as e:
        log_message(f"Не удалось запустить Xray: {e}", "#E74C3C")

def stop_xray(is_quitting=False):
    global xray_process
    if xray_process and xray_process.poll() is None:
        try:
            xray_process.terminate()
            xray_process.wait()
        except: pass
    xray_process = None
    
    if not is_quitting:
        clear_highlight()  
        btn_run.configure(text="Запустить конфиг", fg_color=["#3B8ED0", "#1F6AA5"], hover_color=["#36719F", "#144870"])
        log_message("Конфиг остановлен")

# --- Управление профилями ---
def switch_profile(new_profile):
    global active_profile
    if new_profile == active_profile: return
    stop_xray()
    stop_system_proxy()
    setup_active_profile(new_profile)
    load_base64_urls()
    load_state(is_initial=False)
    log_message(f"Профиль изменен: {new_profile}")

def add_new_profile():
    dialog = ctk.CTkInputDialog(text="Имя нового профиля:", title="Создать профиль")
    name = dialog.get_input()
    if name:
        name = sanitize_filename(name.strip())
        if name:
            stop_xray()
            stop_system_proxy()
            setup_active_profile(name)
            profs = get_profiles()
            profile_dropdown.configure(values=profs)
            profile_var.set(name)
            load_base64_urls()
            load_state(is_initial=False)
            log_message(f"Создан профиль: {name}", "#2ECC71")

def delete_current_profile():
    if len(get_profiles()) <= 1:
        log_message("Нельзя удалить единственный профиль", "#F39C12")
        return
    deleted_name = active_profile
    stop_xray()
    stop_system_proxy()
    try: shutil.rmtree(CONFIGS_DIR)
    except: pass
    profs = get_profiles()
    if not profs: profs = ["Default"]
    new_prof = profs[0]
    profile_dropdown.configure(values=profs)
    profile_var.set(new_prof)
    setup_active_profile(new_prof)
    load_base64_urls()
    load_state(is_initial=False)
    log_message(f"Профиль '{deleted_name}' удален", "#F39C12")

# --- Проверка пинга всех серверов без переключения ---
def on_ping_all_click():
    tags = config_list.get_all_tags()
    if not tags: 
        log_message("Список серверов пуст", "#F39C12")
        return
    btn_ping_all.configure(state="disabled", text="Замер...")
    log_message("Замер задержки серверов (TLS/HTTP)...")

    def ping_all_task():
        def check_tag(t):
            # Если это активный запущенный конфиг — шлем через туннель к генератору 204
            if xray_process and xray_process.poll() is None and active_tag == t:
                ms, _ = real_proxy_ping(timeout=4.0)
                return t, ms
            config_path = os.path.join(CONFIGS_DIR, f"{t}.json")
            host, port, sni = get_server_endpoint_from_config(config_path)
            if host and port:
                ms, _ = smart_ping(host, port, sni, timeout=3.5)
                return t, ms
            return t, -1

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            results = list(executor.map(check_tag, tags))

        valid_results = [r for r in results if r[1] >= 0]

        def update_ui():
            for original_tag in tags:
                ms = next((r[1] for r in results if r[0] == original_tag), -1)
                res_str = f"{ms} ms" if ms >= 0 else "Ошибка"
                config_list.update_ping(original_tag, res_str)

            btn_ping_all.configure(state="normal", text="Пинг")
            log_message(f"Проверка завершена. Доступно: {len(valid_results)} из {len(tags)}", "#2ECC71" if valid_results else "#E74C3C")

            # Отображаем цифры пинга 15 секунд для комфортного ознакомления
            root.after(15000, lambda: [config_list.update_ping(t, "") for t in tags])

        root.after(0, update_ui)
    threading.Thread(target=ping_all_task, daemon=True).start()

# --- Контекстное меню ---
def on_context_ping_click():
    tag = config_list.selected_tag
    if not tag: return

    is_running_now = (xray_process and xray_process.poll() is None and active_tag == tag)
    
    def ping_task():
        if is_running_now:
            ms, status = real_proxy_ping(timeout=4.0)
            res_str = f"{ms} ms" if ms >= 0 else status
            check_type = "Туннель SOCKS5"
        else:
            config_path = os.path.join(CONFIGS_DIR, f"{tag}.json")
            host, port, sni = get_server_endpoint_from_config(config_path)
            if host and port:
                ms, status = smart_ping(host, port, sni, timeout=3.5)
                res_str = f"{ms} ms" if ms >= 0 else status
                check_type = "TLS + HTTP Handshake" if sni else "TCP пинг"
            else:
                res_str = "No Host"
                check_type = "Ошибка"

        def update_ui():
            config_list.update_ping(tag, res_str)
            log_message(f"[{check_type}] {tag}: {res_str}")
            # Держим результат пинга 15 секунд
            root.after(15000, lambda: config_list.update_ping(tag, ""))
        root.after(0, update_ui)
        
    threading.Thread(target=ping_task, daemon=True).start()

def on_context_delete_config():
    tag = config_list.selected_tag
    if not tag: return
    if active_tag == tag:
        stop_xray()
        stop_system_proxy()
    try: os.remove(os.path.join(CONFIGS_DIR, f"{tag}.json"))
    except: pass
    config_list.delete(tag)
    if tag in configs: del configs[tag]
    log_message(f"Конфиг '{tag}' удален", "#F39C12")

def show_context_menu(event, tag):
    context_menu.tk_popup(event.x_root, event.y_root)

def parse_version(v_str):
    """Преобразует строку версии вида 'v1.20-beta' в кортеж чисел (1, 20) для корректного сравнения"""
    nums = re.findall(r'\d+', str(v_str))
    return tuple(map(int, nums)) if nums else (0,)

def download_and_install_update(download_url, new_version):
    """Фоновое скачивание и безопасный перезапуск для PyInstaller --onefile"""
    def _worker():
        try:
            current_exe = get_executable_path()
            
            if not getattr(sys, 'frozen', False):
                log_message(f"Обновление {new_version} доступно (в режиме .py автозамена отключена)", "#F39C12")
                return

            log_message(f"Скачивание обновления {new_version}...", "#3498DB")
            temp_exe = current_exe + ".new"

            with requests.get(download_url, stream=True, timeout=30) as r:
                r.raise_for_status()
                with open(temp_exe, 'wb') as f:
                    for chunk in r.iter_content(chunk_size=65536):
                        if chunk:
                            f.write(chunk)

            log_message("Установка и перезапуск...", "#2ECC71")
            time.sleep(0.5)

            clean_env = os.environ.copy()
            for key in list(clean_env.keys()):
                if key.startswith(("_PYI", "_MEI")):
                    clean_env.pop(key, None)
            
            clean_env["PYINSTALLER_RESET_ENVIRONMENT"] = "1"

            cmd = (
                f'set PYINSTALLER_RESET_ENVIRONMENT=1 & '
                f'ping 127.0.0.1 -n 3 > nul & '
                f'move /y "{temp_exe}" "{current_exe}" & '
                f'start "" "{current_exe}"'
            )

            subprocess.Popen(
                cmd,
                shell=True,
                env=clean_env,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
            )

            root.after(100, actual_quit)

        except Exception as e:
            log_message(f"Ошибка обновления: {e}", "#E74C3C")
            temp_exe = get_executable_path() + ".new"
            if os.path.exists(temp_exe):
                try: os.remove(temp_exe)
                except: pass

    threading.Thread(target=_worker, daemon=True).start()

# --- Доп функции (Update, Autostart) ---
def check_latest_version():
    def _check():
        try:
            url = "https://api.github.com/repos/xVRVx/winLoadXRAY/releases/latest"
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            release_data = response.json()
            
            latest_version = release_data.get("tag_name", "")
            if not latest_version:
                return

            if parse_version(latest_version) > parse_version(APP_VERS):
                is_win7 = False
                if sys.platform == "win32":
                    try:
                        is_win7 = sys.getwindowsversion().major < 10
                    except Exception:
                        pass

                current_exe_name = os.path.basename(get_executable_path()).lower()
                if "win7" in current_exe_name:
                    is_win7 = True

                download_url = None
                fallback_url = None

                for asset in release_data.get("assets", []):
                    name = asset.get("name", "").lower()
                    if not name.endswith(".exe"):
                        continue

                    if not fallback_url:
                        fallback_url = asset.get("browser_download_url")

                    if is_win7 and "win7" in name:
                        download_url = asset.get("browser_download_url")
                        break
                    elif not is_win7 and "win7" not in name:
                        download_url = asset.get("browser_download_url")
                        break

                download_url = download_url or fallback_url
                if not download_url:
                    return

                def _show_ui():
                    btn_update = ctk.CTkButton(
                        frame_links,
                        text=f"Обновить до {latest_version}",
                        fg_color="#F39C12",
                        hover_color="#D68910",
                        text_color="white",
                        height=22,
                        font=("Arial", 11, "bold"),
                        command=lambda: download_and_install_update(download_url, latest_version)
                    )
                    btn_update.pack(side="right", padx=5)
                    ToolTip(btn_update, f"Нажмите для автоматического обновления на версию {latest_version}")

                root.after(0, _show_ui)

        except Exception:
            pass

    threading.Thread(target=_check, daemon=True).start()

def highlight_active(tag):
    global active_tag
    active_tag = tag
    save_state()
    config_list.update_colors()

def clear_highlight():
    global active_tag
    active_tag = None
    save_state()
    config_list.update_colors()

# --- Всплывающие подсказки ---
class ToolTip:
    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tipwindow = None
        self.widget.bind("<Enter>", self.show_tip)
        self.widget.bind("<Leave>", self.hide_tip)

    def show_tip(self, event=None):
        if self.tipwindow: return
        content = self.text() if callable(self.text) else self.text
        if not content: return

        self.tipwindow = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True) 
        label = tk.Label(tw, text=content, background="#ffffe0", relief="solid", borderwidth=1, font=("Segoe UI", 10, "normal"), justify="left")
        label.pack(ipadx=8, ipady=6)

        tw.update_idletasks()
        tip_w = tw.winfo_reqwidth()
        screen_w = tw.winfo_screenwidth()

        x = self.widget.winfo_rootx() + 20
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 5

        if x + tip_w > screen_w - 10:
            x = screen_w - tip_w - 10
        if x < 10:
            x = 10

        tw.wm_geometry(f"+{x}+{y}")

    def hide_tip(self, event=None):
        if self.tipwindow:
            self.tipwindow.destroy()
            self.tipwindow = None

def resource_path(relative_path):
    if hasattr(sys, '_MEIPASS'): return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), relative_path)
    
XRAY_EXE = resource_path("xray/xray.exe")
CREATE_NO_WINDOW = 0x08000000

def get_executable_path():
    return sys.executable if getattr(sys, 'frozen', False) else os.path.abspath(__file__)

def open_exe_folder():
    """Открывает папку расположения исполняемого файла в Проводнике Windows"""
    try:
        exe_dir = os.path.dirname(os.path.abspath(get_executable_path()))
        if os.path.exists(exe_dir):
            os.startfile(exe_dir)
    except Exception as e:
        log_message(f"Не удалось открыть папку: {e}", "#E74C3C")

def get_path_tooltip():
    """Формирует текст подсказки: только путь к программе (без инфы о конфигах)"""
    exe_path = get_executable_path()
    return f"Исполняемый файл:\n{exe_path}\n\n(Нажмите, чтобы открыть папку с программой)"

def is_in_startup(app_name=APP_NAME):
    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            0, winreg.KEY_READ
        ) as key:
            value, _ = winreg.QueryValueEx(key, app_name)
        exe_path = get_executable_path().lower()
        return exe_path in value.lower()
    except Exception:
        return False

def add_to_startup(app_name=APP_NAME, path=None):
    if path is None:
        path = get_executable_path()
    path = f'"{path}" --autostart'
    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            0, winreg.KEY_ALL_ACCESS
        )
        winreg.SetValueEx(key, app_name, 0, winreg.REG_SZ, path)
        winreg.CloseKey(key)
        log_message("Автозапуск включен", "#2ECC71")
    except Exception as e:
        log_message(f"Ошибка автозапуска: {e}", "#E74C3C")

def remove_from_startup(app_name=APP_NAME):
    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            0, winreg.KEY_ALL_ACCESS
        )
        winreg.DeleteValue(key, app_name)
        winreg.CloseKey(key)
        log_message("Автозапуск выключен")
    except FileNotFoundError:
        pass
    except Exception as e:
        log_message(f"Ошибка удаления автозапуска: {e}", "#E74C3C")

def toggle_startup():
    if startup_var.get():
        add_to_startup()
    else:
        remove_from_startup()

def open_link(event): webbrowser.open_new("https://t.me/SkyBridge_VPN_bot")
def github(event): webbrowser.open_new("https://github.com/xVRVx/winLoadXRAY/")

# --- Обработка ссылки (Протокол Реестра) ---
def register_url_protocol():
    if sys.platform != "win32": return
    try:
        exe_path = get_executable_path()
        if exe_path.endswith('.py'):
            command = f'"{sys.executable}" "{exe_path}" "%1"'
        else:
            command = f'"{exe_path}" "%1"'

        key_path = r"Software\Classes\winloadxray"
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key_path) as key:
            winreg.SetValueEx(key, "", 0, winreg.REG_SZ, "URL:winLoadXRAY Protocol")
            winreg.SetValueEx(key, "URL Protocol", 0, winreg.REG_SZ, "")

        cmd_path = key_path + r"\shell\open\command"
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, cmd_path) as key:
            winreg.SetValueEx(key, "", 0, winreg.REG_SZ, command)
    except Exception:
        pass

def _restore_window():
    root.deiconify()
    root.wm_state('normal')
    root.attributes('-topmost', True)
    root.attributes('-topmost', False)
    root.focus_force()

def process_incoming_url(url):
    try:
        _restore_window()
    except: pass
    
    if url and url != "WAKEUP":
        entry.delete(0, 'end')
        entry.insert(0, url)
        add_from_url()

def start_ipc_server():
    def _server():
        try:
            server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server.bind(("127.0.0.1", IPC_PORT))
            server.listen()
            while True:
                conn, addr = server.accept()
                data = conn.recv(4096)
                if data:
                    url = data.decode('utf-8').strip()
                    if url:
                        root.after(0, lambda u=url: process_incoming_url(u))
        except Exception:
            pass
    threading.Thread(target=_server, daemon=True).start()

# ==========================================
# ====== НАСТРОЙКА ЦВЕТОВ ПРОГРАММЫ ========
# ==========================================
MAIN_BG_COLOR = "#102236"  # Основной цвет программы (темно-синий)
LIST_BG_COLOR = "#1a1a1a"  # Цвет поля со списком конфигов (темный/графит)
# ==========================================

class ConfigList(ctk.CTkScrollableFrame):
    def __init__(self, master, command=None, right_click_command=None, **kwargs):
        super().__init__(master, **kwargs)
        self.command = command
        self.right_click_command = right_click_command
        self.rows = {}
        self.selected_tag = None
        self.emoji_font = ctk.CTkFont(family="Segoe UI Emoji", size=16)

    def insert(self, tag, config_type="XRAY", at_top=False):
        if tag in self.rows:
            self.delete(tag)
        
        row_frame = ctk.CTkFrame(self, fg_color="transparent", corner_radius=0, border_width=0)
        
        flag, name = split_flag(tag)
        
        lbl_flag = ctk.CTkLabel(row_frame, text=flag, width=30, font=self.emoji_font, anchor="center", text_color="white")
        lbl_flag.pack(side="left", padx=(5,0))
        
        lbl_name = ctk.CTkLabel(row_frame, text=name, anchor="w", text_color="white")
        lbl_name.pack(side="left", fill="x", expand=True, padx=5)
        
        # --- Правый блок ---
        lbl_ping = ctk.CTkLabel(row_frame, text="", width=65, anchor="e", text_color="white")
        lbl_ping.pack(side="right", padx=(0,10))
        
        lbl_type = ctk.CTkLabel(row_frame, text=config_type, width=105, anchor="w", text_color="gray")
        lbl_type.pack(side="right", padx=(5, 5))
        
        for w in (row_frame, lbl_flag, lbl_name, lbl_ping, lbl_type):
            w.bind("<Button-1>", lambda e, t=tag: self.select(t))
            w.bind("<Button-3>", lambda e, t=tag: self.right_click(e, t))
            w.bind("<Double-Button-1>", lambda e, t=tag: self.double_click(t))
            w.configure(cursor="hand2")

        row_dict = {
            "frame": row_frame,
            "lbl_name": lbl_name,
            "lbl_ping": lbl_ping,
            "lbl_type": lbl_type,
            "lbl_flag": lbl_flag
        }

        if at_top and self.rows:
            first_frame = next(iter(self.rows.values()))["frame"]
            row_frame.pack(fill="x", padx=2, pady=1, before=first_frame)
            self.rows = {tag: row_dict, **self.rows}
        else:
            row_frame.pack(fill="x", padx=2, pady=1)
            self.rows[tag] = row_dict

    def update_colors(self):
        for t, widgets in self.rows.items():
            if t == active_tag:
                bg_color = "#2ECC71"
                widgets["frame"].configure(fg_color=bg_color)
                widgets["lbl_name"].configure(text_color="black", fg_color=bg_color)
                widgets["lbl_ping"].configure(text_color="black", fg_color=bg_color)
                widgets["lbl_type"].configure(text_color="#1E5631", fg_color=bg_color) 
                widgets["lbl_flag"].configure(text_color="black", fg_color=bg_color)
            elif t == self.selected_tag:
                bg_color = "#3498DB"
                widgets["frame"].configure(fg_color=bg_color)
                widgets["lbl_name"].configure(text_color="white", fg_color=bg_color)
                widgets["lbl_ping"].configure(text_color="white", fg_color=bg_color)
                widgets["lbl_type"].configure(text_color="#D5D8DC", fg_color=bg_color) 
                widgets["lbl_flag"].configure(text_color="white", fg_color=bg_color)
            else:
                widgets["frame"].configure(fg_color="transparent")
                widgets["lbl_name"].configure(text_color=["white", "gray90"], fg_color="transparent")
                widgets["lbl_ping"].configure(text_color=["white", "gray90"], fg_color="transparent")
                widgets["lbl_type"].configure(text_color="gray", fg_color="transparent")
                widgets["lbl_flag"].configure(text_color=["white", "gray90"], fg_color="transparent")

    def update_ping(self, tag, ping_text):
        if tag in self.rows:
            self.rows[tag]["lbl_ping"].configure(text=ping_text)

    def delete(self, tag):
        if tag in self.rows:
            self.rows[tag]["frame"].destroy()
            del self.rows[tag]
            if self.selected_tag == tag: self.selected_tag = None

    def clear(self):
        for w in self.rows.values(): w["frame"].destroy()
        self.rows.clear()
        self.selected_tag = None

    def select(self, tag):
        self.selected_tag = tag
        self.update_colors()
        if self.command: self.command(tag)

    def right_click(self, event, tag):
        self.select(tag)
        if self.right_click_command: self.right_click_command(event, tag)

    def double_click(self, tag):
        self.select(tag)
        run_selected()

    def get_all_tags(self): return list(self.rows.keys())

# --- Построение основного окна GUI ---
root = ctk.CTk()
root.title(f"{APP_NAME} {APP_VERS} {XRAY_VERS}")
root.geometry("500x480") 
root.minsize(500, 480)
root.iconbitmap(resource_path("img/icon.ico"))

root.configure(fg_color=MAIN_BG_COLOR)

def keypress(e):
    if e.keycode == 86: paste_and_add() # Ctrl+V
    elif e.keycode == 67: cmd_copy(root)
    elif e.keycode == 88: cmd_cut(root)
    elif e.keycode == 65: cmd_select_all(root)
root.bind("<Control-KeyPress>", keypress)
root.bind('<Return>', lambda e: add_from_url() if entry == root.focus_get() else run_selected())

bg_frame = ctk.CTkFrame(root, fg_color="transparent")
bg_frame.pack(fill="both", expand=True)

content_frame = ctk.CTkFrame(bg_frame, fg_color="transparent")
content_frame.pack(fill="both", expand=True, padx=15, pady=15)

# Меню профилей
frame_prof = ctk.CTkFrame(content_frame, fg_color="transparent")
frame_prof.pack(fill="x", pady=(0, 10))
ctk.CTkLabel(frame_prof, text="Профиль:", text_color="white").pack(side="left", padx=(0,5))
profile_var = ctk.StringVar(value="Default")
profile_dropdown = ctk.CTkOptionMenu(frame_prof, variable=profile_var, command=switch_profile)
profile_dropdown.pack(side="left", fill="x", expand=True, padx=(0, 5))
ctk.CTkButton(frame_prof, text="+", width=30, command=add_new_profile).pack(side="left", padx=(0, 5))
ctk.CTkButton(frame_prof, text="-", width=30, fg_color="#E74C3C", hover_color="#C0392B", command=delete_current_profile).pack(side="left")

# Строка ввода
frame_entry = ctk.CTkFrame(content_frame, fg_color="transparent")
frame_entry.pack(fill="x", pady=(0, 10))
entry = ctk.CTkEntry(frame_entry, placeholder_text="URL подписки, vless или hy2 конфиг...")
entry.pack(side="left", fill="x", expand=True, padx=(0, 5))
ToolTip(entry, "Вставьте сюда URL подписки или конфиг (vless://, hy2://)")

img_paste = ctk.CTkImage(Image.open(resource_path("img/ref.png")), size=(20, 20))
btn_paste = ctk.CTkButton(frame_entry, image=img_paste, text="", width=30, command=paste_and_add)
btn_paste.pack(side="left", padx=(0, 5))
ToolTip(btn_paste, "Вставить из буфера обмена")

img_update = ctk.CTkImage(Image.open(resource_path("img/ico.png")), size=(20, 20))
btn_refresh = ctk.CTkButton(frame_entry, image=img_update, text="", width=30, command=update_all_subscriptions)
btn_refresh.pack(side="left")
ToolTip(btn_refresh, "Обновить подписку")

# Список конфигов
context_menu = tk.Menu(root, tearoff=0, bg="#2b2b2b", fg="white", activebackground="#3498db")
context_menu.add_command(label="Проверить пинг", command=on_context_ping_click)
context_menu.add_command(label="Удалить конфиг", command=on_context_delete_config)

config_list = ConfigList(content_frame, fg_color=LIST_BG_COLOR, right_click_command=show_context_menu, width=400, height=150)
config_list.pack(fill="both", expand=True, pady=(0, 5))

# Кнопки управления (Строка 1)
frame_btns1 = ctk.CTkFrame(content_frame, fg_color="transparent")
frame_btns1.pack(fill="x", pady=(15, 10))
btn_run = ctk.CTkButton(frame_btns1, text="Запустить конфиг", command=run_selected)
btn_run.pack(side="left", fill="x", expand=True, padx=(0, 5))
ToolTip(btn_run, "socks5 на 2080 порту")

btn_proxy = ctk.CTkButton(frame_btns1, text="Включить системный прокси", command=toggle_system_proxy)
btn_proxy.pack(side="right", fill="x", expand=True)
ToolTip(btn_proxy, "Запустите конфиг и выключите другие прокси расширения.\nРаботает только для браузеров.")

# Кнопки управления (Строка 2)
frame_btns2 = ctk.CTkFrame(content_frame, fg_color="transparent")
frame_btns2.pack(fill="x", pady=(5, 5))
startup_var = ctk.BooleanVar(value=is_in_startup())
ctk.CTkCheckBox(frame_btns2, text="Автозапуск", variable=startup_var, command=toggle_startup, text_color="white").pack(side="left")

btn_ping_all = ctk.CTkButton(frame_btns2, text="Пинг", width=85, command=on_ping_all_click)
btn_ping_all.pack(side="left", padx=(10, 5))
ToolTip(btn_ping_all, "Проверить реальную задержку всех серверов без переключения")

btn_make_balancer = ctk.CTkButton(frame_btns2, text="Балансир", width=85, command=on_manual_balancer_click)
btn_make_balancer.pack(side="left", padx=(0, 5))
ToolTip(btn_make_balancer, "Создать/обновить Автоконфиг с балансировкой leastPing и Gemini-роутингом")

# Знак вопроса в пустой части строки
btn_info = ctk.CTkButton(
    frame_btns2,
    text="?",
    width=26,
    height=26,
    corner_radius=13,
    fg_color="#2c3e50",
    hover_color="#34495e",
    text_color="#ecf0f1",
    font=("Arial", 12, "bold"),
    command=open_exe_folder
)
btn_info.pack(side="right")
ToolTip(btn_info, get_path_tooltip)

# --- СТРОКА СТАТУСА / ЛОГОВ ---
lbl_status = ctk.CTkLabel(content_frame, text="• Программа готова к работе", anchor="w", text_color="#BDC3C7", font=("Arial", 11))
lbl_status.pack(fill="x", pady=(6, 2))

# Ссылки 
frame_links = ctk.CTkFrame(content_frame, fg_color="transparent")
frame_links.pack(fill="x", pady=(5, 0))
lbl_tg = ctk.CTkLabel(frame_links, text="Наш Telegram бот", cursor="hand2", text_color="#3498db")
lbl_tg.pack(side="left", padx=(0, 10))
lbl_tg.bind("<Button-1>", open_link)
lbl_gh = ctk.CTkLabel(frame_links, text="GitHub", cursor="hand2", text_color="#3498db")
lbl_gh.pack(side="left")
lbl_gh.bind("<Button-1>", github)

# ==========================================
# ===== ЛОГИКА СИСТЕМНОГО ТРЕЯ И ВЫХОДА ====
# ==========================================

def actual_quit():
    stop_xray(is_quitting=True)
    stop_system_proxy(is_quitting=True)
    root.destroy()
    os._exit(0)

def on_closing():
    if HAS_TRAY:
        root.withdraw()
    else:
        actual_quit()

def show_window_from_tray(icon=None, item=None):
    root.after(0, _restore_window)

def quit_from_tray(icon=None, item=None):
    if icon:
        icon.stop()
    root.after(0, actual_quit)

if HAS_TRAY:
    def setup_tray():
        try:
            image = Image.open(resource_path("img/icon.ico"))
            menu = pystray.Menu(
                tray_item('Развернуть', show_window_from_tray, default=True),
                tray_item('Выход', quit_from_tray)
            )
            tray_icon = pystray.Icon("winLoadXRAY", image, "winLoadXRAY", menu)
            threading.Thread(target=tray_icon.run, daemon=True).start()
        except:
            pass
    setup_tray()

try:
    import win32api
    import win32con

    def _windows_shutdown_handler(ctrl_type):
        if ctrl_type in (win32con.CTRL_SHUTDOWN_EVENT, win32con.CTRL_LOGOFF_EVENT):
            actual_quit() 
            return True
        return False

    win32api.SetConsoleCtrlHandler(_windows_shutdown_handler, True)
except ImportError:
    pass 

# --- Инициализация перед запуском ---
register_url_protocol()
start_ipc_server()

# Запуск
load_initial_profile()
profile_var.set(active_profile)
profile_dropdown.configure(values=get_profiles())
load_base64_urls()
load_state(is_initial=True)

if startup_url:
    root.after(200, lambda: process_incoming_url(startup_url))

if IS_AUTOSTART:
    if HAS_TRAY:
        root.withdraw()
    else:
        root.iconify()

root.after(3000, check_latest_version)

# Запуск таймера проверки автообновления подписки
root.after(10000, check_auto_update)

root.protocol("WM_DELETE_WINDOW", on_closing)
root.mainloop()