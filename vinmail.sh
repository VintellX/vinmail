#!/bin/bash
# VinMail v0.3.0
# "Bash-ing out an email."

set -uo pipefail

VINMAIL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vinmail"
ACCOUNTS_DIR="$VINMAIL_DIR/accounts"
META_FILE="$VINMAIL_DIR/accounts.list"   # alias|email|encrypted(0|1)
ACTIVE_FILE="$VINMAIL_DIR/.active"
MSMTPRC="$HOME/.msmtprc"
TEMPLATE_DIR="/usr/share/vinmail"
LOCK_FILE="$VINMAIL_DIR/.lock"
LOCK_DIR="$VINMAIL_DIR/.lockdir"
VERSION="0.3.0"
SUBTITLE="Bash-ing out an email; Don’t let email be a pain in the inbox."

# ----- Color Codos -----
if [[ -t 1 ]]; then
    RED="\033[31m";     GREEN="\033[32m"
    YELLOW="\033[33m";  CYAN="\033[36m"
    BOLD="\033[1m";     DIM="\033[2m"; RESET="\033[0m"
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""
    BOLD=""; DIM=""; RESET=""
fi

WHOAMI=$(id -un)
GREETING=""
EDITOR="${VISUAL:-${EDITOR:-vim}}"
ALIASES=(); EMAILS=(); ENCRYPTED=()

# ----- Cleanup -----
cleanup() {
    tput cnorm 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true
    rm -rf "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

acquireLock() {
    if command -v flock &>/dev/null; then
        exec 9>"$LOCK_FILE"
        flock -n 9 || {
            echo -e "${RED}Already running.${RESET}" >&2
            exit 1
        }
    else
        mkdir "$LOCK_DIR" 2>/dev/null || {
            echo -e "${RED}Already running.${RESET}" >&2
            exit 1
        }
    fi
}

# ----- Helpahh Funcs -----
err() { echo -e "${RED}  ✗ $*${RESET}" >&2; }
ok() { echo -e "${GREEN}  ✓ $*${RESET}"; }
warn() { echo -e "${YELLOW}  ! $*${RESET}"; }
info() { echo -e "${DIM}  $*${RESET}"; }
pressAnyKey() { echo -ne "\n  ${DIM}Press any key...${RESET}"; read -rsn1; }

# ----- Init -----
init() {
    mkdir -p "$ACCOUNTS_DIR"
    [[ ! -f "$META_FILE"   ]] && touch "$META_FILE"
    [[ ! -f "$ACTIVE_FILE" ]] && touch "$ACTIVE_FILE"
    if [[ ! -f "$HOME/.mailrc" && -f "$TEMPLATE_DIR/mailrc" ]]; then
        cp "$TEMPLATE_DIR/mailrc" "$HOME/.mailrc"
    fi
    local greetings=("Namaste (नमस्ते)" "Konnichiwa (こんにちは)" "¡Hola" "Hello" "Bonjour" "Salut" "Ciao" "NiHao (你好)" "Privet (Привет)")
    GREETING="${greetings[$(( RANDOM % ${#greetings[@]} ))]}"
}

# ----- TLS auto-detecto -----
detectTLSPhile() {
    local candidates=(
        /etc/ssl/certs/ca-certificates.crt
        /etc/pki/tls/certs/ca-bundle.crt
        /etc/ssl/ca-bundle.pem
    )
    for f in "${candidates[@]}"; do [[ -f "$f" ]] && echo "$f" && return; done
    echo "/etc/ssl/certs/ca-certificates.crt"
}

# ----- registry -----
fetchAccounts() {
    ALIASES=(); EMAILS=(); ENCRYPTED=()
    [[ ! -f "$META_FILE" ]] && return
    while IFS='|' read -r a e enc _; do
        [[ -z "$a" ]] && continue
        ALIASES+=("$a"); EMAILS+=("$e"); ENCRYPTED+=("${enc:-0}")
    done < "$META_FILE"
}

fetchActive() {
    local a=""
    [[ -f "$ACTIVE_FILE" ]] && a=$(cat "$ACTIVE_FILE") || a=""
    echo "${a//[$'\n\r ']/}"
}
updatoMeta() {
    local alias="$1" enc="$2"
    local email; email=$(grep "^${alias}|" "$META_FILE" | cut -d'|' -f2)
    local tmp; tmp=$(mktemp)
    grep -v "^${alias}|" "$META_FILE" > "$tmp" || true
    echo "${alias}|${email}|${enc}" >> "$tmp"
    mv "$tmp" "$META_FILE"
}

rmMeta() {
    local tmp; tmp=$(mktemp)
    grep -v "^${1}|" "$META_FILE" > "$tmp" || true
    mv "$tmp" "$META_FILE"
}

# ----- Validations TwT -----
validateAlias() {
    [[ -z "$1" ]]                  && { err "Alias cannot be empty.";    return 1; }
    [[ ! "$1" =~ ^[a-z0-9_-]+$ ]] && { err "Use only: a-z 0-9 - _";    return 1; }
    [[ ${#1} -gt 32 ]]            && { err "Alias too long (max 32).";   return 1; }
    return 0
}

validateMailo() {
    [[ -z "$1" ]]                         && { err "Email cannot be empty.";     return 1; }
    [[ ! "$1" =~ ^[^@]+@[^@]+\.[^@]+$ ]] && { err "Not a valid email address."; return 1; }
    [[ "$1" == *"|"* ]]                   && { err "Email cannot contain '|'.";  return 1; }
    return 0
}
validatePorto() {
    [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )) && return 0
    err "Port must be 1–65535."; return 1
}

# ----- Keyboard reader (arrows + j/k) -----
KEY=""
readKeyboardo() {
    local char seq
    IFS= read -rsn1 char
    if [[ "$char" == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.15 seq 2>/dev/null || seq=""
        case "$seq" in
            '[A') KEY="UP"   ;; '[B') KEY="DOWN" ;;
            '[C') KEY="RIGHT";; '[D') KEY="LEFT"  ;;
            *)    KEY="ESC"  ;;
        esac
    else
        KEY="$char"
    fi
}

