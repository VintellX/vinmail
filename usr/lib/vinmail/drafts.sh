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
saveDraft() {}

# ----- Load Draft -----
loadDraft() {}

# ----- Delete Draft -----
deleteDraft() {
    local draft_file="$1"
    local body_file="${draft_file%.draft}.body"
    rm -f "$draft_file" "$body_file"
}

# ----- Show Drafts -----
showDrafts() {}
