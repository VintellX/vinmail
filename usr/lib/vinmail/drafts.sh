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

# ----- Show Drafts -----
showDrafts() {}