# ----- Navigate -----
NAV_RESULT=-1
navigate() {
    local title="$1" hint="$2"
    local -n _items="$3"
    local taken="${4:-0}" render_fn="${5:-}"
    local count=${#_items[@]}
    NAV_RESULT=-1
    [[ $count -eq 0 ]] && return
    tput civis 2>/dev/null || true
    while true; do
        echoHeader "$title"
        echo -e "  ${DIM}${hint}${RESET}\n"
        for i in "${!_items[@]}"; do
            if [[ -n "$render_fn" ]]; then echo -e "$("$render_fn" "$i" "$taken")"
            elif [[ $i -eq $taken ]]; then echo -e "  ${GREEN}▶  ${BOLD}${_items[$i]}${RESET}"
            else echo -e "     ${_items[$i]}"; fi
        done
        readKeyboardo
        case "$KEY" in
            UP|k)     taken=$(( taken - 1 )); [[ $taken -lt 0 ]] && taken=$(( count - 1 )) ;;
            DOWN|j)   taken=$(( taken + 1 )); [[ $taken -ge count ]] && taken=0 ;;
            ""|$'\n') NAV_RESULT=$taken; break ;;
            q|Q)      NAV_RESULT=-1;     break ;;
        esac
    done
    tput cnorm 2>/dev/null || true
}

