#!/bin/bash

var_name="$1"
var_path="$2"

tc_config_path=~/AppData/Roaming/GHISLER/wincmd.ini
# tc_config_path=./wincmd.ini
tc_config_path=$(realpath "$tc_config_path")

delete=0

# Check arguments
if [ "$var_name" = "delete" ]; then
  delete=1
  var_name=""
  var_path=""
else
  if [ -z "$var_name" ] || [ -z "$var_path" ]; then
  echo "Usage: $0 [delete | [<var_name> <var_path>]*]"
  exit 1
  fi
fi

# Compute the start line, line where [DirMenu] starts
start_line=$(grep -n "^\\[DirMenu\\]" "$tc_config_path" | cut -d: -f1)
if [ -z "$start_line" ]; then
  echo "[DirMenu] section not found."
  exit 1
fi

# Compute the end line. Use the next section as stop point
end_line=$(grep -n "^\\[" "$tc_config_path" | grep -A 1 "\\[DirMenu\\]" | tail -n1 | cut -d: -f1)
if [ "$end_line" = "$start_line" ]; then
  end_line=$(wc -l < "$tc_config_path")
fi


if [ "$delete" -eq 0 ]; then
  # Adding an entry/entries
  entry_number=1
  end_line=$((end_line - 1))
  if [ "$end_line" = "$start_line" ]; then
    # echo "Just enter new entry"
    entry_number=1
  else
    # Extract the entry_number from the line at start_line
    entry_line=$(sed -n "${end_line}p" "$tc_config_path")
    # echo "Entry line: $entry_line"
    if [[ $entry_line =~ ^cmd([0-9]+)= ]]; then
      entry_number=$(( ${BASH_REMATCH[1]} + 1 ))
    fi
  fi

  # Create a list from all passed parameters
  params=("$@")

  # Iterate through the list and assign odd to var_name, even to var_path
  lines=""
  for ((i=0; i<${#params[@]}; i+=2)); do
    var_name="${params[i]}"
    var_path="${params[i+1]}"
    
    echo -e "$entry_number \t $var_name \t $var_path"
    win_path_escaped=$(echo $var_path | sed -E 's|^/([a-zA-Z])|\1:|' | sed -e 's|/|\\\\|g')

    lines+="menu${entry_number}=${var_name}\n"
    lines+="cmd${entry_number}=cd $win_path_escaped\n"
    entry_number=$((entry_number + 1))
  done

  # Remove the last newline character
  lines="${lines%\\n}"
  # Endline points to the last line so increment
  end_line=$((end_line + 1))
  sed -i "${end_line}i $lines" "$tc_config_path"

else 
  # Deleting all entries
  start_line=$((start_line + 1))

  if [ "$start_line" -ge "$end_line" ]; then
    echo "Nothing to delte."
  else 
    sed -i.bak "$start_line,$((end_line-1))d" "$tc_config_path"
    echo "Lines $start_line - $end_line after [DirMenu] have been removed. Backup created as $tc_config_path.bak"
  fi
  exit 0
fi

