typeset -ga ZSH_MODES
typeset -g ZSH_CURRENT_MODE
typeset -gA ZSH_GENERIC_BUFFER_OPS

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
    [[ -n $ZSH_CURRENT_MODE ]] || return
    (( $+functions[+$ZSH_CURRENT_MODE-zshexit] )) && +$ZSH_CURRENT_MODE-zshexit
}

+zmode-line-init () {
    [[ -n $ZSH_CURRENT_MODE ]] || return
    (( $+functions[+$ZSH_CURRENT_MODE-line-init] )) && +$ZSH_CURRENT_MODE-line-init
}

+zmode-line-finish () {
    [[ -n $ZSH_CURRENT_MODE ]] || return
    (( $+functions[+$ZSH_CURRENT_MODE-line-finish] )) && +$ZSH_CURRENT_MODE-line-finish
}

+zmode-prompt-precmd () {
    [[ -n $ZSH_CURRENT_MODE ]] || return
    (( $+functions[+$ZSH_CURRENT_MODE-prompt-precmd] )) && +$ZSH_CURRENT_MODE-prompt-precmd
}

generic-buffer-op () {
    local cmd=$ZSH_GENERIC_BUFFER_OPS[$WIDGET]
    [[ -z $cmd ]] && zle -M "no such op: $WIDGET" && return

    zle .push-line
    BUFFER=" $cmd"
    zle .accept-line
}
zmode-generic-widgets () {
    local key op
    for key op in ${(kvP)2}; do
        zle -N ${1}-$key generic-buffer-op
        ZSH_GENERIC_BUFFER_OPS[${1}-$key]=$op
    done
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
