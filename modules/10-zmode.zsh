typeset -gHa ZSH_MODES
typeset -gH ZSH_CURRENT_MODE
typeset -gHA ZSH_GENERIC_BUFFER_OPS
typeset -gH ZMODE_SHOULD_LIST

zmode-register () {
    ZSH_MODES+=( $1 )
}

+zmode-chpwd () {
    local -a triggered_modes
    local has_mode=0
    local mode
    [[ -n $ZSH_CURRENT_MODE ]] && has_mode=1
    for mode in $ZSH_MODES; do
        +${mode}-trigger && triggered_modes+=( $mode )
    done

    if [[ -z $triggered_modes ]]; then
        local mode=$ZSH_CURRENT_MODE
        ZSH_CURRENT_MODE=
        zmode-leave $mode
        return
    fi

    if (( $#triggerd_modes > 1 )); then
        # priority?
        echo "Conflicting modes: ${(j: / :)enabled_modes}" >&2
        return
    fi

    # compare current to single triggered mode
    local new_mode=$triggered_modes[1] old_mode=$ZSH_CURRENT_MODE
    [[ $new_mode == $old_mode ]] && return
    ZSH_CURRENT_MODE=$new_mode

    # leave old mode, enter new mode
    [[ -n $old_mode ]] && zmode-leave $old_mode
    zmode-enter $new_mode
}

zmode-enter () {
    (( $+functions[+$1-enter] )) && +$1-enter

    if (( $+functions[+${1}-bindkeys] )); then
        bindkey -A main zmode-prev-keymap
        bindkey -N zmode-keymap main
        bindkey -A zmode-keymap main

        +${1}-bindkeys
    fi
}

zmode-leave () {
    if bindkey -l zmode-keymap &> /dev/null; then
        bindkey -A zmode-prev-keymap main
        bindkey -D zmode-prev-keymap
        bindkey -D zmode-keymap
    fi

    (( $+functions[+${1}-leave] )) && +${1}-leave
}

+zmode-zshexit () {
    [[ -n $ZSH_CURRENT_MODE ]] || return 0
    (( $+functions[+$ZSH_CURRENT_MODE-zshexit] )) && +$ZSH_CURRENT_MODE-zshexit
    return 0
}

+zmode-line-init () {
    [[ -n $ZSH_CURRENT_MODE ]] || return 0
    (( $+functions[+$ZSH_CURRENT_MODE-line-init] )) && +$ZSH_CURRENT_MODE-line-init
    ZMODE_SHOULD_LIST=
    return 0
}

+zmode-line-finish () {
    integer ret=0
    [[ -n $ZSH_CURRENT_MODE ]] || return 0
    if (( $+functions[+$ZSH_CURRENT_MODE-line-finish] )); then
        +$ZSH_CURRENT_MODE-line-finish || ret=1
    fi
    if (( ret == 0 )) && [[ -z $BUFFER ]]; then
        ZMODE_SHOULD_LIST=1
    fi
    return 0
}

+zmode-prompt-precmd () {
    [[ -n $ZSH_CURRENT_MODE ]] || return 0
    (( $+functions[+$ZSH_CURRENT_MODE-prompt-precmd] )) && +$ZSH_CURRENT_MODE-prompt-precmd
    return 0
}

zmode-generic-widgets () {
    local key op
    for key op in ${(kvP)2}; do
        zle -N ${1}-$key generic-buffer-op
        ZSH_GENERIC_BUFFER_OPS[${1}-$key]=$op
    done
}

generic-buffer-op () {
    local cmd=$ZSH_GENERIC_BUFFER_OPS[$WIDGET]
    [[ -z $cmd ]] && zle -M "no such op: $WIDGET" && return

    zle .push-line
    BUFFER=" $cmd"
    zle .accept-line
}

zmode-generic-sub() {
    setopt localoptions extendedglob
    local sub=${WIDGET##*-}
    local -a pieces=( ${(z)BUFFER} )
    if [[ $pieces[1] != $sub ]]; then
        BUFFER="$pieces[1] $sub "
        CURSOR=$#BUFFER
    fi

    (( $+functions[$WIDGET-hook] )) && $WIDGET-hook
}

zmode-generic-flag() {
    setopt localoptions extendedglob
    local flag=${(M)WIDGET%%-##[^-]##}
    local -a pieces=( ${(z)BUFFER} )
    if (( $+pieces[(r)$flag])); then
        BUFFER=${BUFFER/ $flag/}
    else
        BUFFER="${BUFFER% } $flag "
        CURSOR=$#BUFFER
    fi
}

zmode-generic-param() {
    setopt localoptions extendedglob
    local arg=${(M)WIDGET%%-##[^-]##}
    local quoted=
    [[ $WIDGET = *-quoted-* ]] && quoted=1

    local -a pieces=( ${(z)BUFFER} )
    local pos=$pieces[(i)$arg]
    if (( pos < $#pieces )); then
        CURSOR=$(( ${(c)#${pieces[1,pos+1]}} -1 ))
        [[ $BUFFER[CURSOR-1] == (\'|\") ]] && CURSOR+=-1
    else
        BUFFER="${BUFFER% } $arg "
        if [[ -n $quoted ]]; then
            BUFFER+="''"
            CURSOR=$(( $#BUFFER - 1 ))
        else
            CURSOR=$#BUFFER
        fi
    fi

    zle .send-break
}

autoload -U add-zsh-hook add-zle-hook-widget
add-zsh-hook chpwd +zmode-chpwd
add-zsh-hook zshexit +zmode-zshexit
add-zle-hook-widget line-finish +zmode-line-finish
add-zle-hook-widget line-init +zmode-line-init
# don't override other styles with our own - add it to the list!
() {
    local hooks
    zstyle -a ':prompt:*:ps1' precmd-hooks hooks
    zstyle ':prompt:*:ps1' precmd-hooks $hooks +zmode-prompt-precmd
}
