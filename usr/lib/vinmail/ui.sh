#!/bin/bash
# VinMail v1.1.0 - Terminal based Mail Manager
# "Bash-ing out an email."

# ----- Keyboard Reader (arrows + j/k) -----
KEY=""
readKeyboardo() {
    local char seq
    IFS= read -rsn1 char
    if [[ "$char" == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.15 seq 2>/dev/null || seq=""
        case "$seq" in
            '[A') KEY="UP"   ;; '[B') KEY="DOWN"  ;;
            '[C') KEY="RIGHT";; '[D') KEY="LEFT"   ;;
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

# ----- Headers -----
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
