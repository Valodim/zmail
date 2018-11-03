typeset -g ZMAIL_LIST ZMAIL_QUERY ZMAIL_CUSTOM_QUERY ZMAIL_NARROW_QUERY

+zmail-trigger () {
    [[ $PWD == ~/Maildir ]]
}

+zmail-enter () {
    ZMAIL_QUERY=inbox

    local seqdir=${MBLAZE:-$HOME/.mblaze}/seqs
    mkdir -p $seqdir
    export MAILSEQ=$seqdir/$$.$(pwgen 5 1)
    export MAILTAGS=$MAILSEQ.tags
    zmail_load_queries
    zmail_loadseq

    alias -g M='$(mseq .)'
    alias -g MSGID='$(maddr -h message-id -a .)'
    alias -g MID='mid:$(maddr -h message-id -a .)'
    alias -g MTHREAD='thread:{mid:$(maddr -h message-id -a .)}'
    alias -g MQ='$(zmail_current_query)'

    ZMAIL_LIST=1
}

+zmail-leave() {
    [[ -n $MAILSEQ ]] && rm -- $MAILSEQ
    unset MAILSEQ MAILTAGS
    unalias M MSGID MID MQ
}

+zmail-zshexit() {
    if [[ -f $MAILSEQ && $MAILTAGS ]]; then
        rm -- $MAILSEQ $MAILTAGS
        unset MAILSEQ MAILTAGS
    fi
}

+zmail-bindkeys () {
    bindkey '^[j' zmail-move-next-list
    bindkey '^[k' zmail-move-prev-list
    bindkey '^[h' zmail-inbox
    bindkey '^[l' zmail-narrow-to-thread
    bindkey '^[t' zmail-move-top-list
    bindkey '^[e' zmail-move-end-list

    bindkey '^[r' zmail-refresh-list
    bindkey '^[R' zmail-clean-list

    bindkey '^[o' zmail-open
    bindkey '^[O' zmail-open-full
    bindkey '^[a' zmail-open-first-attach
    bindkey '^[A' zmail-enter

    bindkey '^[p' zmail-reply

    bindkey '^[m' zmail-mark-seen-list # like "Mark seen"
    bindkey '^[M' zmail-mark-muted-list # like "Mark Muted"
    bindkey '^[n' zmail-mark-unseen-list # like "New"
    bindkey '^[b' zmail-mark-trash-list # like "garBage"
    bindkey '^[B' zmail-mark-spam-list # like shift-garBage
}

+zmail-line-init() {
    mfix
    if [[ -n $ZMAIL_LIST ]]; then
        ZMAIL_LIST=
        echo
        mfancyscan
        zle .redisplay
    fi
}

+zmail-line-finish() {
    case $BUFFER in
        "")
            ZMAIL_LIST=1
            ;;
        <->)
            BUFFER=" mseq -C $BUFFER"
            ZMAIL_LIST=1
            zle .accept-line
            ;;
    esac
    return 1
}

+zmail-prompt-precmd () {
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

    local mailboxquery=$ZMAIL_QUERY
    if [[ $mailboxquery == custom ]]; then
        mailboxquery='[ '${ZMAIL_CUSTOM_QUERY[1,25]}' ]'
    fi
    if [[ $ZMAIL_NARROW_QUERY == 'thread:{mid:'*'}' ]]; then
        mailboxquery+='/thread'
    fi
    prompt_bits+=( "%K{black}$sep1%F{white} $mailboxquery  $mailnum ${drafticon}%F{black}" )
}

typeset -A zmail_ops
zmail_ops=(
    'open'        'm'
    'open-full'   'MAILFILTER=~/.mblaze/filter-nostrip m'
    'open-first-attach' 'mopenattach'
    'enter'       'menter'

    'refresh'     'mrefresh'
    'clean'       'mclean'

    'reply'       'mreply'

    'move-next'   'mseq -C .+1'
    'move-prev'   'mseq -C .-1'
    'move-top'    'mseq -C 1'
    'move-end'    'mseq -C \$'

    'narrow-to-thread' 'mq -n MTHREAD'
    'inbox'       'mq -n'

    'mark-seen'   'mflag -tS'
    'mark-unseen' 'mflag -ts'
    'mark-trash'  'mflag -T'
    'mark-spam'   'mspam'
    'mark-muted'  'notmuch tag +muted MID'
)
zmail-op-generic() {
    local should_list=
    [[ $WIDGET == *-list ]] && should_list=1
    local op=${${WIDGET#zmail-}%-list}
    local cmd=$zmail_ops[$op]
    [[ -z $cmd ]] && zle -M 'no such op' && return

    zle .push-line
    BUFFER=" $cmd"
    [[ -n $should_list ]] && ZMAIL_LIST=1
    zle .accept-line
}
for i in ${(k)zmail_ops}; do
    zle -N zmail-$i zmail-op-generic
    zle -N zmail-$i-list zmail-op-generic
done

m() {
    mautocrypt -i &>/dev/null

    mshow "$@"
    mflag -S > /dev/null
}

mrefresh() {
    notmuch new --quiet
    zmail_loadseq
}

zmail_load_queries() {
    setopt localoptions extendedglob
    local name query
    typeset -gAH ZMAIL_QUERIES
    ZMAIL_QUERIES=( )
    while read -r line; do
        line=${line%%\#*}
        name=${line%%:*}
        query=${${line#*:}## #}
        [[ -n $name && -n $query ]] || continue
        ZMAIL_QUERIES[$name]=$query
    done < ${MBLAZE:-$HOME/.mblaze}/notmuch-queries
}

zmail_current_query() {
    if [[ $ZMAIL_QUERY == custom ]] && (( $+ZMAIL_CUSTOM_QUERY )); then
        echo -E - $ZMAIL_CUSTOM_QUERY
    else
        echo -E - $ZMAIL_QUERIES[$ZMAIL_QUERY]
    fi
    if [[ -n $ZMAIL_NARROW_QUERY ]]; then
        echo -E - ' AND ' $ZMAIL_NARROW_QUERY
    fi
}

zmail_loadseq() {
    local query="$(zmail_current_query)"

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
        zmail_load_queries
    elif [[ $1 == -n ]]; then
        shift
        ZMAIL_NARROW_QUERY="$@"
        ZMAIL_LIST=1
        zmail_loadseq
    elif (( $# > 0 )); then
        ZMAIL_NARROW_QUERY=
        if (( $+ZMAIL_QUERIES[$1] )); then
            ZMAIL_QUERY=$1
            unset ZMAIL_CUSTOM_QUERY
        else
            typeset -agH ZMAIL_CUSTOM_QUERY
            ZMAIL_CUSTOM_QUERY=( "$@" )
            ZMAIL_QUERY=custom
        fi
        ZMAIL_LIST=1
        zmail_loadseq
    else
        for k v in ${(kv)ZMAIL_QUERIES}; do
            print -- $k: $v
        done
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

zmode-register zmail
