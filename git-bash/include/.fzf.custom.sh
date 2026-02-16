if [ ! -f ~/.fzf.bash ]; then
    # Clone the repo and install
    pushd ~
    if [ ! -d .fzf ]; then
        echo "Cloning fzf into director $PWD"
        git clone https://github.com/junegunn/fzf.git
    else
        pushd .fzf
        git pull
        popd
    fi
    echo "Calling fzf install"
    .fzf/install
    popd
fi
# Load the fzf
source ~/.fzf.bash

# Add the Fuzzy completion for our aliases 'pu **<TAB>'
# _fzf_setup_completion dir pu
# Issue: This breaks autocompletions of env variables like 'pu $dre<tab>' not expanding

# Fzf for piped intput. e.g. g lga | fzx
alias fzx='fzf --height 50% --ansi --reverse'

# TODO: make the alt+c not running cd (cause we already can cd without it)