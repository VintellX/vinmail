#!/bin/bash
# VinMail v1.1.0 - Terminal based Mail Manager
# "Bash-ing out an email."

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

# ----- View Config -----
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

# ----- Read or Abort -----
readOrAbort() {
    local _var_name="$1"
    # local -n _rab_var="$1"
    local prompt="$2"
    local _input
    echo -ne "  ${prompt}: "
    # read -r _rab_var
    # if [[ -z "$_rab_var" ]]; then
    #     info "Aborted."; sleep 1; return 1
    # fi
    read -r _input
    if [[ -z "$_input" ]]; then
        info "Aborted."; sleep 1; return 1
    fi
    eval "$_var_name=\"\$_input\""
    return 0
}

# ----- Add Account -----
addAccount() {
    echoHeader "Add Account"
    echo -e "  ${DIM}Leave any prompt empty and press Enter to abort.${RESET}\n"
    local alias email name host port starttls tls_file

    while true; do
        readOrAbort alias "${CYAN}Alias${RESET}" || return
        alias=$(echo "$alias" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        validateAlias "$alias" || continue
        grep -q "^${alias}|" "$META_FILE" 2>/dev/null \
            && { err "'${alias}' already exists."; continue; }
        break
    done

    while true; do
        readOrAbort email "${CYAN}Email${RESET}" || return
        validateMailo "$email" && break
    done

    while true; do
        readOrAbort name "${CYAN}Display name${RESET}" || return
        name="${name//|/}"
        [[ -n "$name" ]] && break
        err "Cannot be empty."
    done

    echo -e "\n  ${CYAN}SMTP preset:${RESET}"
    echo -e "  ${BOLD}[1]${RESET} Gmail          smtp.gmail.com:587"
    echo -e "  ${BOLD}[2]${RESET} Gmail SSL      smtp.gmail.com:465"
    echo -e "  ${BOLD}[3]${RESET} Outlook        smtp-mail.outlook.com:587"
    echo -e "  ${BOLD}[4]${RESET} Zoho Mail      smtp.zoho.com:587"
    echo -e "  ${BOLD}[5]${RESET} Yahoo          smtp.mail.yahoo.com:587"
    echo -e "  ${BOLD}[6]${RESET} Fastmail       smtp.fastmail.com:587"
    echo -e "  ${BOLD}[7]${RESET} Custom"
    local preset
    readOrAbort preset "\n  Choice [1-7]" || return

    case "$preset" in
        1) host="smtp.gmail.com";          port="587"; starttls="on"  ;;
        2) host="smtp.gmail.com";          port="465"; starttls="off" ;;
        3) host="smtp-mail.outlook.com";   port="587"; starttls="on"  ;;
        4) host="smtp.zoho.com";           port="587"; starttls="on"  ;;
        5) host="smtp.mail.yahoo.com";     port="587"; starttls="on"  ;;
        6) host="smtp.fastmail.com";       port="587"; starttls="on"  ;;
        *)
            while true; do
                readOrAbort host "${CYAN}Host${RESET}" || return
                [[ -n "$host" ]] && break
            done
            while true; do
                readOrAbort port "${CYAN}Port${RESET} [587]" || return
                port="${port:-587}"
                validatePorto "$port" && break
            done
            [[ "$port" == "465" ]] && starttls="off" || starttls="on"
            ;;
    esac

    # TLS trust file — empty = use default, not abort
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

# ----- List Renderers -----
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
