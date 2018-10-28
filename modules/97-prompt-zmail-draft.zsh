typeset -gH ZSH_IS_DRAFTDIR

+prompt-draftdir() {
    [[ -n $ZSH_IS_DRAFTDIR ]] || return 0
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

# don't override other styles with our own - add it to the list!
() {
    local hooks
    zstyle -a ':prompt:*:ps1' precmd-hooks hooks
    zstyle ':prompt:*:ps1' precmd-hooks $hooks +prompt-draftdir
}
