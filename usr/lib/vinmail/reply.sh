#!/bin/bash
# VinMail v1.1.2 - Terminal based Mail Manager
# "Bash-ing out an email."

# ----- Parse EML -----
parseEml() {
    local eml_file="$1"
    local normalized_eml; normalized_eml=$(safeTmpFile ".eml")
    tr -d '\r' < "$eml_file" > "$normalized_eml"
    eml_file="$normalized_eml"
    # ----- Headers -----
    EML_FROM=""
    EML_TO=""
    EML_CC=""
    EML_SUBJECT=""
    EML_MSG_ID=""
    EML_REFERENCES=""
    EML_DATE=""
    EML_BODY_FILE=""
 
    local current_header="" current_value=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
 
        if [[ "$line" =~ ^[[:space:]] ]]; then
            current_value+=" ${line#"${line%%[! ]*}"}"
        else
            if [[ -n "$current_header" ]]; then
                _setEmlHeader "$current_header" "$current_value"
            fi
            current_header="${line%%:*}"
            current_value="${line#*: }"
        fi
    done < "$eml_file"
    [[ -n "$current_header" ]] && _setEmlHeader "$current_header" "$current_value"
 
    local body_file; body_file=$(safeTmpFile ".txt")
    EML_BODY_FILE="$body_file"
 
    local in_body=0 in_text_part=0 boundary=""
    local content_type
    content_type=$(grep -i "^Content-Type:" "$eml_file" | head -1)
 
    if echo "$content_type" | grep -qi "multipart"; then
        boundary=$(echo "$content_type" | grep -o 'boundary="[^"]*"' | cut -d'"' -f2)
        if [[ -z "$boundary" ]]; then
            boundary=$(echo "$content_type" | grep -o "boundary=[^ ;]*" | cut -d'=' -f2)
        fi
 
        local in_headers=0 found_plain=0
        while IFS= read -r line; do
            if [[ "$line" == "--${boundary}" || "$line" == "--${boundary} " ]]; then
                in_headers=1; in_text_part=0; found_plain=0; continue
            fi
            if [[ "$line" == "--${boundary}--" ]]; then break; fi
 
            if [[ $in_headers -eq 1 ]]; then
                [[ -z "$line" ]] && { in_headers=0; [[ $found_plain -eq 1 ]] && in_text_part=1; continue; }
                echo "$line" | grep -qi "content-type: text/plain" && found_plain=1
                continue
            fi
 
            if [[ $in_text_part -eq 1 ]]; then
                echo "$line" >> "$body_file"
            fi
        done < "$eml_file"
    else
        awk '/^$/{found=1; next} found{print}' "$eml_file" > "$body_file"
    fi
 
    return 0
}

# keep parseEml from being too messy, just vars
_setEmlHeader() {
    local header="$1" value="$2"
    local header_lower
    header_lower=$(echo "$header" | tr '[:upper:]' '[:lower:]')
    case "$header_lower" in
        from)        EML_FROM="$value"       ;;
        to)          EML_TO="$value"         ;;
        cc)          EML_CC="$value"         ;;
        subject)     EML_SUBJECT="$value"    ;;
        message-id)  EML_MSG_ID="$value"     ;;
        references)  EML_REFERENCES="$value" ;;
        date)        EML_DATE="$value"       ;;
    esac
}

# ----- extract sender email and name -----
extractEmail() {
    local from="$1"
    if echo "$from" | grep -q "<"; then
        echo "$from" | grep -o '<[^>]*>' | tr -d '<>'
    else
        echo "$from" | tr -d ' '
    fi
}

extractName() {
    local from="$1"
    if echo "$from" | grep -q "<"; then
        echo "$from" | sed 's/[[:space:]]*<[^>]*>//' | tr -d '"' | sed 's/^[[:space:]]*//'
    else
        echo "$from"
    fi
}

quoteBody() {
    local body_file="$1"
    local from="$2"
    local date="$3"
    local quoted_file; quoted_file=$(safeTmpFile ".txt")
 
    {
        echo ""
        echo ""
        echo "> On ${date} ${from} wrote:"
        while IFS= read -r line; do
            echo "> ${line}"
        done < "$body_file"
    } > "$quoted_file"
 
    echo "$quoted_file"
}

