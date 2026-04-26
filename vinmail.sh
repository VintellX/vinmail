#!/bin/bash
# VinMail v0.1.0 - A simple mail selector for msmtp
# "Delivering bytes, not bites."

VINMAIL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vinmail"
ACCOUNTS_DIR="$VINMAIL_DIR/accounts"
META_FILE="$VINMAIL_DIR/accounts.list"   # alias|email|encrypted(0|1)
ACTIVE_FILE="$VINMAIL_DIR/.active"
MSMTPRC="$HOME/.msmtprc"
TEMPLATE_DIR="/usr/share/vinmail"

# ----- Color Codos -----
RED="\033[31m";     GREEN="\033[32m"
YELLOW="\033[33m";  BLUE="\033[34m"
MAGENTA="\033[35m"; CYAN="\033[36m"
RESET="\033[0m"

WHOAMI=$(id -un)

# ----- Helpahh Funcs -----
err() { echo -e "${RED}  ✗ $*${RESET}" >&2; }
ok() { echo -e "${GREEN}  ✓ $*${RESET}"; }
warn() { echo -e "${YELLOW}  ! $*${RESET}"; }
info() { echo -e "${DIM}  $*${RESET}"; }


# ----- Init -----
init() {
    mkdir -p "$ACCOUNTS_DIR"
    [[ ! -f "$META_FILE"   ]] && touch "$META_FILE"
    [[ ! -f "$ACTIVE_FILE" ]] && touch "$ACTIVE_FILE"
    if [[ ! -f "$HOME/.mailrc" && -f "$TEMPLATE_DIR/mailrc" ]]; then
        cp "$TEMPLATE_DIR/mailrc" "$HOME/.mailrc"
    fi
}

# ----- accounts -----
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

