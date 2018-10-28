typeset -gH ZSH_IS_MAILDIR ZSH_MAILDIR_LIST ZSH_MAILDIR_QUERY ZSH_MAILDIR_SAVED_LD_PRELOAD

m() {
    mautocrypt -i &>/dev/null

    mshow "$@"
    (( ${+argv[(r)-X]} || ${+argv[(r)-O]} )) && return

    local -a msgs
    msgs=( "${@:#-*}" )
    mflag -S $msgs > /dev/null
}

mspam() {
    [[ $# == 0 ]] && set -- .
    mrefile -k "$@" Spam
    mflag -T "$@" > /dev/null
}

mclean() {
    local numtrashed
    numtrashed=$(mdirs . | grep -v -E '(Trash|Spam)' | mlist -T | mrefile -v Trash | wc -l)
    echo "Moved $numtrashed msgs to Trash. Reindexing…"
    notmuch new
    ZSH_MAILDIR_LIST=1
}

maildir_chpwd() {
    local is_maildir
    [[ $PWD == ~/Maildir ]] && is_maildir=1 || is_maildir=
    [[ $ZSH_IS_MAILDIR == $is_maildir ]] && return
    ZSH_IS_MAILDIR=$is_maildir
    if [[ $is_maildir == 1 ]]; then
        maildir_enter
    else
        maildir_leave
    fi
}

maildir_enter() {
    ZSH_MAILDIR_SAVED_LD_PRELOAD=$LD_PRELOAD
    # TODO keep? LD_PRELOAD=

    ZSH_MAILDIR_QUERY=inbox

    local seqdir=${MBLAZE:-$HOME/.mblaze}/seqs
    mkdir -p $seqdir
    export MAILSEQ=$seqdir/$$.$(pwgen 5 1)
    export MAILTAGS=$MAILSEQ.tags
    maildir_load_queries
    maildir_loadseq

    maildir_bindkeys
    ZSH_MAILDIR_LIST=1
}

maildir_leave() {
    LD_PRELOAD=$ZSH_MAILDIR_SAVED_LD_PRELOAD
    ZSH_MAILDIR_SAVED_LD_PRELOAD=

    [[ -n $MAILSEQ ]] && rm -- $MAILSEQ
    unset MAILSEQ
    unset MAILTAGS

    bindkey -A maildir-prev-keymap main
    bindkey -D maildir-prev-keymap
}

maildir_zshexit() {
    [[ -n $ZSH_IS_MAILDIR ]] || return
    if [[ -f $MAILSEQ && $MAILTAGS ]]; then
        rm -- $MAILSEQ $MAILSEQ.old $MAILTAGS
        unset MAILSEQ
        unset MAILTAGS
    fi
}

maildir_bindkeys() {
    bindkey -A main maildir-prev-keymap
    bindkey -N maildir-keymap main
    bindkey -A maildir-keymap main

    bindkey '^[j' maildir-move-next-list
    bindkey '^[k' maildir-move-prev-list
    bindkey '^[h' maildir-move-5prev-list
    bindkey '^[l' maildir-move-5next-list
    bindkey '^[t' maildir-move-top-list
    bindkey '^[e' maildir-move-end-list

    bindkey '^[o' maildir-open
    bindkey '^[O' maildir-open-full
    bindkey '^[r' maildir-refresh-list

    bindkey '^[p' maildir-reply

    bindkey '^[m' maildir-mark-seen-list # like "Mark seen'
    bindkey '^[n' maildir-mark-unseen-list # like "New"
    bindkey '^[b' maildir-mark-trash-list # like "garBage"
    bindkey '^[B' maildir-mark-spam-list # like shift-garBage
}

typeset -hA maildir_ops
maildir_ops=(
    'open'        'm'
    'open-full'   'MAILFILTER=~/.mblaze/filter-nostrip m'

    'refresh'     'mrefresh'

    'reply'       'mreply'

    'move-next'   'mseq -C .+1'
    'move-prev'   'mseq -C .-1'
    'move-5next'  'mseq -C .+5'
    'move-5prev'  'mseq -C .-5'
    'move-top'    'mseq -C 1'
    'move-end'    'mseq -C \$'

    'mark-seen'   'mflag -tS'
    'mark-unseen' 'mflag -ts'
    'mark-trash'  'mflag -T'
    'mark-spam'   'mspam'
)
maildir-op-generic() {
    local should_list=
    [[ $WIDGET == *-list ]] && should_list=1
    local op=${${WIDGET#maildir-}%-list}
    local cmd=$maildir_ops[$op]
    [[ -z $cmd ]] && zle -M 'no such op' && return

    zle .push-line
    BUFFER=" $cmd"
    [[ -n $should_list ]] && ZSH_MAILDIR_LIST=1
    zle .accept-line
}
for i in ${(k)maildir_ops}; do
    zle -N maildir-$i maildir-op-generic
    zle -N maildir-$i-list maildir-op-generic
done

mrefresh() {
    notmuch new --quiet
    maildir_loadseq
}

maildir_load_queries() {
    setopt localoptions extendedglob
    local name query
    typeset -gAH ZSH_MAILDIR_QUERIES
    ZSH_MAILDIR_QUERIES=( )
    while read -r line; do
        line=${line%%\#*}
        name=${line%%:*}
        query=${${line#*:}## #}
        [[ -n $name && -n $query ]] || continue
        ZSH_MAILDIR_QUERIES[$name]=$query
    done < ${MBLAZE:-$HOME/.mblaze}/notmuch-queries
}

maildir_current_query() {
    if [[ $ZSH_MAILDIR_QUERY == custom ]] && (( $+ZSH_MAILDIR_CUSTOM_QUERY )); then
        echo -E - $ZSH_MAILDIR_CUSTOM_QUERY
    else
        echo -E - $ZSH_MAILDIR_QUERIES[$ZSH_MAILDIR_QUERY]
    fi
}

maildir_loadseq() {
    local query="$(maildir_current_query)"

    local -a message_tags
    local -A msgs_with_tags
    python =(<<< "
import sys
from notmuch import Database, Query
for msg in Database().create_query(sys.argv[1]).search_messages():
    print(msg.get_filename())
    print(' '.join(msg.get_tags()))
") $query >! $MAILTAGS
    # notmuch search --output=filesandtags $query >! $MAILTAGS
    mthread < $MAILTAGS 2>/dev/null | mseq -S
}

mq() {
    if [[ $1 == -e ]]; then
        ${EDITOR:-vim} ${MBLAZE:-$HOME/.mblaze}/notmuch-queries
        maildir_load_queries
    elif (( $# > 0 )); then
        if (( $+ZSH_MAILDIR_QUERIES[$1] )); then
            ZSH_MAILDIR_QUERY=$1
            unset ZSH_MAILDIR_CUSTOM_QUERY
        else
            typeset -agH ZSH_MAILDIR_CUSTOM_QUERY
            ZSH_MAILDIR_CUSTOM_QUERY=( "$@" )
            ZSH_MAILDIR_QUERY=custom
        fi
        ZSH_MAILDIR_LIST=1
        maildir_loadseq
    else
        for k v in ${(kv)ZSH_MAILDIR_QUERIES}; do
            print -- $k: $v
        done
    fi
}

+line-finish-maildir() {
    [[ -n $ZSH_IS_MAILDIR ]] || return 0
    case $BUFFER in
        "")
            ZSH_MAILDIR_LIST=1
            ;;
        <->)
            BUFFER=" mseq -C $BUFFER"
            ZSH_MAILDIR_LIST=1
            zle .accept-line
            ;;
    esac
    return 1
}

+line-init-maildir() {
    [[ -n $ZSH_IS_MAILDIR ]] || return

    mfix
    if [[ -n $ZSH_MAILDIR_LIST ]]; then
        ZSH_MAILDIR_LIST=
        echo
        mfancyscan
        zle .redisplay
    fi
}

_mq_queries() {
    setopt localoptions extendedglob
    local name query
    typeset -a queries descriptions
    while read -r line; do
        line=${line%%\#*}
        name=${line%%:*}
        query=${${line#*:}## #}
        [[ -n $name && -n $query ]] || continue
        queries+=( $name )
        descriptions+=( $name:$query )
    done < ${MBLAZE:-$HOME/.mblaze}/notmuch-queries

    _describe -t notmuch-queries -V 'Saved Queries' descriptions queries
}

_mq () {
    local ret=1

    (( $#words <= 2 )) && _mq_queries && ret=0
    () {
        local -a words=( $argv )
        _dispatch notmuch notmuch-search-term && ret=0
    } $words[2,$]

    return $ret
}

compdef _mq mq

alias -g M='$(mseq .)'
alias -g MSGID='$(maddr -h message-id -a .)'
alias -g MID='mid:$(maddr -h message-id -a .)'
alias -g MQ='$(maildir_current_query)'

autoload -U add-zsh-hook add-zle-hook-widget
add-zsh-hook chpwd maildir_chpwd
add-zsh-hook zshexit maildir_zshexit
add-zle-hook-widget line-finish +line-finish-maildir
add-zle-hook-widget line-init +line-init-maildir
