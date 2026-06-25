#!/bin/bash
# VinMail
# "Bash-ing out an email."

DRAFTS_DIR="$VINMAIL_DIR/drafts"

# ----- Initialize Drafts Directory -----
initDrafts() {
    mkdir -p "$DRAFTS_DIR"
}

# ----- Drafts Count -----
draftCount() {
    local count
    count=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.draft" 2>/dev/null | wc -l | tr -d ' ')
    echo "${count:-0}"
}

# ----- Save Draft -----
saveDraft() {
    local to="$1" cc="$2" bcc="$3" subject="$4"
    local gpg_sign="$5" gpg_key="$6"
    local body_file="$7"
    local _attachments_name="$8"
 
    initDrafts
 
    local timestamp; timestamp=$(date +%s)
    local draft_base="$DRAFTS_DIR/draft_${timestamp}"
    local draft_file="${draft_base}.draft"
    local body_dest="${draft_base}.body"
 
    # sving body to perm file alongside draft
    cp "$body_file" "$body_dest" || {
        err "Could not save draft body."; sleep 1; return 1
    }
 
    local _attachments=()
    eval "_attachments=(\"\${${_attachments_name}[@]+\${${_attachments_name}[@]}}\")"
 
    # join; sep -> |
    local attachments_str=""
    if [[ ${#_attachments[@]} -gt 0 ]]; then
        attachments_str=$(printf '%s|' "${_attachments[@]}")
        attachments_str="${attachments_str%|}"
    fi
 
    cat > "$draft_file" <<DRAFT
TO=${to}
CC=${cc}
BCC=${bcc}
SUBJECT=${subject}
GPG_SIGN=${gpg_sign}
GPG_KEY=${gpg_key}
ATTACHMENTS=${attachments_str}
BODY_FILE=${body_dest}
SAVED=$(date "+%Y-%m-%d %H:%M:%S")
DRAFT
 
    ok "Draft saved."; sleep 1
}

# ----- Load Draft -----
loadDraft() {
    local draft_file="$1"
    [[ ! -f "$draft_file" ]] && { err "Draft not found."; return 1; }
 
    local line key value
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        case "$key" in
            TO)          eval "DRAFT_TO=\"\$value\""          ;;
            CC)          eval "DRAFT_CC=\"\$value\""          ;;
            BCC)         eval "DRAFT_BCC=\"\$value\""         ;;
            SUBJECT)     eval "DRAFT_SUBJECT=\"\$value\""     ;;
            GPG_SIGN)    eval "DRAFT_GPG_SIGN=\"\$value\""    ;;
            GPG_KEY)     eval "DRAFT_GPG_KEY=\"\$value\""     ;;
            ATTACHMENTS) eval "DRAFT_ATTACHMENTS=\"\$value\"" ;;
            BODY_FILE)   eval "DRAFT_BODY_FILE=\"\$value\""   ;;
            SAVED)       eval "DRAFT_SAVED=\"\$value\""       ;;
        esac
    done < "$draft_file"
    return 0
}

# ----- Delete Draft -----
deleteDraft() {
    local draft_file="$1"
    local body_file="${draft_file%.draft}.body"
    rm -f "$draft_file" "$body_file"
}

# ----- draft label for array -----
_draftLabel() {
    local draft_file="$1"
    local subject saved
    subject=$(grep "^SUBJECT=" "$draft_file" | cut -d'=' -f2-)
    saved=$(grep "^SAVED=" "$draft_file" | cut -d'=' -f2-)
    subject="${subject:-(no subject)}"
    printf "%-35s %s" "$subject" "$saved"
}
 
# ----- drafto renderer -----
_draft_render() {
    local i="$1" taken="$2"
    local label="${DRAFT_LABELS[$i]}"
    if [[ $i -eq $taken ]]; then
        echo -e "  ${GREEN}▶  ${BOLD}${label}${RESET}"
    else
        echo -e "     ${label}"
    fi
}
# ----- Show Drafts -----
showDrafts() {
    initDrafts

    while true; do
        local DRAFT_FILES=()
        while IFS= read -r -d '' f; do
            DRAFT_FILES+=("$f")
        done < <(find "$DRAFTS_DIR" -maxdepth 1 -name "*.draft" -print0 2>/dev/null | sort -z)

        if [[ ${#DRAFT_FILES[@]} -eq 0 ]]; then
            echoHeader "Drafts"
            echo -e "  ${DIM}No drafts saved.${RESET}"
            pressAnyKey; return
        fi

        local DRAFT_LABELS=()
        for f in "${DRAFT_FILES[@]}"; do
            DRAFT_LABELS+=("$(_draftLabel "$f")")
        done

        local taken=0 count=${#DRAFT_FILES[@]}
        tput civis 2>/dev/null || true

        while true; do
            echoHeader "Drafts"
            echo -e "  ${DIM}↑/k up · ↓/j down · Enter open · d delete · q back${RESET}\n"
            for i in "${!DRAFT_LABELS[@]}"; do
                if [[ $i -eq $taken ]]; then
                    echo -e "  ${GREEN}▶  ${BOLD}${DRAFT_LABELS[$i]}${RESET}"
                else
                    echo -e "     ${DRAFT_LABELS[$i]}"
                fi
            done

            readKeyboardo
            case "$KEY" in
                UP|k)
                    taken=$(( taken - 1 ))
                    [[ $taken -lt 0 ]] && taken=$(( count - 1 ))
                    ;;
                DOWN|j)
                    taken=$(( taken + 1 ))
                    [[ $taken -ge $count ]] && taken=0
                    ;;
                d|D)
                    tput cnorm 2>/dev/null || true
                    echo -ne "\n  ${RED}Delete this draft? [y/N]: ${RESET}"
                    local confirm; read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        deleteDraft "${DRAFT_FILES[$taken]}"
                        ok "Draft deleted."; sleep 1
                    fi
                    break
                    ;;
                ""|$'\n')
                    tput cnorm 2>/dev/null || true
                    local selected_draft="${DRAFT_FILES[$taken]}"

                    while true; do
                        echoHeader "Draft"
                        echo -e "  $(_draftLabel "$selected_draft")\n"
                        echo -e "  ${BOLD}[o]${RESET} Open and continue editing"
                        echo -e "  ${BOLD}[d]${RESET} Delete draft"
                        echo -e "  ${BOLD}[q]${RESET} Back to drafts"
                        echo -ne "\n  Choice: "; local c; read -r c

                        case "$c" in
                            o|O)
                                sendMailFromDraft "$selected_draft"
                                break
                                ;;
                            d|D)
                                echo -ne "  ${RED}Delete this draft? [y/N]: ${RESET}"
                                local dc; read -r dc
                                if [[ "$dc" =~ ^[Yy]$ ]]; then
                                    deleteDraft "$selected_draft"
                                    ok "Draft deleted."; sleep 1
                                    break
                                fi
                                ;;
                            q|Q) break ;;
                            *) warn "Enter o, d, or q." ;;
                        esac
                    done
                    break
                    ;;
                q|Q)
                    tput cnorm 2>/dev/null || true
                    return
                    ;;
            esac
        done
    done
}
