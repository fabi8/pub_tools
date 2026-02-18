source "$(dirname "${BASH_SOURCE[0]}")/../.common"

if [ ! -f $_plugins_dir/.fzf.bash ]; then
    read -p "Install fzf now? [y/N]: " _fzf_ans
    case "$_fzf_ans" in
        [Yy]*)
            # Clone the repo and install
            pushd $_plugins_dir >/dev/null 2>&1
            if [ ! -d fzf ]; then
                log_info "fzf: Cloning into director $PWD"
                git clone https://github.com/junegunn/fzf.git
            else
                pushd fzf >/dev/null 2>&1
                log_info "fzf: Updating $PWD"
                git pull
                popd >/dev/null 2>&1
            fi
            log_info "fzf: Calling install. No - Autocompletion, Yes - ctrl+t, No - update .bashrc"
            printf 'n\ny\nn\n' | fzf/install
            # The install creates the .fzf.bash in home. Move it from there.
            log_info ".fzf.bash moved to $_plugins_dir"
            mv ~/.fzf.bash $_plugins_dir
            popd >/dev/null 2>&1
            ;;
        *)
            touch $_plugins_dir/.fzf.bash
            echo "log_error "Fzf not installed remove $_plugins_dir/.fzf.bash and resource ~/.profile to launch installation."" >> $_plugins_dir/.fzf.bash
            ;;
    esac
fi
# Load the fzf
source $_plugins_dir/.fzf.bash

# Add the Fuzzy completion for our aliases 'pu **<TAB>'
# _fzf_setup_completion dir pu
# Issue: This breaks autocompletions of env variables like 'pu $dre<tab>' not expanding

# Fzf for piped intput. e.g. g lga | fzx
alias fzx='fzf --height 50% --ansi --reverse'