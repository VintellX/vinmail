#!/bin/bash
# VinMail v1.2.0 - Terminal based Mail Manager
# "Bash-ing out an email."


# ----- Safe Temp File -----
safeTmpFile() {
    local ext="${1:-}" f
    local base
    base=$(mktemp "${TMPDIR:-/tmp}/vinmail_XXXXXX") || {
        err "mktemp failed"; return 1
    }
    if [[ -n "$ext" ]]; then
        mv "$base" "${base}${ext}"
        f="${base}${ext}"
    else
        f="$base"
    fi
    if command -v realpath &>/dev/null; then
        f=$(realpath "$f")
    elif [[ "$(uname)" == "Darwin" ]]; then
        f=$(perl -e 'use Cwd "abs_path"; print abs_path($ARGV[0])' "$f")
    fi
    _TMPFILES+=("$f")
    echo "$f"
}

# ----- MIME Helpers -----
mimeBoundary() {
    printf "vinmail_%s_%s" "$(date +%s)" "$RANDOM"
}

mimeTypeOf() {
    local f="$1"
    if command -v file &>/dev/null; then
        file --brief --mime-type "$f" 2>/dev/null || echo "application/octet-stream"
    else
        echo "application/octet-stream"
    fi
}

appendAttachment() {
    local out="$1" boundary="$2" fpath="$3"
    local fname; fname=$(basename "$fpath")
    local mime_type; mime_type=$(mimeTypeOf "$fpath")
    {
        echo "--${boundary}"
        echo "Content-Type: ${mime_type}; name=\"${fname}\""
        echo "Content-Transfer-Encoding: base64"
        echo "Content-Disposition: attachment; filename=\"${fname}\""
        echo ""
        base64 "$fpath"
        echo ""
    } >> "$out"
}

