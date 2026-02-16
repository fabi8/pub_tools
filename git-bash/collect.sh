if git status | grep -q "modified:"; then
    echo "There are modified files!"
else
    cp ~/.bash_profile 2home
    cp ~/.inputrc 2home
    cp ~/.gitconfig 2home
    cp ~/.minttyrc 2home
fi
