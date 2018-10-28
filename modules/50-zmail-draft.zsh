+zmail-draft-trigger () {
    [[ $PWD == ~/Maildir/draft/* ]]
}

+zmail-draft-bindkeys () {
    bindkey '^[o' zmail-draft-open
    bindkey '^[O' zmail-draft-open-full

    bindkey '^[p' zmail-draft-preview
    bindkey '^[P' zmail-draft-preview-full
}

typeset -A zmail_draft_ops
zmail_draft_ops=(
    'open'        'm ./reply.orig'
    'open-full'   'MAILFILTER=~/.mblaze/filter-nostrip m ./reply.orig'

    'preview'        'mbuild; m ./build/message.mime'
    'preview-full'   'mbuild; MAILFILTER=~/.mblaze/filter-nostrip m ./build/message.mime'
)
zmail-draft-op-generic() {
    local op=${${WIDGET#zmail-draft-}%-list}
    local cmd=$zmail-draft_ops[$op]
    [[ -z $cmd ]] && zle -M 'no such op' && return

    zle .push-line
    BUFFER=" $cmd"
    zle .accept-line
}
for i in ${(k)zmail-draft_ops}; do
    zle -N zmail-draft-$i zmail-draft-op-generic
    zle -N zmail-draft-$i-list zmail-draft-op-generic
done

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
