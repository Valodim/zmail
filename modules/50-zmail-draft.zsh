typeset -gH ZSH_IS_DRAFTDIR

draftdir_chpwd() {
    local is_maildir
    [[ $PWD == ~/Maildir/draft/* ]] && is_draftdir=1 || is_draftdir=
    [[ $ZSH_IS_DRAFTDIR == $is_draftdir ]] && return
    ZSH_IS_DRAFTDIR=$is_draftdir
    if [[ $is_draftdir == 1 ]]; then
        draftdir_enter
    else
        draftdir_leave
    fi
}

draftdir_enter() {
    draftdir_bindkeys
}

draftdir_leave() {
    bindkey -A draftdir-prev-keymap main
    bindkey -D draftdir-prev-keymap
}

draftdir_bindkeys() {
    bindkey -A main draftdir-prev-keymap
    bindkey -N draftdir-keymap main
    bindkey -A draftdir-keymap main

    # bindkey '^[j' maildir-move-next-list
    # bindkey '^[k' maildir-move-prev-list
    # bindkey '^[h' maildir-move-5prev-list
    # bindkey '^[l' maildir-move-5next-list
    # bindkey '^[t' maildir-move-top-list
    # bindkey '^[e' maildir-move-end-list

    bindkey '^[o' draftdir-open
    bindkey '^[O' draftdir-open-full

    bindkey '^[p' draftdir-preview
    bindkey '^[P' draftdir-preview-full
}

typeset -hA draftdir_ops
draftdir_ops=(
    'open'        'm ./reply.orig'
    'open-full'   'MAILFILTER=~/.mblaze/filter-nostrip m ./reply.orig'

    'preview'        'mbuild; m ./build/message.mime'
    'preview-full'   'mbuild; MAILFILTER=~/.mblaze/filter-nostrip m ./build/message.mime'
)
draftdir-op-generic() {
    local op=${${WIDGET#draftdir-}%-list}
    local cmd=$draftdir_ops[$op]
    [[ -z $cmd ]] && zle -M 'no such op' && return

    zle .push-line
    BUFFER=" $cmd"
    zle .accept-line
}
for i in ${(k)draftdir_ops}; do
    zle -N draftdir-$i draftdir-op-generic
    zle -N draftdir-$i-list draftdir-op-generic
done

+line-finish-draftdir() {
    [[ -n $ZSH_IS_DRAFTDIR ]] || return 0
    case $BUFFER in
        "")
            BUFFER=" vim message.eml"
            ;;
    esac
    return 1
}

autoload -U add-zsh-hook add-zle-hook-widget
add-zsh-hook chpwd draftdir_chpwd
add-zle-hook-widget line-finish +line-finish-draftdir
