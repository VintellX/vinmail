#!/bin/bash

# (might remove this feat if it doesn't work well, but it should be a nice feature)

# reply from an existing .eml...
# basically parse the mail, prefill compose and send it back
# let's check 

# parsed values 
EML_FROM=""
EML_TO=""
EML_CC=""
EML_SUBJECT=""
EML_MSG_ID=""
EML_REFERENCES=""
EML_DATE=""
EML_BODY_FILE=""

# parse the .eml filo
parseEml() {
    local eml_file="$1"

    return 0
}

# keeps parseEml from being too messy, just vars
_setEmlHeader() {
    local header="$1"
    local value="$2"
}

extractEmail() {
    local from="$1"
}

extractName() {
    local from="$1"
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
