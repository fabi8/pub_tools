source "$(dirname "${BASH_SOURCE[0]}")/../.common" --show

log_info "To find more serious info about this madness type 'helpx'"
helpx()
{
    echo "===== Dir Navigation ====="
    echo " l                    - ll"
    echo " c                    - cd <param> && ll"
    echo " pu                   - pushd"
    echo " po                   - popd"
    echo " d                    - dirs -l"
    echo " ddirs                - show active bookmarks"
    echo " ctrl+up              - types '../' (see .inputrc)"
    echo " ctrl+bckspc          - removes filename (see .inputrc)"
    echo "===== Dir Search ====="
    echo " fg                   - alias for 'find . | grep'" 
    echo " fgi                  - alias for 'find . | grep -i"
    echo " lsr                  - ls on files, but recursive"
    echo " llr                  - ll on files, but recursive. You can use 'ls' switches lile -t -S"
    echo " ctrl+f               - surrounds search querry with properly escaped 'lsr'"
    echo "===== Dir Other ====="
    echo " wp                   - converts to windows path"
    echo " up                   - converts to unix path"
    echo " mklink               - wrapper for the mklink M$ cmd"
    echo " reset_total_commander_shortcuts"
    echo " reset_file_explorer_shortcuts"
    echo "===== Start/open files ====="
    echo " s [file|program]     - start new instance of program / file opened in default program (start is windows buildtin)"
    echo " o [file|program]     - above in new cmd window (some bat scripts/programs do not like to be run from bash)"
    echo " w [program]          - winpty - interactive command line application written for windows. Example of usage 'w py'"
    echo "===== Other ====="
    echo " g                    - alias for git"
    echo " ps1_toggle           - removes slow git scripts from ps1"
    echo " grepx                - searching in excels"
    echo " sudo [command]       - runs the command in the elevated git-bash"
    echo " cpx                  - copy output to clipboard 'ls | cpx'"
    echo " cpxr                 - copy file to clipboard 'cpxr ./file.txt'"
    echo "===== Plugins ====="
    fzf_helpx
}
#################
# Common functions
#################
# Converts to windows path
wp() {
    [[ "$#" -eq 0 || -z "$@" ]] && return 0
    cygpath -aw "$@"
}

# Converts to unix path
up() {
    [[ "$#" -eq 0 || -z "$@" ]] && return 0
    cygpath -au "$@"
}

#################
# Common aliases
#################
alias g='git'

##################
# List directories
##################

# Make ls ll commands filter (glob expansion) non case sensitive
shopt -s nocaseglob
# Glob **/ will expand recursively
shopt -s globstar

# Make nice colors of files in ll na ls. 
# This modifies LS_COLORS
eval "$(dircolors -b)"
# Adding extra treat for office ;)
export LS_COLORS="$LS_COLORS:*.doc=34:*.docx=34:*.xls=34:*.xlsx=34:*.ppt=34:*.pptx=34:*.odt=34:"

alias ls='ls -F --group-directories-first --color=auto --show-control-chars'
alias l='ls -Al'

##################
# Search files recursively
##################

# strong regexp search
fg() {
    find . | grep "$@"
}

fgi() {
    find . | grep -i "$@"
}

# ls **/ exists, but is super slow, so use
# these to search for some filename quick.
#
# These are slower than above functions, but are using ls
# and are passing additional arguments to the ls.
# So to sort by size -S, by time -t
lsr() {
    local pattern="${1:-*}"
    shift
    find     . -type f -iname "$pattern" -exec ls -F $@ --color=auto {} +
}

llr() {
    local pattern="${1:-*}"
    shift
    lsr "$pattern" $@ -l
}

##################
# Change directories
##################

# Enable auto-cd (changes dir when you type a directory name)
shopt -s autocd  

alias d='dirs -v'

pu(){
    if [ -z "$*" ]; then
        pushd
    else
    pushd "$(up "$*")"
    fi
    l
}

po(){
    popd
    l
}

c(){
    cd "$(up "$*")"
    l
}

# Store pushed directories to cache when exiting
_cleanup_on_exit() {
    dirs -p | tac > ~/.pushd-cache
}
trap _cleanup_on_exit EXIT

# Restore the directories on start
if [ -f ~/.pushd-cache ] && [ "$(dirs -p | wc -l)" -le 1 ]; then
    # Only restore if the current directory stack is empty (protection from resourcing the file)
    it=0
    while IFS= read -r dir; do
        if [ -d "$dir" ]; then
            if [ "$it" -eq 0 ]; then
                cd "$dir" > /dev/null
            else
                pushd "$dir" > /dev/null
            fi
        fi
        let "it++"
    done < ~/.pushd-cache
fi

#####################
# M$ helpers
####################

