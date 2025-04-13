#!/bin/bash
#
######################################################
#   Change File Modification Date by FranzBias (c)   #
#           https://github.com/FranzBias             #
#                                                    #
#       Allows changing the modification date        #
#           of one or more selected files            #
#                                                    #
#           Licensed under the MIT License.          #
#          See LICENSE file for full license.        #
######################################################
#

set -e

# Define translations (only in English)
MSG_NO_FILE="No file selected."
MSG_NO_DATE="No date selected. Exiting."
MSG_NO_TIME="No time selected. Exiting."
MSG_MOD_COMPLETE="Modification complete!"
MSG_BACKUP="Enable file backup."
MSG_DEBUG="Enable debug (log file)."
MSG_YES="Yes"
MSG_NO="No"
MSG_CANCEL="Cancel"
MSG_OPTIONS="Select options:"

# Show options for backup and debug (using checkboxes)
selected_options=$(zenity --list --checklist --title="$MSG_OPTIONS" --text="$MSG_OPTIONS" \
    --column="Select" --column="Option" FALSE "$MSG_BACKUP" FALSE "$MSG_DEBUG" --separator=":")

# Parse the selected options
BACKUP_ENABLED=0
DEBUG_ENABLED=0

# Check if the backup option was selected
if [[ "$selected_options" == *"$MSG_BACKUP"* ]]; then
    BACKUP_ENABLED=1
fi

# Check if the debug option was selected
if [[ "$selected_options" == *"$MSG_DEBUG"* ]]; then
    DEBUG_ENABLED=1
fi

# Check dependencies
for dep in zenity touch; do
    if ! command -v "$dep" &>/dev/null; then
        zenity --error --text="Missing dependency: $dep. Install it with: sudo apt install $dep"
        exit 1
    fi
done

# Prompt for date (force English for Zenity)
selected_date=$(LANG=en_US.UTF-8 zenity --calendar --title="Select the date" --date-format="%Y%m%d")
if [ -z "$selected_date" ]; then
    zenity --error --text="$MSG_NO_DATE"
    exit 1
fi

# Prompt for time (force English for Zenity)
hour_minute=$(LANG=en_US.UTF-8 zenity --list --title="Select the time" --column="Time" "00:00" "00:30" "01:00" "01:30" "02:00" "02:30" "03:00" "03:30" "04:00" "04:30" "05:00" "05:30" "06:00" "06:30" "07:00" "07:30" "08:00" "08:30" "09:00" "09:30" "10:00" "10:30" "11:00" "11:30" "12:00" "12:30" "13:00" "13:30" "14:00" "14:30" "15:00" "15:30" "16:00" "16:30" "17:00" "17:30" "18:00" "18:30" "19:00" "19:30" "20:00" "20:30" "21:00" "21:30" "22:00" "22:30" "23:00" "23:30")
if [ -z "$hour_minute" ]; then
    zenity --error --text="$MSG_NO_TIME"
    exit 1
fi

hour=$(echo "$hour_minute" | cut -d ':' -f1)
minute=$(echo "$hour_minute" | cut -d ':' -f2)
timestamp="${selected_date}${hour}${minute}.00"

# Initialize the debug file only if debug is enabled
if [ "$DEBUG_ENABLED" -eq 1 ]; then
    debug_file="$(dirname "$1")/Debug of change-files-modification-date.txt"
    count=1
    while [ -e "$debug_file" ]; do
        debug_file="$(dirname "$1")/Debug of change-files-modification-date $count.txt"
        ((count++))
    done

    echo "DEBUG LOG - $(date)" > "$debug_file"
fi

# Initialize error log
error_log=""

# Process each selected file
for file in "$@"; do
    # Get only the base name of the file (without the path)
    base_name=$(basename "$file")

    # Get the current file modification time for the debug log
    current_time=$(stat --format=%y "$file")

    # Handle backup file naming with increment
    backup_file="${file}.bkp"
    count=1
    while [ -e "$backup_file" ]; do
        backup_file="${file}.bkp$count"
        ((count++))
    done

    # Create backup file if enabled
    if [ "$BACKUP_ENABLED" -eq 1 ]; then
        cp --preserve=timestamps,mode,ownership "$file" "$backup_file"
    fi

    # Log file modification in the debug file (only file name, no path)
    if [ "$DEBUG_ENABLED" -eq 1 ]; then
        echo "FILE NAME: $base_name" >> "$debug_file"
        echo "DATE AND TIME: $current_time" >> "$debug_file"
    fi

    # Check if the file is read-only
    is_read_only=$(stat -c %a "$file")
    if [ "$is_read_only" -eq 444 ]; then
        # Remove the read-only attribute
        chmod +w "$file"
    fi

    # Attempt to modify the file
    if ! touch -t "$timestamp" -- "$file"; then
        # Log error if the file is read-only or there was any issue
        error_log="$error_log$'\n'File: $file, Error: Read-only or modification failed"
        continue
    fi

    # If it was read-only, restore the read-only permission
    if [ "$is_read_only" -eq 444 ]; then
        chmod 444 "$file"
    fi
done

# Finalize the debug file
if [ "$DEBUG_ENABLED" -eq 1 ]; then
    if [ -z "$error_log" ]; then
        echo "CHANGE(S) DONE!" >> "$debug_file"
    else
        echo -e "ERROR(S) OCCURRED:$error_log" >> "$debug_file"
    fi
fi

zenity --info --text="$MSG_MOD_COMPLETE"