# ----- Validations TwT -----
validateAlias() {
    [[ -z "$1" ]]                  && { err "Alias cannot be empty.";    return 1; }
    [[ ! "$1" =~ ^[a-z0-9_-]+$ ]] && { err "Use only: a-z 0-9 - _";    return 1; }
    [[ ${#1} -gt 32 ]]            && { err "Alias too long (max 32).";   return 1; }
    return 0
}

validateEmail() {
    [[ -z "$1" ]]                         && { err "Email cannot be empty.";     return 1; }
    [[ ! "$1" =~ ^[^@]+@[^@]+\.[^@]+$ ]] && { err "Not a valid email address."; return 1; }
    [[ "$1" == *"|"* ]]                   && { err "Email cannot contain '|'.";  return 1; }
    return 0
}

# ----- GPG -----
check_gpg() {
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

    [[ "$choice" == "2" ]] && ! check_gpg && { warn "Falling back to plain text."; choice="1"; }

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

# ----- Write msmtprc -----
writeConfig() {
    local file="$1" email="$2" name="$3" host="$4" port="$5" tls_file="$6"
    cat > "$file" <<CONF
# VinMail account config
defaults
auth           on
tls            on
tls_starttls   on
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

# ----- Add Account -----
addAccount() {
    echo -e "\n${BOLD}  >>> Add Account <<<${RESET}\n"

    local alias email name host port tls_file

    while true; do
        echo -ne "  ${CYAN}Alias${RESET} (e.g. work): "
        read -r alias
        alias=$(echo "$alias" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        validateAlias "$alias" || continue
        grep -q "^${alias}|" "$META_FILE" 2>/dev/null \
            && { err "'${alias}' already exists."; continue; }
        break
    done

    while true; do
        echo -ne "  ${CYAN}Email${RESET}: "
        read -r email; validateEmail "$email" && break
    done

    while true; do
        echo -ne "  ${CYAN}Display name${RESET}: "
        read -r name; name="${name//|/}"
        [[ -n "$name" ]] && break
        err "Cannot be empty."
    done

    echo -ne "  ${CYAN}SMTP host${RESET} [smtp.gmail.com]: "
    read -r host; host="${host:-smtp.gmail.com}"

    echo -ne "  ${CYAN}SMTP port${RESET} [587]: "
    read -r port; port="${port:-587}"

    local default_tls="/etc/ssl/certs/ca-certificates.crt"
    [[ -f "/etc/pki/tls/certs/ca-bundle.crt" ]] && default_tls="/etc/pki/tls/certs/ca-bundle.crt"
    echo -ne "  ${CYAN}TLS trust file${RESET} [${default_tls}]: "
    read -r tls_file; tls_file="${tls_file:-$default_tls}"

    local config_file="$ACCOUNTS_DIR/${alias}.conf"
    writeConfig "$config_file" "$email" "$name" "$host" "$port" "$tls_file"

    echo -e "\n${BOLD}  >>> Password <<<${RESET}"
    vaultify "$alias"

    echo -ne "\n  Open config in vim? [y/N]: "
    local ov; read -r ov
    [[ "$ov" =~ ^[Yy]$ ]] && vim "$config_file"

    local enc=0
    grep -q "^passwordeval" "$config_file" && enc=1
    echo "${alias}|${email}|${enc}" >> "$META_FILE"

    ok "Account '${alias}' <${email}> added."
    sleep 1
}

# ----- Delete Account -----
delAccount() {
    fetchAccounts
    [[ ${#ALIASES[@]} -eq 0 ]] && { err "No accounts."; sleep 2; return; }

    echo -e "\n${BOLD}  >>> Delete Account <<<${RESET}\n"
    for i in "${!ALIASES[@]}"; do
        printf "  ${BOLD}[%d]${RESET} %s <%s>\n" "$i" "${ALIASES[$i]}" "${EMAILS[$i]}"
    done
    echo -ne "\n  Index to delete: "
    local idx; read -r idx

    if [[ ! "$idx" =~ ^[0-9]+$ ]] || (( idx >= ${#ALIASES[@]} )); then
        err "Invalid index."; sleep 1; return
    fi

    local alias="${ALIASES[$idx]}"
    echo -ne "  Type 'yes' to delete '${alias}': "
    local confirm; read -r confirm
    if [[ "$confirm" == "yes" ]]; then
        rm -f "$ACCOUNTS_DIR/${alias}.conf" "$ACCOUNTS_DIR/${alias}.pass.gpg"
        local tmp; tmp=$(mktemp)
        grep -v "^${alias}|" "$META_FILE" > "$tmp" || true
        mv "$tmp" "$META_FILE"
        local active; active=$(fetchActive)
        if [[ "$active" == "$alias" ]]; then
            > "$ACTIVE_FILE"; rm -f "$MSMTPRC"
            warn "Active account removed."
        fi
        ok "Deleted '${alias}'."
    else
        info "Cancelled."
    fi
    sleep 1
}

# ----- Switch Account -----
switchAccount() {
    fetchAccounts
    [[ ${#ALIASES[@]} -eq 0 ]] && { warn "No accounts. Add one first."; sleep 2; return; }

    local active; active=$(fetchActive)
    echo -e "\n${BOLD}  >>> Switch Account <<<${RESET}\n"
    for i in "${!ALIASES[@]}"; do
        local star=""
        [[ "${ALIASES[$i]}" == "$active" ]] && star=" ${YELLOW}★${RESET}"
        printf "  ${BOLD}[%d]${RESET} %s <%s>%b\n" "$i" "${ALIASES[$i]}" "${EMAILS[$i]}" "$star"
    done
    echo -ne "\n  Select [0-$(( ${#ALIASES[@]} - 1 ))]: "
    local idx; read -r idx

    if [[ ! "$idx" =~ ^[0-9]+$ ]] || (( idx >= ${#ALIASES[@]} )); then
        err "Invalid selection."; sleep 1; return
    fi

    local alias="${ALIASES[$idx]}"
    cp "$ACCOUNTS_DIR/${alias}.conf" "$MSMTPRC"
    chmod 600 "$MSMTPRC"
    printf '%s' "$alias" > "$ACTIVE_FILE"
    ok "Active: ${alias} <${EMAILS[$idx]}>"
    sleep 1
}

# ----- Main -----
vin() {
    local greetings=("Namaste (नमस्ते)" "Konnichiwa (こんにちは)" "¡Hola" "Hello" "Bonjour" "Salut" "Ciao" "NiHao (你好)" "Privet (Привет)")
    local greeting="${greetings[$(( RANDOM % ${#greetings[@]} ))]}"
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "  ╔══════════════════════════════╗"
        echo "  ║       VinMail v0.2.0         ║"
        echo "  ╚══════════════════════════════╝"
        echo -e "${RESET}"
        echo -e "  ${GREEN}${greeting}, ${BOLD}${WHOAMI}!${RESET}"

        local active; active=$(fetchActive)
        [[ -n "$active" ]] \
            && echo -e "  ${DIM}Active: ${RESET}${GREEN}${active}${RESET}\n" \
            || echo -e "  ${DIM}Active: ${RED}none${RESET}\n"

        echo -e "  ${BOLD}[1]${RESET} Switch account"
        echo -e "  ${BOLD}[2]${RESET} Add account"
        echo -e "  ${BOLD}[3]${RESET} Delete account"
        echo -e "  ${BOLD}[q]${RESET} Quit"
        echo -ne "\n  Choice: "

        local c; read -r c
        case "$c" in
            1) switchAccount ;;
            2) addAccount    ;;
            3) delAccount ;;
            q|Q) echo -e "\n${DIM}  Goodbye.${RESET}\n"; exit 0 ;;
            *) ;;
        esac
    done
}

# ----- Run -----
mkdir -p "$VINMAIL_DIR"
init
vin