# Just opens elevated git-bash
sudo(){
    _cleanup_on_exit
    path=$(up $LOCALAPPDATA)/Programs/Git/git-bash.exe
    if [ ! -f "$path" ]; then
        path=$(up $PROGRAMFILES)/Git/git-bash.exe
    fi
    if [ "$#" -gt 0 ]; then
        local cmd="$*; exec bash"
        powershell -Command "Start-Process $(wp $path) -ArgumentList '-c', '\"$cmd\"' -Verb RunAs"
    else
        powershell -Command "Start-Process $(wp $path) -Verb RunAs"
    fi
}

# Copy file/folder to M$ clipboard
cpxr() {
    windows_path=$(wp "$1")
    powershell scb -Path "\"$windows_path"\"
    echo $windows_path " copied to raw clipboard"
}

cpx(){
    if [ -t 0 ]; then
        # Copy whole standard input
        str="$@"
    else
        # Copy whole pipe input
        str=$(cat)
    fi
        powershell scb "\"$str"\"
    num=${#str}
    echo "$num characters copied to text clipboard"
}

alias s='start'
alias w='winpty'
# Opens file passed/piped by default program.
#
# Dependencies:
#      You need to have open.bat on the path.
#
# Note:
#      Seems that pure "start" works same,
#      but at least some .cmd scripts worked better
#      when run from cmd terminal.
o() {
    param=$1
    if [[ -f "$param" ]]; then
        # if is path then convert it to windows path
        wpath=$(wp "$param")
        start open.bat "$wpath"
    else
        start open.bat "$param"
    fi

    # Process piped input (if any)
    if ! [ -t 0 ]; then  # Check if stdin is not a terminal (has piped input)
        while IFS= read -r line; do
            wpath=$(wp "$line")
            start open.bat "$wpath"
        done
    fi
}

# mklink wrapper (cause it is not exe but cmd build-in)
mklink() {
    local opts=()
    local paths=()
    local arg

    for arg in "$@"; do
        case "$arg" in
            /D|/d|/H|/h|/J|/j)
                opts+=("/$arg")
                ;;
            /\?|-*|--*)
                command cmd //c mklink /?
                return $?
                ;;
            *)
                paths+=("$arg")
                ;;
        esac
    done

    command cmd //c mklink "${opts[@]}" "$(wp "${paths[0]}")" "$(wp "${paths[1]}")"
}

# Naming convention for env variables directory shortcuts is
# that the will start with letter d
# and executables with letter e
ddirs(){
    echo -e "\nDirectories d+\n"
    for var in $(set | grep ^d[a-zA-Z\_\s]*=. | sed -e "s/=.*//g"); do
        value="${!var}"
        var=${var:1}
        printf "%-30s %s\n" "$var" "$value"
    done
    echo -e "\nExecutables e+\n"
    for var in $(set | grep ^e[a-zA-Z\_\s]*=. | sed -e "s/=.*//g"); do
        value="${!var}"
        var=${var:1}
        printf "%-30s %s\n" "$var" "$value"
    done
}

_get_bookmarked_directory_names()
{
    set | grep ^d.*=[\/\'] | sed -e "s/=.*//g"
}
# Based on the naming convention (see ddirs) this
# will configure shortcuts in the total commander
reset_total_commander_shortcuts() {
    # Start with an empty array to store the arguments
    local args=()

    # Loop through all environment variables
    for var in $(_get_bookmarked_directory_names); do        
        # Retrieve the variable's value
        value="${!var}"

        # Remove trailing d from the var
        var_stripped=${var#d}

        # Add variable name and value to the arguments array
        args+=("$var_stripped" "$value")
    done

    # Call tc.sh with the constructed arguments
    tc.sh delete
    tc.sh "${args[@]}"
}

# Exports all d variables, and rename them to quickaccess*
reset_file_explorer_shortcuts() {
    for var in $(_get_bookmarked_directory_names); do

        value="${!var}"
        value=$(wp "$value")  # Convert to Windows path
        new_var_name="quickaccess_${var#d}"  # Remove the leading 'd' and add 'quickaccess_'
        echo "Exporting $var as $new_var_name=$value"
        export "$new_var_name=$value"
    done
    
    # This is fancy way how go arround "no script run" policy
    powershell $(cat $(where reset_quickaccess.ps1))
}

#################
# PS1 Speed Toggle
#################

# Store the original complex PS1
PS1_WITH_BRANCH='\[\033]0;$TITLEPREFIX:$PWD\007\]\n\[\033[32m\]\u@\h \[\033[35m\]$MSYSTEM \[\033[33m\]\w\[\033[36m\]`__git_ps1`\[\033[0m\]\n$ '

# Define a simple, fast PS1
PS1_SIMPLE='\[\033]0;$TITLEPREFIX:$PWD\007\]\n\[\033[32m\]\u@\h \[\033[33m\] \w\[\033[0m\]\n$ '

# Function to toggle between simple and complex PS1
ps1_toggle() {
    if [[ "$PS1" == "$PS1_SIMPLE" ]]; then
        export PS1="$PS1_WITH_BRANCH"
        echo "ps1_toggle - git branch"
    else
        export PS1="$PS1_SIMPLE"
        echo "ps1_toggle - simple"
    fi
}

# Call it on start
ps1_toggle