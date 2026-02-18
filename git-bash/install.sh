# This lines allow to run the script like this '. ./bla/bla/install.sh'
source "$(dirname "${BASH_SOURCE[0]}")/.common"

# Starting
log_info "Starting to copy files into the home."
cp -v $_2home_dir/.* ~

bash_config_start_tag="#START_BASH_CONFIG"
bash_config_end_tag="#END_BASH_CONFIG"

if [ -f ~/.profile ]; then
    log_info "Found ~/.profile. Modifying it. Check if done correctly afterwards."
else
    log_info "~/.profile not found. Creating one."
    touch ~/.profile
fi

# Remove previous configuration
log_info "  Removing previous configuration."
sed -i "/${bash_config_start_tag}/,/${bash_config_end_tag}/d" ~/.profile

log_info "  Adding new configuration."
echo $bash_config_start_tag >> ~/.profile

# Add include directory to the profile if not already on the path
if echo "$PATH" | tr ':' '\n' | grep -Fxq $_include_dir; then
    log_info "  $_include_dir found on the PATH. Not adding it to .profile."
else
    echo "" >> ~/.profile
    echo 'PATH="$PATH:'"$_include_dir"'"' >> ~/.profile
    echo 'export PATH' >> ~/.profile
    log_info "  Added the $_include_dir into the PATH by the .profile."
fi
# Source our fancy bash profile from git location for better convenience

for file in "$_2Profile_dir"/.*; do
    [ -f "$file" ] || continue
    echo 'source '"$file" >> ~/.profile
done

echo $bash_config_end_tag >> ~/.profile

log_success "If no errors visible, we are done!"
