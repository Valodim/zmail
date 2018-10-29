+zmail-draft-trigger () {
    [[ $PWD == ~/Maildir/draft/* ]]
}

+zmail-draft-bindkeys () {
    bindkey '^[o' zmail-draft-open
    bindkey '^[O' zmail-draft-open-full

    bindkey '^[p' zmail-draft-preview
    bindkey '^[P' zmail-draft-preview-full
}

+zmail-draft-line-finish() {
    case $BUFFER in
        "")
            BUFFER=" vim message.eml"
            ;;
    esac
    return 1
}

+zmail-draft-prompt-precmd () {
    # remove pwd prompt bit
    prompt_bits=( ${prompt_bits:#*%1v*} )

    local from=$(maddr -h from -a ./message.eml)
    local to=( ${(f)"$(maddr -h to:cc -a ./message.eml)"} )
    if (( $#to > 1 )); then
        to[2]="+$(( $#to - 1 ))"
        to[3,$]=( )
    elif (( $#to == 0)); then
        to[1]="?"
    fi

    local address_display
    if zstyle -s ":zmail:draft:$from" address-display address_display; then
        from=$address_display
    fi

    local attachs=( attachments/*(.N) )
    if (( $#attachs == 0 )); then
        attachs=
    elif (( $#attachs == 1 )); then
        attachs="$sep2  "
    else
        attachs="$sep2  $#attachs "
    fi

    prompt_bits+=( "%K{black}$sep1%F{white} $from ﰲ $to $attachs%F{black}" )
}

zmode-register zmail-draft
() {
    local -A ops=(
        'open'        'mshow ./reply.orig'
        'open-full'   'MAILFILTER=~/.mblaze/filter-nostrip mshow ./reply.orig'

        'preview'        'mbuild; mshow ./build/message.mime'
        'preview-full'   'mbuild; MAILFILTER=~/.mblaze/filter-nostrip mshow ./build/message.mime'
    )
    zmode-generic-widgets zmail-draft ops
}
