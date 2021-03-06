typeset -g ZMODE_SHOULD_LIST ZMAIL_QUERY ZMAIL_CUSTOM_QUERY ZMAIL_NARROW_QUERY

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

    ZMODE_SHOULD_LIST=1

    (( $path[(I)*zmail*] == 0 )) && path+=( ~/code/zmail/bin )
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
    bindkey '^[i' zmail-open-html
    bindkey '^[a' zmail-open-first-attach
    bindkey '^[A' zmail-enter
    bindkey '^[E' zmail-edit

    bindkey '^[p' zmail-reply

    bindkey '^[f' zmail-mark-flag-list
    bindkey '^[F' zmail-mark-unflag-list
    bindkey '^[m' zmail-mark-seen-list # like "Mark seen"
    bindkey '^[M' zmail-mark-muted-list # like "Mark Muted"
    bindkey '^[n' zmail-mark-unseen-list # like "New"
    bindkey '^[b' zmail-mark-trash-list # like "garBage"
    bindkey '^[B' zmail-mark-spam-list # like shift-garBage

    for i in {0..9}; bindkey "^[$i" zmail-query-$i
}

+zmail-line-init() {
    mfix
    if [[ -n $ZMODE_SHOULD_LIST ]]; then
        echo
        mfancyscan
        zle .redisplay
    fi
}

+zmail-line-finish() {
    case $BUFFER in
        <->)
            BUFFER=" mseq -C $BUFFER"
            ZMODE_SHOULD_LIST=1
            zle .accept-line
            ;;
    esac
    return 0
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
    'open-html'   'm -A text/html'
    'open-first-attach' 'mopenattach'
    'enter'       'menter'
    'edit'        "${EDITOR:-vim} M"

    'refresh'     'mrefresh'
    'clean'       'mclean'

    'reply'       'mreply'

    'move-next'   'mseq -C .+1'
    'move-prev'   'mseq -C .-1'
    'move-top'    'mseq -C 1'
    'move-end'    'mseq -C \$'

    'narrow-to-thread' 'mq -n MTHREAD'
    'inbox'       'mq -n'

    'mark-flag'   'mflag -tF'
    'mark-unflag' 'mflag -tf'
    'mark-seen'   'mflag -tS'
    'mark-unseen' 'mflag -ts'
    'mark-trash'  'mflag -T'
    'mark-spam'   'mspam'
    'mark-muted'  'notmuch tag +muted MID'
)
for i in {0..9}; zmail_ops+=( "query-$i" "mq $i" )

zmail-op-generic() {
    local should_list=
    [[ $WIDGET == *-list ]] && should_list=1
    local op=${${WIDGET#zmail-}%-list}
    local cmd=$zmail_ops[$op]
    [[ -z $cmd ]] && zle -M 'no such op' && return

    zle .push-line
    BUFFER=" $cmd"
    [[ -n $should_list ]] && ZMODE_SHOULD_LIST=1
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
    typeset -gaH ZMAIL_QUERY_NAMES
    ZMAIL_QUERIES=( )
    ZMAIL_QUERY_NAMES=( )
    while read -r line; do
        line=${line%%\#*}
        name=${line%%:*}
        query=${${line#*:}## #}
        [[ -n $name && -n $query ]] || continue
        ZMAIL_QUERIES[$name]=$query
        ZMAIL_QUERY_NAMES+=$name
    done < ${MBLAZE:-$HOME/.mblaze}/notmuch-queries
}

zmail_current_query() {
    if [[ -n $ZMAIL_NARROW_QUERY ]]; then
        echo '('
    fi
    if [[ $ZMAIL_QUERY == custom ]] && (( $+ZMAIL_CUSTOM_QUERY )); then
        echo -E - $ZMAIL_CUSTOM_QUERY
    else
        echo -E - $ZMAIL_QUERIES[$ZMAIL_QUERY]
    fi
    if [[ -n $ZMAIL_NARROW_QUERY ]]; then
        echo -E - ') AND ' $ZMAIL_NARROW_QUERY
    fi
}

zmail_loadseq() {
    local query="$(zmail_current_query)"

    local -a message_tags
    local -A msgs_with_tags
    python =(<<< "
from __future__ import print_function
import sys
try:
    from notmuch import Database, Query
except:
    print('Could not load notmuch python module (try: pip install notmuch)', file=sys.stderr)
    sys.exit(1)
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
        ZMODE_SHOULD_LIST=1
        zmail_loadseq
    elif (( $# > 0 )); then
        ZMAIL_NARROW_QUERY=
        if [[ $1 == <-> ]]; then
            ZMAIL_QUERY=${ZMAIL_QUERY_NAMES[$1]}
            unset ZMAIL_CUSTOM_QUERY
        elif (( $+ZMAIL_QUERIES[$1] )); then
            ZMAIL_QUERY=$1
            unset ZMAIL_CUSTOM_QUERY
        else
            typeset -agH ZMAIL_CUSTOM_QUERY
            ZMAIL_CUSTOM_QUERY=( "$@" )
            ZMAIL_QUERY=custom
        fi
        ZMODE_SHOULD_LIST=1
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

(( $+functions[compdef] )) && compdef _mq mq

zmode-register zmail
