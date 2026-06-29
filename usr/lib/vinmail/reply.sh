#!/bin/bash

# (might remove this feat if it doesn't work well, but it should be a nice feature)

# reply from an existing .eml...
# basically parse the mail, prefill compose and send it back
# let's check 


# ----- Parse EML -----
parseEml() {
    local eml_file="$1"

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
    case "${header,,}" in
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

# quote the original body
#
# On ...
# > hello
# > world
quoteBody() {
    local body_file="$1"
    local from="$2"
    local date="$3"


    return 0
}

# how it should be:
# user picks an .eml
# parse it
# ask reply / reply all
# build headers
# open compose with quote already there
# till now i can think of it only, let's see :/
replyToMail() {

    # active account checks...

    # ask for eml

    # parse it

    # build:
    #   to
    #   subject
    #   in-reply-to
    #   references

    # quote body

    # compose loop

    return 0
}
