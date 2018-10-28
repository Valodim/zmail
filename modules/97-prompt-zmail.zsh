typeset -gH ZSH_IS_MAILDIR

+prompt-maildir() {
    [[ -n $ZSH_IS_MAILDIR ]] || return
    # remove pwd prompt bit
    prompt_bits=( ${prompt_bits:#*%1v*} )

    local mailnum
    mailnum=$(mseq -f | wc -l)

    local -a drafts
    local drafticon=
    drafts=( draft/*(N) )
    if [[ -n $drafts ]]; then
        drafticon=" $#drafts "
    fi

    local mailboxquery=$ZSH_MAILDIR_QUERY
    if [[ $mailboxquery == custom ]]; then
        mailboxquery='[ '${ZSH_MAILDIR_CUSTOM_QUERY[1,25]}' ]'
    fi
    prompt_bits+=( "%K{black}$sep1%F{white} $mailboxquery  $mailnum ${drafticon}%F{black}" )
}

# don't override other styles with our own - add it to the list!
() {
    local hooks
    zstyle -a ':prompt:*:ps1' precmd-hooks hooks
    zstyle ':prompt:*:ps1' precmd-hooks $hooks +prompt-maildir
}
