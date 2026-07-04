#!/bin/bash
# VinMail v1.2.1 - Terminal based Mail Manager
# "Bash-ing out an email."

decodeQP() {
    perl -0777 -pe 's/=\r?\n//g; s/=([0-9A-Fa-f]{2})/chr(hex($1))/ge' 2>/dev/null \
    || sed ':a;N;$!ba;s/=\n//g' | sed 's/=\r//g'
}
 
_getBoundary() {
    local text="$1"
    local b=""
    b=$(echo "$text" | grep -o 'boundary="[^"]*"' | head -1 | cut -d'"' -f2)
    if [[ -z "$b" ]]; then
        b=$(echo "$text" | grep -o "boundary=[^;[:space:]\"]*" \
            | head -1 | sed 's/boundary=//' | tr -d '"')
    fi
    echo "$b"
}

_processPart() {
    local part_file="$1"
    local part_ct="" part_enc="" in_h=1
    local header_block=""
 
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        header_block+="$line"$'\n'
        local lc; lc=$(echo "$line" | tr '[:upper:]' '[:lower:]')
        if echo "$lc" | grep -q "^content-type:"; then
            part_ct="$line"
        elif [[ "$line" =~ ^[[:space:]] ]] && [[ -n "$part_ct" ]]; then
            part_ct+=" $line"
        fi
        if echo "$lc" | grep -q "^content-transfer-encoding:"; then
            part_enc=$(echo "$line" | sed 's/.*:[[:space:]]*//' \
                | tr '[:upper:]' '[:lower:]' | tr -d ' \r')
        fi
    done < "$part_file"
 
    local lc_ct; lc_ct=$(echo "$part_ct" | tr '[:upper:]' '[:lower:]')
 
    if echo "$lc_ct" | grep -q "text/plain"; then
        local body; body=$(safeTmpFile ".body")
        awk 'found{print} /^$/ && !found{found=1}' "$part_file" > "$body"
        case "$part_enc" in
            quoted-printable|quoted_printable) decodeQP < "$body" ;;
            base64) base64 -d "$body" 2>/dev/null ;;
            *) cat "$body" ;;
        esac
        rm -f "$body"
        return 0
 
    elif echo "$lc_ct" | grep -q "multipart"; then
        local nb; nb=$(_getBoundary "$header_block")
        if [[ -n "$nb" ]]; then
            local nested; nested=$(safeTmpFile ".nested")
            cp "$part_file" "$nested"
            _extractTextPlain "$nested" "$nb"
            local rc=$?
            rm -f "$nested"
            return $rc
        fi
    fi
    return 1
}
_extractTextPlain() {
    local file="$1"
    local boundary="${2:-}"
 
    if [[ -z "$boundary" ]]; then
        local ct_block="" in_ct=0
        while IFS= read -r line; do
            if echo "$line" | grep -qi "^Content-Type:"; then
                ct_block="$line"; in_ct=1
            elif [[ $in_ct -eq 1 && "$line" =~ ^[[:space:]] ]]; then
                ct_block+=" $line"
            elif [[ $in_ct -eq 1 ]]; then
                break
            fi
        done < "$file"
        boundary=$(_getBoundary "$ct_block")
    fi
 
    [[ -z "$boundary" ]] && return 1
 
    local part_file; part_file=$(safeTmpFile ".part")
    local in_part=0 found=0
 
    while IFS= read -r line; do
        line="${line%$'\r'}"
 
        if [[ "$line" == "--${boundary}" || "$line" == "--${boundary} " ]]; then
            if [[ $in_part -eq 1 && -s "$part_file" ]]; then
                if _processPart "$part_file"; then
                    found=1; break
                fi
            fi
            > "$part_file"; in_part=1; continue
        fi
 
        if [[ "$line" == "--${boundary}--" || "$line" == "--${boundary}-- " ]]; then
            if [[ $in_part -eq 1 && -s "$part_file" ]]; then
                _processPart "$part_file" && found=1
            fi
            break
        fi
 
        [[ $in_part -eq 1 ]] && echo "$line" >> "$part_file"
    done < "$file"
 
    rm -f "$part_file"
    return $(( found == 0 ? 1 : 0 ))
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

# ----- Parse EML -----
parseEml() {
    local eml_file="$1"
 
    local clean; clean=$(safeTmpFile ".eml")
    tr -d '\r' < "$eml_file" > "$clean"
    eml_file="$clean"
    # ----- Headers -----
    EML_FROM=""
    EML_TO=""
    EML_CC=""
    EML_SUBJECT=""
    EML_MSG_ID=""
    EML_REFERENCES=""
    EML_DATE=""
    EML_BODY_FILE=""
 
    local cur_h="" cur_v=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        if [[ "$line" =~ ^[[:space:]] ]]; then
            cur_v+=" ${line#"${line%%[! 	]*}"}"
        else
            [[ -n "$cur_h" ]] && _setEmlHeader "$cur_h" "$cur_v"
            cur_h="${line%%:*}"
            cur_v="${line#*: }"
        fi
    done < "$eml_file"
    [[ -n "$cur_h" ]] && _setEmlHeader "$cur_h" "$cur_v"
 
    local body_file; body_file=$(safeTmpFile ".txt")
    EML_BODY_FILE="$body_file"
 
    local ct_block="" in_ct=0
    while IFS= read -r line; do
        if echo "$line" | grep -qi "^Content-Type:"; then
            ct_block="$line"; in_ct=1
        elif [[ $in_ct -eq 1 && "$line" =~ ^[[:space:]] ]]; then
            ct_block+=" $line"
        elif [[ $in_ct -eq 1 ]]; then
            break
        fi
    done < "$eml_file"
 
    if echo "$ct_block" | grep -qi "multipart"; then
        local top_boundary; top_boundary=$(_getBoundary "$ct_block")
        [[ -n "$top_boundary" ]] && \
            _extractTextPlain "$eml_file" "$top_boundary" > "$body_file"
    else
        local top_enc
        top_enc=$(grep -i "^Content-Transfer-Encoding:" "$eml_file" | head -1 \
            | sed 's/.*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        local raw; raw=$(safeTmpFile ".raw")
        awk '/^$/{found=1;next} found{print}' "$eml_file" > "$raw"
        case "$top_enc" in
            quoted-printable|quoted_printable) decodeQP < "$raw" > "$body_file" ;;
            base64) base64 -d "$raw" > "$body_file" 2>/dev/null ;;
            *) cp "$raw" "$body_file" ;;
        esac
        rm -f "$raw"
    fi
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
    echo "$reply_subject" | grep -qi "^Re:" || reply_subject="Re: ${reply_subject}" 

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
