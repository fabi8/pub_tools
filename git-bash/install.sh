# This lines allow to run the script like this '. ./bla/bla/install.sh'
source "$(dirname "${BASH_SOURCE[0]}")/.common"

old_dotglob=$(shopt -p dotglob)
shopt -s dotglob

log_info "Starting to copy files into the home."
for file in "$_2home_dir"/*; do
    [ -f "$file" ] || continue
    filename="$(basename "$file")"
    if [ -f ~/$filename ]; then
        if [ ! -f ~/$filename$_backup_extension ]; then
            log_info "Backing up $filename"
            mv ~/$filename ~/$filename$_backup_extension
        fi
    fi
    cp -v $file ~
done

if [ -f ~/.profile ]; then
    log_info "Found ~/.profile. Modifying it. Check if done correctly afterwards."
else
    log_info "~/.profile not found. Creating one."
    touch ~/.profile
fi

log_info "  Removing previous configuration."
sed -i "/${_bash_config_start_tag}/,/${_bash_config_end_tag}/d" ~/.profile

log_info "  Adding new configuration."
echo $_bash_config_start_tag >> ~/.profile

# Add include directory to the profile if not already on the path
if echo "$PATH" | tr ':' '\n' | grep -Fxq $_include_dir; then
    log_info "  $_include_dir found on the PATH. Not adding it to .profile."
else
    echo "" >> ~/.profile
    echo 'PATH="$PATH:'"$_include_dir"'"' >> ~/.profile
    echo 'export PATH' >> ~/.profile
    log_info "  Added the $_include_dir into the PATH by the .profile."
fi

# Source our fancy scripts each time git-bash is opened
for file in "$_2Profile_dir"/*; do
    [ -f "$file" ] || continue
    echo 'source '"$file" >> ~/.profile
done

log_info "Adding bookmark drepo_gitbash"
echo "drepo_gitbash=$_this_repo_dir" >> ~/.profile

echo $_bash_config_end_tag >> ~/.profile
eval "$old_dotglob"  

log_success "If no errors visible, we are done!"
