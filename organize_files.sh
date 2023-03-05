#!/bin/bash
shopt -s globstar nullglob

# Delete files and folders containing "sample" in their name, as well as .jpg, .png, .jpeg, .txt and .nfo files
find . -type f \( -iname \*.sample\* -o -iname \*.jpg -o -iname \*.jpeg -o -iname \*.png -o -iname \*.txt -o -iname \*.nfo \) -delete
find . -type d -iname "*sample*" -exec rm -rf {} +
find . -type d -iname "*proof*" -exec rm -rf {} +

# Find all .mkv files in the current and subdirectories

find . -type f -iname '*.mkv' -print0 | while IFS= read -r -d '' file; do
    # Get the filename without the path
    filename=$(basename "$file")
    echo "Found file $file"

    # Check if there is a "Subs", "subs", "Sub", or "sub" folder in the same directory as the .mkv file
    parent_dir=$(dirname "$file")
    subs_dir=$(find "$parent_dir" -maxdepth 1 -type d -iname "subs" -o -iname "sub")

    # Check if there are files to be renamed first
    if ! [[ "$filename" =~ [sS][0-9][0-9] ]]; then
        echo "File has no valid season and episode number: $filename"
        full_number=$(echo "$file" | rev | find . -type f -name '*.mkv' -exec basename {} \; | grep -oE '[0-9]{3,4}' | grep -v -E '1080|720|265|264' | head -n 1)
        echo "File: $file"
        echo "Full number: $full_number"
        if [[ -n "$full_number" ]]; then
            if [[ ${#full_number} -eq 3 ]]; then
                season_number=$(echo "$full_number" | cut -c 1)
                episode_number=$(echo "$full_number" | cut -c 2,3)
                echo "Season number: $season_number"
                echo "Episode number: $episode_number"
                season_number="S0$season_number"
                episode_number="E$episode_number"
            else
                season_number=$(echo "$full_number" | cut -c 1,2)
                episode_number=$(echo "$full_number" | cut -c 3,4)
                echo "Season number: $season_number"
                echo "Episode number: $episode_number"
                season_number="S$season_number"
                episode_number="E$episode_number"
            fi
            new_filename=$(echo "$file" | sed "s/\([.-]\| \)$full_number\([.-]\| \)/\1${season_number}${episode_number}\2/")
            mv "$file" "$new_filename"
            echo "Renamed $file to $new_filename"
        fi
        echo "Now use the new filename: $new_filename"
        # Check if the file name contains "s0x" (in upper or lowercase)
    if [[ "$new_filename" =~ [sS][0-9][0-9] ]]; then
            echo "File has valid season and episode numbers"
            # Get the folder name (e.g. S01, S02, etc.)
            foldername=$(echo "$new_filename" | grep -o -E "[sS][0-9][0-9]" | tail -n 1 | tr '[:lower:]' '[:upper:]')
        
            # Create the folder if it doesn't exist
            if [ ! -d "$foldername" ]; then
                echo "Creating new folder $foldername"
                mkdir "$foldername"
            fi
        
            if [ "$subs_dir" != "" ]; then
                # Move the entire folder containing the .mkv file and the "subs" folder to the destination folder
                echo "Moving $parent_dir to $foldername"
                mv "$parent_dir" "$foldername"
            else
                # Move the file to the season folder
                echo "Moving $new_filename to $foldername"
                mv "$new_filename" "$foldername"
            fi
        else
            # Move the file to the location where the script was started
            if [ "$subs_dir" != "" ]; then
                mv "$parent_dir" "$(dirname "$0")"
            else
                mv "$new_filename" "$(dirname "$0")"
            fi
        fi
    continue
    fi

    # Check if the file name contains "s0x" (in upper or lowercase)
    if [[ "$filename" =~ [sS][0-9][0-9] ]]; then
        echo "File has valid a season and episode number"
        # Get the folder name (e.g. S01, S02, etc.)
        foldername=$(echo "$filename" | grep -o -E "[sS][0-9][0-9]" | tr '[:lower:]' '[:upper:]')
      
        # Create the folder if it doesn't exist
        if [ ! -d "$foldername" ]; then
            echo "Creating new folder $foldername"
            mkdir "$foldername"
        fi
      
        if [ "$subs_dir" != "" ]; then
            # Move the entire folder containing the .mkv file and the "subs" folder to the destination folder
            echo "Moving $parent_dir to $foldername"
            mv "$parent_dir" "$foldername"
        else
            # Move the file to the season folder
            echo "Moving $file to $foldername"
            mv "$file" "$foldername"
        fi
    else
        # Move the file to the location where the script was started
        if [ "$subs_dir" != "" ]; then
            mv "$parent_dir" "$(dirname "$0")"
        else
            mv "$file" "$(dirname "$0")"
        fi
    fi
done
