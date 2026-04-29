#!/bin/bash
# VinMail v1.0.0 - Terminal based Mail Manager
# "Bash-ing out an email."

# ----- Send Mailo -----
sendMail() {
    local active; active=$(fetchActive)
    if [[ -z "$active" ]]; then
        err "No active account. Switch to one first."; sleep 2; return
    fi

    local account_conf="$ACCOUNTS_DIR/${active}.conf"
    if [[ ! -f "$account_conf" ]]; then
        err "Config not found for '${active}'. Try switching again."; sleep 2; return
    fi

    cp "$account_conf" "$MSMTPRC"
    chmod 600 "$MSMTPRC"

    local active_email active_name
    active_email=$(grep -E "^[[:space:]]*user[[:space:]]" "$account_conf" \
        | head -1 | awk '{print $2}' || echo "")
    active_name=$(grep -E "^[[:space:]]*from[[:space:]]" "$account_conf" \
        | head -1 | sed 's/^[[:space:]]*from[[:space:]]*//' | tr -d '"' || echo "")
    [[ -z "$active_name" ]] && active_name="$active_email"

    echoHeader "Send Mail"
    echo -e "  ${DIM}From: ${active_name} <${active_email}>${RESET}\n"

    # Headers
    local to cc subject
    while true; do
        echo -ne "  ${CYAN}To${RESET}      : "; read -r to
        [[ -n "$to" ]] && break; err "Recipient cannot be empty."
    done
    echo -ne "  ${CYAN}Cc${RESET}      : "; read -r cc
    echo -ne "  ${CYAN}Subject${RESET} : "; read -r subject

    local body_file; body_file=$(tmpFile ".txt")
    printf "\n\nThanks and regards,\n%s" "$active_name" > "$body_file"
    echo -e "\n  ${DIM}Opening ${EDITOR} for body...${RESET}"; sleep 0.4
    "$EDITOR" "$body_file"

    echo -ne "\n  ${YELLOW}Send to <${to}>? [Y/n]: ${RESET}"
    local confirm; read -r confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && { info "Cancelled."; sleep 1; return; }

    local date_str; date_str=$(date -R)
    local msg_id; msg_id="<$(date +%s).${RANDOM}@vinmail>"
    local out; out=$(tmpFile ".eml")

    {
        echo "Date: $date_str"
        echo "From: ${active_name} <${active_email}>"
        echo "To: $to"
        [[ -n "$cc" ]] && echo "Cc: $cc"
        echo "Subject: $subject"
        echo "Message-ID: $msg_id"
        echo "MIME-Version: 1.0"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo "Content-Transfer-Encoding: 8bit"
        echo "X-Mailer: VinMail ${VERSION}"
        echo ""
        cat "$body_file"
    } > "$out"

    local all_rcpts=()
    IFS=',' read -ra _to_arr <<< "$to"
    IFS=',' read -ra _cc_arr <<< "${cc:-}"
    for r in "${_to_arr[@]:-}" "${_cc_arr[@]:-}"; do
        r="${r// /}"; [[ -n "$r" ]] && all_rcpts+=("$r")
    done

    echo -e "\n  Sending..."
    if msmtp --file="$MSMTPRC" -- "${all_rcpts[@]}" < "$out"; then
        ok "Mail sent to: ${to}${cc:+, ${cc}}"
    else
        err "Send failed. Check ${VINMAIL_DIR}/msmtp.log"
    fi
    sleep 2
}