replyToMail() {
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
 
    echoHeader "Reply to Mail"
    echo -e "  ${DIM}Provide the original mail as a .eml file.${RESET}"
    echo -e "  ${DIM}Most mail clients: File → Save As → .eml${RESET}\n"
    local eml_path
    readFilePath eml_path "Path to .eml file" || return
    eml_path="${eml_path/#\~/$HOME}"
 
    if [[ -z "$eml_path" ]]; then
        err "No file provided."; sleep 2; return
    fi
    if [[ ! -f "$eml_path" ]]; then
        err "File not found: $eml_path"; sleep 2; return
    fi
    if [[ "${eml_path##*.}" != "eml" ]]; then
        warn "File doesn't have .eml extension; trying anyway."
        sleep 1
    fi
 
    echo -e "\n  ${DIM}Parsing...${RESET}"
    parseEml "$eml_path"
 
    echoHeader "Reply to Mail"
    echo -e "  ${DIM}Parsed from original:${RESET}\n"
    echo -e "  ${DIM}From    :${RESET} ${EML_FROM}"
    echo -e "  ${DIM}Subject :${RESET} ${EML_SUBJECT}"
    echo -e "  ${DIM}Date    :${RESET} ${EML_DATE}"
    echo -e "  ${DIM}Msg-ID  :${RESET} ${EML_MSG_ID}"
    echo
 
    echo -e "  ${BOLD}[1]${RESET} Reply to sender only"
    echo -e "  ${BOLD}[2]${RESET} Reply all (sender + Cc)"
    echo -e "  ${BOLD}[q]${RESET} Cancel"
    echo -ne "\n  Choice: "; local choice; read -r choice
 
    case "$choice" in
        q|Q) return ;;
        2)
            local reply_to; reply_to=$(extractEmail "$EML_FROM")
            local orig_to_others=""
            if [[ -n "$EML_TO" ]]; then
                local _addr
                while IFS=',' read -ra _addrs; do
                    for _addr in "${_addrs[@]}"; do
                        _addr="${_addr// /}"
                        local _extracted; _extracted=$(extractEmail "$_addr")
                        # skip our own email
                        [[ "$_extracted" == "$active_email" ]] && continue
                        [[ -z "$orig_to_others" ]] \
                            && orig_to_others="$_addr" \
                            || orig_to_others="${orig_to_others}, ${_addr}"
                    done
                done <<< "$EML_TO"
            fi
        
            local orig_cc_others=""
            if [[ -n "$EML_CC" ]]; then
                local _addr
                while IFS=',' read -ra _addrs; do
                    for _addr in "${_addrs[@]}"; do
                        _addr="${_addr// /}"
                        local _extracted; _extracted=$(extractEmail "$_addr")
                        [[ "$_extracted" == "$active_email" ]] && continue
                        [[ -z "$orig_cc_others" ]] \
                            && orig_cc_others="$_addr" \
                            || orig_cc_others="${orig_cc_others}, ${_addr}"
                    done
                done <<< "$EML_CC"
            fi
        
            local reply_cc=""
            if [[ -n "$orig_to_others" && -n "$orig_cc_others" ]]; then
                reply_cc="${orig_to_others}, ${orig_cc_others}"
            elif [[ -n "$orig_to_others" ]]; then
                reply_cc="$orig_to_others"
            elif [[ -n "$orig_cc_others" ]]; then
                reply_cc="$orig_cc_others"
            fi
            ;;
        *)
            local reply_to; reply_to=$(extractEmail "$EML_FROM")
            local reply_cc=""
            ;;
    esac
 
    local reply_subject="$EML_SUBJECT"
    if ! echo "$reply_subject" | grep -qi "^Re:"; then
        reply_subject="Re: ${reply_subject}"
    fi
 
    local reply_references=""
    if [[ -n "$EML_REFERENCES" ]]; then
        reply_references="${EML_REFERENCES} ${EML_MSG_ID}"
    else
        reply_references="${EML_MSG_ID}"
    fi
 
    local quoted_body
    quoted_body=$(quoteBody "$EML_BODY_FILE" "$EML_FROM" "$EML_DATE")
 
    local body_file; body_file=$(safeTmpFile ".txt")
    {
        printf "\n\nThanks and regards,\n%s\n" "$active_name"
        cat "$quoted_body"
    } > "$body_file"
 
    local ATTACHMENTS=()
    _composeLoop "$active" "$account_conf" "$active_email" "$active_name" \
        "$reply_to" "$reply_cc" "" "$reply_subject" \
        "no" "" "$body_file" "" \
        "$EML_MSG_ID" "$reply_references"
}
