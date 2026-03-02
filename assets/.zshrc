export ZSH="$HOME/.oh-my-zsh"
export TERMINAL=kitty

ZSH_THEME="agnoster"

plugins=(
    git 
    zsh-autosuggestions 
    zsh-syntax-highlighting 
    fzf
)

source $ZSH/oh-my-zsh.sh

alias ls='ls -lah'
alias explore='nautilus'

[[ -z "$TERMINAL_EMULATOR" ]] && fastfetch