# ----- Header -----
echoHeader() {
  clear

  printf "%b" "${CYAN}${BOLD}"
  cat << "EOF"
 __     ___       __  __       _ _
 \ \   / (_)_ __ |  \/  | __ _(_) |
  \ \ / /| | '_ \| |\/| |/ _` | | |
   \ V / | | | | | |  | | (_| | | |
    \_/  |_|_| |_|_|  |_|\__,_|_|_|

EOF
  printf "%b" "${RESET}"

  printf "%b            >>> v%s <<<\n\n%b" "${CYAN}${BOLD}" "$VERSION" "${RESET}"
  printf " %s \n\n" "$SUBTITLE"
  echo -e "${RESET}"
  [[ -n "${1:-}" ]] && echo -e "  ${BOLD}--> ${1} <--${RESET}\n"
}

echoMainHeader() {
    echoHeader ""
    echo -e "  ${GREEN}${GREETING}, ${BOLD}${WHOAMI}!${RESET}"
    local active; active=$(fetchActive)
    if [[ -n "$active" ]]; then
        local email; email=$(grep "^${active}|" "$META_FILE" 2>/dev/null | cut -d'|' -f2 || echo "?")
        echo -e "  ${DIM}Active: ${RESET}${GREEN}${BOLD}${active}${RESET} ${DIM}<${email}>${RESET}\n"
    else
        echo -e "  ${DIM}Active: ${RED}none${RESET}\n"
    fi
    echo -e "  ${DIM}↑/k up · ↓/j down · Enter select · q quit${RESET}\n"
}

# ----- GPG -----
checkGpg() {
    command -v gpg &>/dev/null || { err "gpg not found. Install gnupg."; return 1; }
}

# ----- Password Storage -----
vaultify() {
    local alias="$1"
    local config_file="$ACCOUNTS_DIR/${alias}.conf"

    echo -e "\n${YELLOW}  Password storage:${RESET}"
    echo -e "  ${BOLD}[1]${RESET} Plain text  ${DIM}(chmod 600)${RESET}"
    echo -e "  ${BOLD}[2]${RESET} GPG encrypt ${DIM}(recommended)${RESET}"

    local choice
    while true; do
        echo -ne "\n  Choice [1/2]: "
        read -r choice
        [[ "$choice" == "1" || "$choice" == "2" ]] && break
        warn "Enter 1 or 2."
    done

    [[ "$choice" == "2" ]] && ! checkGpg && { warn "Falling back to plain text."; choice="1"; }

    echo -ne "  App Password (NOT login password): "
    local password; read -r password
    echo

    if [[ "$choice" == "2" ]]; then
        echo -e "\n${CYAN}  GPG secret keys:${RESET}"
        gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
            | grep -E "^(sec|uid)" | head -10 | sed 's/^/  /' \
            || { warn "No GPG keys found. Falling back to plain text."; choice="1"; }
    fi

    if [[ "$choice" == "2" ]]; then
        echo -ne "  GPG key ID or email: "
        local gpg_key; read -r gpg_key
        local gpg_file="$ACCOUNTS_DIR/${alias}.pass.gpg"

        if echo "$password" | gpg --batch --yes \
                --encrypt --recipient "$gpg_key" \
                --output "$gpg_file" 2>/tmp/vinmail_gpg_err; then
            chmod 600 "$gpg_file"
            sed -i '/^password\|^passwordeval/d' "$config_file"
            echo "passwordeval gpg --quiet --decrypt ${gpg_file}" >> "$config_file"
            ok "Password encrypted with GPG."
            return 0
        else
            err "GPG failed. Falling back to plain text."
            choice="1"
        fi
    fi

    sed -i '/^password\|^passwordeval/d' "$config_file"
    echo "password $password" >> "$config_file"
    chmod 600 "$config_file"
    ok "Password saved."
}

# ----- Config Functions -----
writeConfig() {
    local file="$1" email="$2" name="$3" host="$4" port="$5" starttls="$6" tls_file="$7"
    cat > "$file" <<CONF
# VinMail account config
defaults
auth           on
tls            on
tls_starttls   ${starttls}
tls_trust_file ${tls_file}
logfile        ${VINMAIL_DIR}/msmtp.log

account        default
host           ${host}
port           ${port}
from           "${name}"
user           ${email}
password       PLACEHOLDER
CONF
    chmod 600 "$file"
}

fetchConfig() {
    echoHeader "Config: ${1}"
    sed 's/^\(password[[:space:]]\+\).*/\1[hidden]/' "$ACCOUNTS_DIR/${1}.conf"
    pressAnyKey
}

# ----- Test Account -----
testAccount() {
    echoHeader "Test: ${1}"
    echo -e "  Testing SMTP connection...\n"
    if msmtp --file="$ACCOUNTS_DIR/${1}.conf" --serverinfo 2>&1 | sed 's/^/  /'; then
        echo; ok "Connection successful!"
    else
        echo; err "Connection failed."
    fi
    pressAnyKey
}
# ----- Add Account -----
addAccount() {
    echoHeader "Add Account"
    local alias email name host port starttls tls_file

    while true; do
        echo -ne "  ${CYAN}Alias${RESET}: "; read -r alias
        alias=$(echo "$alias" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        validateAlias "$alias" || continue
        grep -q "^${alias}|" "$META_FILE" 2>/dev/null \
            && { err "'${alias}' already exists."; continue; }
        break
    done
    while true; do echo -ne "  ${CYAN}Email${RESET}: "; read -r email; validateMailo "$email" && break; done
    while true; do
        echo -ne "  ${CYAN}Display name${RESET}: "; read -r name; name="${name//|/}"
        [[ -n "$name" ]] && break; err "Cannot be empty."
    done

    echo -e "\n  ${CYAN}SMTP preset:${RESET}"
    echo -e "  ${BOLD}[1]${RESET} Gmail          smtp.gmail.com:587"
    echo -e "  ${BOLD}[2]${RESET} Gmail SSL      smtp.gmail.com:465"
    echo -e "  ${BOLD}[3]${RESET} Outlook        smtp-mail.outlook.com:587"
    echo -e "  ${BOLD}[4]${RESET} Zoho Mail      smtp.zoho.com:587"
    echo -e "  ${BOLD}[5]${RESET} Yahoo          smtp.mail.yahoo.com:587"
    echo -e "  ${BOLD}[6]${RESET} Fastmail       smtp.fastmail.com:587"
    echo -e "  ${BOLD}[7]${RESET} Custom"
    local preset; echo -ne "\n  Choice [1-7]: "; read -r preset

    case "$preset" in
        1) host="smtp.gmail.com";          port="587"; starttls="on"  ;;
        2) host="smtp.gmail.com";          port="465"; starttls="off" ;;
        3) host="smtp-mail.outlook.com";   port="587"; starttls="on"  ;;
        4) host="smtp.zoho.com";           port="587"; starttls="on"  ;;
        5) host="smtp.mail.yahoo.com";     port="587"; starttls="on"  ;;
        6) host="smtp.fastmail.com";       port="587"; starttls="on"  ;;
        *)
            while true; do echo -ne "  ${CYAN}Host${RESET}: "; read -r host; [[ -n "$host" ]] && break; done
            while true; do
                echo -ne "  ${CYAN}Port${RESET} [587]: "; read -r port; port="${port:-587}"
                validatePorto "$port" && break
            done
            [[ "$port" == "465" ]] && starttls="off" || starttls="on"
            ;;
    esac

    local default_tls; default_tls=$(detectTLSPhile)
    echo -ne "  ${CYAN}TLS trust file${RESET} [${default_tls}]: "
    read -r tls_file; tls_file="${tls_file:-$default_tls}"
    [[ ! -f "$tls_file" ]] && warn "TLS file not found."

    local config_file="$ACCOUNTS_DIR/${alias}.conf"
    writeConfig "$config_file" "$email" "$name" "$host" "$port" "$starttls" "$tls_file"

    echo -e "\n${BOLD}  >>> Password <<<${RESET}"
    vaultify "$alias"

    echo -ne "\n  Open config in ${CYAN}${EDITOR}${RESET}? [y/N]: "
    local ov; read -r ov; [[ "$ov" =~ ^[Yy]$ ]] && "$EDITOR" "$config_file"

    echo -ne "  Test SMTP now? [y/N]: "
    local dt; read -r dt; [[ "$dt" =~ ^[Yy]$ ]] && testAccount "$alias"

    local enc=0
    grep -q "^passwordeval" "$config_file" && enc=1
    echo "${alias}|${email}|${enc}" >> "$META_FILE"
    ok "Account '${alias}' <${email}> added."; sleep 1
}
# ----- Delete Account -----
delAccount() {
    fetchAccounts
    [[ ${#ALIASES[@]} -eq 0 ]] && { err "No accounts."; sleep 2; return; }
    navigate "Delete Account" "↑/k · ↓/j · Enter · q cancel" ALIASES 0 "_del_render"
    local idx=$NAV_RESULT; [[ $idx -lt 0 ]] && return
    local alias="${ALIASES[$idx]}"
    echo -ne "\n  ${RED}Type 'yes' to delete '${alias}': ${RESET}"; local c; read -r c
    if [[ "$c" == "yes" ]]; then
        rm -f "$ACCOUNTS_DIR/${alias}.conf" "$ACCOUNTS_DIR/${alias}.pass.gpg"
        rmMeta "$alias"
        local active; active=$(fetchActive)
        if [[ "$active" == "$alias" ]]; then
            > "$ACTIVE_FILE"; rm -f "$MSMTPRC"; warn "Active account removed."
        fi
        ok "Deleted '${alias}'."
    else
        info "Cancelled."
    fi
    sleep 1
}

# ----- Edit Account -----
editAccount() {
    fetchAccounts
    [[ ${#ALIASES[@]} -eq 0 ]] && { err "No accounts."; sleep 2; return; }
    navigate "Edit Account" "↑/k · ↓/j · Enter · q cancel" ALIASES 0 "_edit_render"
    local idx=$NAV_RESULT; [[ $idx -lt 0 ]] && return
    local alias="${ALIASES[$idx]}" config_file="$ACCOUNTS_DIR/${ALIASES[$idx]}.conf"

    while true; do
        echoHeader "Edit: ${alias}"
        echo -e "  ${DIM}<${EMAILS[$idx]}>${RESET}\n"
        echo -e "  ${BOLD}[1]${RESET} Edit config in ${EDITOR}"
        echo -e "  ${BOLD}[2]${RESET} Change password"
        echo -e "  ${BOLD}[3]${RESET} Rename alias"
        echo -e "  ${BOLD}[4]${RESET} View config (password hidden)"
        echo -e "  ${BOLD}[5]${RESET} Test SMTP connection"
        echo -e "  ${BOLD}[q]${RESET} Back"
        echo -ne "\n  Choice: "; local ec; read -r ec
        case "$ec" in
            1) "$EDITOR" "$config_file" ;;
            2)
                vaultify "$alias"
                local enc=0
                grep -q "^passwordeval" "$config_file" && enc=1
                updatoMeta "$alias" "$enc"
                ok "Password updated."; sleep 1
                ;;
            3)
                echo -ne "\n  New alias for '${alias}': "; local new; read -r new
                new=$(echo "$new" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
                validateAlias "$new" || continue
                grep -q "^${new}|" "$META_FILE" 2>/dev/null \
                    && { err "'${new}' already exists."; continue; }
                mv "$ACCOUNTS_DIR/${alias}.conf" "$ACCOUNTS_DIR/${new}.conf"
                [[ -f "$ACCOUNTS_DIR/${alias}.pass.gpg" ]] && {
                    mv "$ACCOUNTS_DIR/${alias}.pass.gpg" "$ACCOUNTS_DIR/${new}.pass.gpg"
                    sed -i "s|${alias}.pass.gpg|${new}.pass.gpg|g" "$ACCOUNTS_DIR/${new}.conf"
                }
                local tmp; tmp=$(mktemp)
                grep -v "^${alias}|" "$META_FILE" > "$tmp" || true
                echo "${new}|${EMAILS[$idx]}|${ENCRYPTED[$idx]:-0}" >> "$tmp"
                mv "$tmp" "$META_FILE"
                local active; active=$(fetchActive)
                [[ "$active" == "$alias" ]] && printf '%s' "$new" > "$ACTIVE_FILE"
                ok "Renamed '${alias}' → '${new}'."; sleep 1; return
                ;;
            4) fetchConfig "$alias" ;;
            5) testAccount "$alias" ;;
            q|Q) return ;;
            *) warn "Unknown option." ;;
        esac
    done
}

