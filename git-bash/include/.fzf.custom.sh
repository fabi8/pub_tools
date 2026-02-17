if [ ! -f ~/.fzf.bash ]; then
    echo "fzf is not installed."
    read -p "Install fzf now? [y/N]: " _fzf_ans
    case "$_fzf_ans" in
        [Yy]*)
            # Clone the repo and install
            pushd ~
            if [ ! -d .fzf ]; then
                echo "Cloning fzf into director $PWD"
                git clone https://github.com/junegunn/fzf.git
            else
                pushd .fzf
                echo "Updating the fzf $PWD"
                git pull
                popd
            fi
            echo "Calling fzf install"
            .fzf/install
            popd
            ;;
        *)
            echo "Skipping fzf installation; fzx and completions will not work."
            return 0 2>/dev/null || exit 0
            ;;
    esac
fi
# Load the fzf
source ~/.fzf.bash

# Add the Fuzzy completion for our aliases 'pu **<TAB>'
# _fzf_setup_completion dir pu
# Issue: This breaks autocompletions of env variables like 'pu $dre<tab>' not expanding

# Fzf for piped intput. e.g. g lga | fzx
alias fzx='fzf --height 50% --ansi --reverse'

# TODO: make the alt+c not running cd (cause we already can cd without it)