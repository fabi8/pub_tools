source "$(dirname "${BASH_SOURCE[0]}")/.common"
if git status | grep -q "Changes not staged for commit:"; then
    echo "There are modified files! Stage them first."
else

    old_dotglob=$(shopt -p dotglob)
    shopt -s dotglob

    for file in "$_2home_dir"/*; do
        [ -f "$file" ] || continue
        filename="$(basename "$file")"
        if [ -f ~/$filename ]; then
            if diff -q $file ~/$filename > /dev/null; then
                log_info "$filename no change."
            else
                log_info "$filename different."
                cp ~/$filename $_2home_dir
            fi
        fi
        cp -v $file ~
    done

    eval "$old_dotglob" 
fi