# ----- Message Builder -----
BUILD_MSG=""
buildMessage() {
    local from_name="$1" from_email="$2" to="$3" cc="$4" bcc="$5"
    local subject="$6" body_file="$7"
    local _attachments_name="$8"
    local gpg_sign="$9" gpg_key="${10:-}"
    local in_reply_to="${11:-}"
    local references="${12:-}"

    local _attachments=()
    eval "_attachments=(\"\${${_attachments_name}[@]+\${${_attachments_name}[@]}}\")"

    local out; out=$(safeTmpFile ".eml")
    BUILD_MSG="$out"

    local boundary; boundary=$(mimeBoundary)
    local date_str;  date_str=$(date -R)
    local msg_id;    msg_id="<$(date +%s).${RANDOM}@vinmail>"

    # ----- GPG clearsign -----
    local sig_file=""
    if [[ "$gpg_sign" == "yes" ]]; then
        local clearsigned; clearsigned=$(safeTmpFile ".asc")
        gpgLog
        if gpg --yes --local-user "$gpg_key" \
                --clearsign --output "$clearsigned" "$body_file" 2>/tmp/vinmail_sign_err; then
            sig_file="$clearsigned"
            ok "Clearsigned attachment ready."
        else
            err "GPG signing failed:"
            sed 's/^/  /' /tmp/vinmail_sign_err >&2
            warn "Sending without signature."
            gpg_sign="no"
        fi
    fi

    # ----- MIME structure -----
    local has_attachments=0
    [[ ${#_attachments[@]} -gt 0 ]] && has_attachments=1
    [[ -n "$sig_file" ]]            && has_attachments=1

    {
        echo "Date: $date_str"
        echo "From: ${from_name} <${from_email}>"
        echo "To: $to"
        [[ -n "$cc" ]] && echo "Cc: $cc"
        echo "Subject: $subject"
        echo "Message-ID: $msg_id"
        [[ -n "$in_reply_to" ]]  && echo "In-Reply-To: $in_reply_to"
        [[ -n "$references" ]]   && echo "References: $references"
        echo "MIME-Version: 1.0"
        echo "X-Mailer: VinMail ${VERSION}"

        if [[ $has_attachments -eq 1 ]]; then
            echo "Content-Type: multipart/mixed; boundary=\"${boundary}\""
            echo ""
            echo "--${boundary}"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo "Content-Transfer-Encoding: 8bit"
            echo ""
            cat "$body_file"
            echo ""
        else
            echo "Content-Type: text/plain; charset=UTF-8"
            echo "Content-Transfer-Encoding: 8bit"
            echo ""
            cat "$body_file"
        fi
    } > "$out"

    # ----- User attachments -----
    for fpath in "${_attachments[@]:-}"; do
        [[ -z "$fpath" || ! -f "$fpath" ]] && continue
        appendAttachment "$out" "$boundary" "$fpath"
    done

    # ----- GPG signature.asc attachment -----
    if [[ -n "$sig_file" ]]; then
        {
            echo "--${boundary}"
            echo "Content-Type: text/plain; name=\"signature.asc\""
            echo "Content-Transfer-Encoding: 7bit"
            echo "Content-Disposition: attachment; filename=\"signature.asc\""
            echo "Content-Description: GPG clearsigned body"
            echo ""
            cat "$sig_file"
            echo ""
        } >> "$out"
    fi

    [[ $has_attachments -eq 1 ]] && echo "--${boundary}--" >> "$out"
}

# ----- Compose State View -----
showComposeState() {
    local from_name="$1" from_email="$2" to="$3" cc="$4" bcc="$5"
    local subject="$6" attachments="$7" gpg_sign="$8" gpg_key="$9"

    echoHeader "Compose Mail"
    echo -e "  ${DIM}From   :${RESET} ${from_name} <${from_email}>"
    echo -e "  ${CYAN}To     :${RESET} ${to:-${RED}(required)${RESET}}"
    echo -e "  ${CYAN}Cc     :${RESET} ${cc:-(none)}"
    echo -e "  ${CYAN}Bcc    :${RESET} ${bcc:-(none)}"
    echo -e "  ${CYAN}Subject:${RESET} ${subject:-(empty)}"
    echo -e "  ${CYAN}Attach :${RESET} ${attachments:-(none)}"
    if [[ "$gpg_sign" == "yes" ]]; then
        echo -e "  ${CYAN}GPG    :${RESET} ${GREEN}sign with ${gpg_key}${RESET}"
    else
        echo -e "  ${CYAN}GPG    :${RESET} (unsigned)"
    fi
    echo
}

# ----- Attachment Manager -----
manageAttachments() {
    local _pa_list_name="$1"

    while true; do
        local _pa_list=()
        eval "_pa_list=(\"\${${_pa_list_name}[@]+\${${_pa_list_name}[@]}}\")"

        echoHeader "Attachments"
        echo -e "  ${DIM}Current:${RESET}"
        if [[ ${#_pa_list[@]} -eq 0 ]]; then
            echo -e "  ${DIM}(none)${RESET}"
        else
            for i in "${!_pa_list[@]}"; do
                local sz; sz=$(du -sh "${_pa_list[$i]}" 2>/dev/null | cut -f1 || echo "?")
                echo -e "  ${BOLD}[$i]${RESET} ${_pa_list[$i]} ${DIM}(${sz})${RESET}"
            done
        fi
        echo
        echo -e "  ${BOLD}[a]${RESET} Add file"
        echo -e "  ${BOLD}[r]${RESET} Remove file"
        echo -e "  ${BOLD}[q]${RESET} Done"
        echo -ne "\n  Choice: "; local c; read -r c

        case "$c" in
            a|A)
                local fpath
                readFilePath fpath "Path to file" || continue
                fpath="${fpath/#\~/$HOME}"
                if [[ ! -f "$fpath" ]]; then
                    err "File not found: $fpath"; sleep 1
                elif [[ ! -r "$fpath" ]]; then
                    err "Cannot read: $fpath"; sleep 1
                else
                    _pa_list+=("$fpath")
                    eval "${_pa_list_name}=(\"\${_pa_list[@]}\")"
                    ok "Added: $(basename "$fpath")"; sleep 1
                fi
                ;;
            r|R)
                [[ ${#_pa_list[@]} -eq 0 ]] && { warn "Nothing to remove."; sleep 1; continue; }
                echo -ne "  Remove index [0-$(( ${#_pa_list[@]} - 1 ))]: "
                local ridx; read -r ridx
                if [[ "$ridx" =~ ^[0-9]+$ ]] && (( ridx < ${#_pa_list[@]} )); then
                    info "Removed: ${_pa_list[$ridx]}"
                    _pa_list=( "${_pa_list[@]:0:$ridx}" "${_pa_list[@]:$(( ridx + 1 ))}" )
                    eval "${_pa_list_name}=(\"\${_pa_list[@]+\${_pa_list[@]}}\")"
                    sleep 1
                else
                    err "Invalid index."; sleep 1
                fi
                ;;
            q|Q) return ;;
            *) warn "Enter a, r, or q." ;;
        esac
    done
}

# ----- GPG Setup -----
setupGpgSign() {
    local _sign_ref_name="$1"
    local _key_ref_name="$2"

    if ! checkGpg; then warn "GPG not available."; sleep 2; return; fi

    local out
    out=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
        | grep -E "^(sec|uid)" | head -20 || true)
    if [[ -z "$out" ]]; then
        warn "No GPG signing keys found. Run: gpg --gen-key"; sleep 2; return
    fi
    echo -e "\n${CYAN}  GPG signing keys:${RESET}"
    echo "$out" | sed 's/^/  /'

    echo -ne "\n  GPG key ID or email to sign with: "
    local k; read -r k
    [[ -z "$k" ]] && { warn "No key entered — signing disabled."; sleep 1; return; }

    if gpg --list-secret-keys "$k" &>/dev/null; then
        eval "$_sign_ref_name=\"yes\""
        eval "$_key_ref_name=\"\$k\""
        ok "Will sign with: $k"
    else
        err "Key '${k}' not found."; warn "Signing disabled."
    fi
    sleep 1
}

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

    # ----- Compose state -----
    local to="" cc="" bcc="" subject=""
    local gpg_sign="no" gpg_key=""
    local ATTACHMENTS=()

    local body_file; body_file=$(safeTmpFile ".txt")
    [[ -z "$body_file" || ! -f "$body_file" ]] && {
        err "Could not create temporary body file."; sleep 2; return
    }
    printf "\n\nThanks and regards,\n%s\n" "$active_name" > "$body_file"

    
    _composeLoop "$active" "$account_conf" "$active_email" "$active_name" \
        "" "" "" "" "no" "" "$body_file"
}

# ----- Sedn mailo from draft -----
sendMailFromDraft() {
    local draft_file="$1"
 
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
 
    loadDraft "$draft_file" || return
 
    local ATTACHMENTS=()
    if [[ -n "$DRAFT_ATTACHMENTS" ]]; then
        IFS='|' read -ra ATTACHMENTS <<< "$DRAFT_ATTACHMENTS"
        local valid=()
        for f in "${ATTACHMENTS[@]}"; do
            [[ -f "$f" ]] && valid+=("$f") || warn "Attachment no longer exists, skipping: $f"
        done
        ATTACHMENTS=("${valid[@]+"${valid[@]}"}")
    fi
 
    local body_file
    if [[ -n "$DRAFT_BODY_FILE" && -f "$DRAFT_BODY_FILE" ]]; then
        # copy to a temp file before editing
        body_file=$(safeTmpFile ".txt")
        cp "$DRAFT_BODY_FILE" "$body_file"
    else
        body_file=$(safeTmpFile ".txt")
        printf "\n\nThanks and regards,\n%s\n" "$active_name" > "$body_file"
    fi
 
    _composeLoop "$active" "$account_conf" "$active_email" "$active_name" \
        "$DRAFT_TO" "$DRAFT_CC" "$DRAFT_BCC" "$DRAFT_SUBJECT" \
        "$DRAFT_GPG_SIGN" "$DRAFT_GPG_KEY" "$body_file" "$draft_file"
}

# ----- Compose loop -----
_composeLoop() {
    local active="$1"
    local account_conf="$2"
    local active_email="$3"
    local active_name="$4"
    local to="$5"
    local cc="$6"
    local bcc="$7"
    local subject="$8"
    local gpg_sign="$9"
    local gpg_key="${10:-}"
    local body_file="${11}"
    local source_draft="${12:-}"   # set if opened from a draft
    local in_reply_to="${13:-}"
    local references="${14:-}"

    local _draft_saved=0 # tracking state :)
 
    while true; do
        local attach_display=""
        if [[ ${#ATTACHMENTS[@]} -gt 0 ]]; then
            local names=()
            for f in "${ATTACHMENTS[@]}"; do names+=("$(basename "$f")"); done
            attach_display=$(printf '%s, ' "${names[@]}")
            attach_display="${attach_display%, }"
        fi
 
        showComposeState "$active_name" "$active_email" \
            "$to" "$cc" "$bcc" "$subject" "$attach_display" "$gpg_sign" "$gpg_key"
        [[ -n "$in_reply_to" ]] && \
            echo -e "  ${DIM}Reply to: ${in_reply_to}${RESET}\n"
        echo -e "  ${BOLD}[t]${RESET} Edit To"
        echo -e "  ${BOLD}[c]${RESET} Edit Cc"
        echo -e "  ${BOLD}[b]${RESET} Edit Bcc"
        echo -e "  ${BOLD}[s]${RESET} Edit Subject"
        echo -e "  ${BOLD}[e]${RESET} Edit body in ${EDITOR}"
        echo -e "  ${BOLD}[a]${RESET} Manage attachments"
        echo -e "  ${BOLD}[g]${RESET} GPG sign settings"
        echo -e "  ${BOLD}[d]${RESET} Save draft"
        echo -e "  ${BOLD}[y]${RESET} ${GREEN}${BOLD}Send${RESET}"
        echo -e "  ${BOLD}[q]${RESET} Cancel / discard"
        echo -ne "\n  Action: "; local action; read -r action
 
        case "$action" in
            t|T)
                readPrefill to "${CYAN}To${RESET}" "$to"
                _draft_saved=0
                ;;
            c|C)
                readPrefill cc "${CYAN}Cc${RESET}" "$cc"
                _draft_saved=0
                ;;
            b|B)
                readPrefill bcc "${CYAN}Bcc${RESET}" "$bcc"
                _draft_saved=0
                ;;
            s|S)
                readPrefill subject "${CYAN}Subject${RESET}" "$subject"
                _draft_saved=0;;
            e|E)
                "$EDITOR" "$body_file"
                _draft_saved=0
                ;;
            a|A) manageAttachments ATTACHMENTS ;;
            d|D)
                saveDraft "$to" "$cc" "$bcc" "$subject" \
                    "$gpg_sign" "$gpg_key" "$body_file" ATTACHMENTS
                # if editing an existing draft, del the old one after saving new
                if [[ -n "$source_draft" && -f "$source_draft" ]]; then
                    deleteDraft "$source_draft"
                    source_draft=""
                fi
                _draft_saved=1
                ;;
            g|G)
                if [[ "$gpg_sign" == "yes" ]]; then
                    echo -ne "  Disable GPG signing? [y/N]: "; local dis; read -r dis
                    if [[ "$dis" =~ ^[Yy]$ ]]; then
                        gpg_sign="no"; gpg_key=""; ok "Signing disabled."; sleep 1
                    fi
                else
                    setupGpgSign gpg_sign gpg_key
                fi
                ;;
            y|Y)
                if [[ -z "$to" ]]; then
                    err "Recipient (To) is required."; sleep 2; continue
                fi
 
                local body_text
                body_text=$(grep -v "^-- $" "$body_file" \
                    | grep -v "^${active_name}$" \
                    | grep -v "^${active_email}$" \
                    | tr -d '[:space:]' || true)
                if [[ -z "$body_text" ]]; then
                    warn "Message body appears empty."
                    echo -ne "  Send anyway? [y/N]: "; local eo; read -r eo
                    [[ ! "$eo" =~ ^[Yy]$ ]] && continue
                fi
 
                # Preview
                echoHeader "Preview"
                echo -e "  ${DIM}From   :${RESET} ${active_name} <${active_email}>"
                echo -e "  ${CYAN}To     :${RESET} ${to}"
                [[ -n "$cc" ]]             && echo -e "  ${CYAN}Cc     :${RESET} ${cc}"
                [[ -n "$bcc" ]]            && echo -e "  ${CYAN}Bcc    :${RESET} ${bcc}"
                echo -e "  ${CYAN}Subject:${RESET} ${subject:-(no subject)}"
                [[ -n "$attach_display" ]] && echo -e "  ${CYAN}Attach :${RESET} ${attach_display}"
                [[ "$gpg_sign" == "yes" ]] && echo -e "  ${CYAN}GPG    :${RESET} ${GREEN}signed${RESET}"
                echo -e "\n  --> Body preview <--"
                local term_width; term_width=$(tput cols 2>/dev/null || echo 80)
                cat "$body_file" | fold -s -w $(( term_width - 4 )) | sed 's/^/  /'
                echo -e "  --->><<---"
 
                echo -ne "\n  ${YELLOW}Confirm send? [Y/n]: ${RESET}"
                local confirm; read -r confirm
                [[ "$confirm" =~ ^[Nn]$ ]] && continue
 
                buildMessage "$active_name" "$active_email" \
                    "$to" "$cc" "$bcc" "$subject" \
                    "$body_file" ATTACHMENTS "$gpg_sign" "$gpg_key" \
                    "$in_reply_to" "$references"
 
                local all_rcpts=()
                IFS=',' read -ra _to_arr  <<< "$to"
                IFS=',' read -ra _cc_arr  <<< "${cc:-}"
                IFS=',' read -ra _bcc_arr <<< "${bcc:-}"
                for r in "${_to_arr[@]:-}" "${_cc_arr[@]:-}" "${_bcc_arr[@]:-}"; do
                    r="${r// /}"; [[ -n "$r" ]] && all_rcpts+=("$r")
                done
 
                echo -e "\n  Sending..."
                gpgInfo "$account_conf"
                if msmtp --file="$MSMTPRC" -- "${all_rcpts[@]}" < "$BUILD_MSG"; then
                    ok "Mail sent to: ${to}${cc:+, ${cc}}${bcc:+ (+ bcc)}"
                    # del draft after on successful send
                    if [[ -n "$source_draft" && -f "$source_draft" ]]; then
                        deleteDraft "$source_draft"
                        info "Draft deleted after sending."
                    fi
                else
                    err "Send failed. Check ${VINMAIL_DIR}/msmtp.log"
                fi
                sleep 2; return
                ;;
            q|Q)
                if [[ $_draft_saved -eq 1 ]]; then
                    info "Draft saved. Returning to menu."; sleep 1; return
                else
                    echo -ne "\n  Discard draft? [y/N]: "
                    local dis; read -r dis
                    [[ "$dis" =~ ^[Yy]$ ]] && { info "Discarded."; sleep 1; return; }
                fi
                ;;
        esac
    done
}
