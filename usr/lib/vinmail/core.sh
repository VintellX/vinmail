#!/bin/bash
# VinMail v1.1.0 - Terminal based Mail Manager
# "Bash-ing out an email."

# ----- Paths -----
VINMAIL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vinmail"
ACCOUNTS_DIR="$VINMAIL_DIR/accounts"
META_FILE="$VINMAIL_DIR/accounts.list"   # alias|email|encrypted(0|1)
ACTIVE_FILE="$VINMAIL_DIR/.active"
MSMTPRC="$HOME/.msmtprc"
# TEMPLATE_DIR="/usr/share/vinmail"
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$_lib_dir/../../share/vinmail" 2>/dev/null && pwd \
    || echo "/usr/share/vinmail")"
LOCK_FILE="$VINMAIL_DIR/.lock"
LOCK_DIR="$VINMAIL_DIR/.lockdir"
VERSION="1.1.0"
SUBTITLE="Bash-ing out an email; Shell yeah, mail sent."

# ----- Color Codos -----
if [[ -t 1 ]]; then
    RED="\033[31m";     GREEN="\033[32m"
    YELLOW="\033[33m";  CYAN="\033[36m"
    BOLD="\033[1m";     DIM="\033[2m"; RESET="\033[0m"
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""
    BOLD=""; DIM=""; RESET=""
fi

# ----- Session Globals -----
WHOAMI=$(id -un)
GREETING=""
EDITOR="${VISUAL:-${EDITOR:-vim}}"
ALIASES=(); EMAILS=(); ENCRYPTED=()

# ----- Temp File Tracking -----
_TMPFILES=()
tmpFile() {
    local f; f=$(mktemp "${TMPDIR:-/tmp}/vinmail_XXXXXX${1:-}")
    _TMPFILES+=("$f"); echo "$f"
}

# ----- Cleanup -----
cleanup() {
    tput cnorm 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    for f in "${_TMPFILES[@]:-}"; do rm -f "$f"; done
}
trap cleanup EXIT INT TERM

# ----- Lock -----
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
err()         { echo -e "${RED}  ✗ $*${RESET}" >&2; }
ok()          { echo -e "${GREEN}  ✓ $*${RESET}"; }
warn()        { echo -e "${YELLOW}  ! $*${RESET}"; }
info()        { echo -e "${DIM}  $*${RESET}"; }
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
