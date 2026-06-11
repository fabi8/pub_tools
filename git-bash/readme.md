# How to use this
Use collect.sh to get new files from system for commit.
Use install.sh to install the files.

# Known issues
* grepx.exe requires a ton of dependencies :(
* reset_total_commander_shortcuts - not working with new installation of TC. The config file is in different location.
* cpx : when the piped input or input from the parameter contains backslashes or quotes, it interfere with bash and in the clipboard ends up with unexpected result

# New ideas
* cpxr: could by default copy onedrive link, if the file passed is located in onedrive
* 'o' could change directory to the paramerer before it runs it.
* There could be one command instead of 3 - "s o w" 

* Add commands "plugin-list" "plugin-install <name>" "plugin-uninstall <name>" and rework the fzf installation. It is quite hard to follow.

* Command for copy file/folder out of clipboard would be nice.
* Add support for wsl