# ----- Switch Account -----
switchAccount() {
    fetchAccounts
    [[ ${#ALIASES[@]} -eq 0 ]] && { warn "No accounts. Add one first."; sleep 2; return; }
    local active; active=$(fetchActive)
    local pre=0
    for i in "${!ALIASES[@]}"; do [[ "${ALIASES[$i]}" == "$active" ]] && pre=$i; done
    navigate "Switch Account" "↑/k · ↓/j · Enter · q cancel" ALIASES "$pre" "_switch_render"
    local idx=$NAV_RESULT; [[ $idx -lt 0 ]] && return
    local alias="${ALIASES[$idx]}"
    [[ ! -f "$ACCOUNTS_DIR/${alias}.conf" ]] && { err "Config missing."; sleep 2; return; }
    cp "$ACCOUNTS_DIR/${alias}.conf" "$MSMTPRC"
    chmod 600 "$MSMTPRC"
    printf '%s' "$alias" > "$ACTIVE_FILE"
    local written; written=$(fetchActive)
    [[ "$written" == "$alias" ]] \
        && ok "Active: ${BOLD}${alias}${RESET}${GREEN} <${EMAILS[$idx]}>" \
        || err "Failed to save active account."
    sleep 1
}

# ----- Status -----
showStatus() {
    fetchAccounts
    local active; active=$(fetchActive)
    echoHeader "Status"
    local total=${#ALIASES[@]} gpg_count=0 plain_count=0
    for enc in "${ENCRYPTED[@]:-}"; do
        [[ "$enc" == "1" ]] && gpg_count=$(( gpg_count + 1 )) \
                             || plain_count=$(( plain_count + 1 ))
    done
    echo -e "  ${BOLD}Data dir :${RESET} ${DIM}${VINMAIL_DIR}${RESET}"
    echo -e "  ${BOLD}Log      :${RESET} ${DIM}${VINMAIL_DIR}/msmtp.log${RESET}"
    echo -e "  ${BOLD}Accounts :${RESET} ${total} ${DIM}(${gpg_count} gpg · ${plain_count} plain)${RESET}"
    if [[ -n "$active" ]]; then
        local ae; ae=$(grep "^${active}|" "$META_FILE" 2>/dev/null | cut -d'|' -f2 || echo "?")
        echo -e "  ${BOLD}Active   :${RESET} ${GREEN}${BOLD}${active}${RESET} ${DIM}<${ae}>${RESET}"
    else
        echo -e "  ${BOLD}Active   :${RESET} ${RED}none${RESET}"
    fi
    echo
    if [[ $total -gt 0 ]]; then
        printf "  ${BOLD}%-20s %-32s %-5s${RESET}\n" "ALIAS" "EMAIL" "PASS"
        printf "  ${DIM}%-20s %-32s %-5s${RESET}\n" "--------------------" "--------------------------------" "-----"
        for i in "${!ALIASES[@]}"; do
            local enc_tag="${RED}plain${RESET}"
            [[ "${ENCRYPTED[$i]:-0}" == "1" ]] && enc_tag="${GREEN}gpg  ${RESET}"
            local star="  "
            [[ "${ALIASES[$i]}" == "$active" ]] && star="${YELLOW}★ ${RESET}"
            printf "  %b${BOLD}%-20s${RESET} ${DIM}%-32s${RESET} %b\n" \
                "$star" "${ALIASES[$i]}" "${EMAILS[$i]}" "$enc_tag"
        done
    else
        info "No accounts configured yet."
    fi
    pressAnyKey
}

# ----- Edit renderer -----
_edit_render() {
    local i="$1" t="$2" enc_tag=""
    [[ "${ENCRYPTED[$i]:-0}" == "1" ]] && enc_tag=" ${GREEN}[gpg]${RESET}"
    [[ $i -eq $t ]] \
        && echo -e "  ${GREEN}▶  ${BOLD}${ALIASES[$i]}${RESET} ${DIM}<${EMAILS[$i]}>${RESET}${enc_tag}" \
        || echo -e "     ${ALIASES[$i]} ${DIM}<${EMAILS[$i]}>${RESET}${enc_tag}"
}

_del_render() {
    local i="$1" t="$2"
    [[ $i -eq $t ]] \
        && echo -e "  ${RED}▶  ${BOLD}${ALIASES[$i]}${RESET} ${DIM}<${EMAILS[$i]}>${RESET}" \
        || echo -e "     ${ALIASES[$i]} ${DIM}<${EMAILS[$i]}>${RESET}"
}

_switch_render() {
    local i="$1" t="$2" active; active=$(fetchActive)
    local enc_tag="" star=""
    [[ "${ENCRYPTED[$i]:-0}" == "1" ]] && enc_tag=" ${GREEN}[gpg]${RESET}"
    [[ "${ALIASES[$i]}" == "$active" ]]  && star=" ${YELLOW}★ active${RESET}"
    [[ $i -eq $t ]] \
        && echo -e "  ${GREEN}▶  ${BOLD}${ALIASES[$i]}${RESET} ${DIM}<${EMAILS[$i]}>${RESET}${enc_tag}${star}" \
        || echo -e "     ${ALIASES[$i]} ${DIM}<${EMAILS[$i]}>${RESET}${enc_tag}${star}"
}

# ----- Main -----
vin() {
    local options=("Switch active account" "Add account" "Edit / Rename / Test"
                   "Delete account" "Status" "Quit")
    local count=${#options[@]} taken=0
    while true; do
        echoMainHeader
        for i in "${!options[@]}"; do
            [[ $i -eq $taken ]] \
                && echo -e "  ${GREEN}▶  ${BOLD}${options[$i]}${RESET}" \
                || echo -e "     ${options[$i]}"
        done
        readKeyboardo
        case "$KEY" in
            UP|k)     taken=$(( taken - 1 )); [[ $taken -lt 0 ]] && taken=$(( count - 1 )) ;;
            DOWN|j)   taken=$(( taken + 1 )); [[ $taken -ge count ]] && taken=0 ;;
            ""|$'\n')
                case $taken in
                    0) switchAccount ;; 1) addAccount ;;
                    2) editAccount   ;; 3) delAccount ;;
                    4) showStatus    ;; 5) echo -e "\n${DIM}  Goodbye.${RESET}\n"; exit 0 ;;
                esac ;;
            q|Q) echo -e "\n${DIM}  Goodbye.${RESET}\n"; exit 0 ;;
        esac
    done
}

# ----- Run -----
mkdir -p "$VINMAIL_DIR"
acquireLock
init
vin
