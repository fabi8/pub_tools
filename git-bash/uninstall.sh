source "$(dirname "${BASH_SOURCE[0]}")/.common"
set -x
if [ -f ~/.profile ]; then
    log_info "Removing configuration from ~/.profile."
    sed -i "/${_bash_config_start_tag}/,/${_bash_config_end_tag}/d" ~/.profile
fi

old_dotglob=$(shopt -p dotglob)
shopt -s dotglob
for file in ~/*$_backup_extension; do
    [ -f "$file" ] || continue
    filename="$(basename "$file")"
    filename_orig="${filename%$_backup_extension}"
    log_info "Recovering $filename_orig"
    mv ~/$filename ~/$filename_orig 
done
eval "$old_dotglob"

log_success "If no errors visible, uninstall complete. See you!"