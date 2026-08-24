#!/usr/bin/env bash
#
# organize_files.sh — sort .mkv episodes into S01/S02/... folders
#
# Usage:
#   ./organize_files.sh --dry-run    # show what would happen, change nothing
#   ./organize_files.sh              # do it
#
# Run it from the directory that holds the release folders.

set -uo pipefail

DRY=0
case "${1:-}" in
    -n|--dry-run) DRY=1 ;;
    -h|--help)    sed -n '2,10p' "$0"; exit 0 ;;
    "")           ;;
    *)            echo "unknown option: $1" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*"; }
run() {
    if (( DRY )); then
        printf 'DRY  %s\n' "$*"
    else
        "$@"
    fi
}

# Everything happens relative to where we were started, not to where the
# script file happens to live.
root=$PWD

# --------------------------------------------------------------------------
# 1. Clean out junk
# --------------------------------------------------------------------------
if (( DRY )); then
    say "DRY  would remove sample/proof dirs and junk files:"
    find . -depth -type d \( -iname '*sample*' -o -iname '*proof*' \) -printf '     %p\n'
    find . -type f \( -iname '*sample*' -o -iname '*.jpg' -o -iname '*.jpeg' \
                   -o -iname '*.png' -o -iname '*.txt' -o -iname '*.nfo' \) -printf '     %p\n'
else
    # -depth so we delete children before parents (no "No such file" spam)
    find . -depth -type d \( -iname '*sample*' -o -iname '*proof*' \) -exec rm -rf {} +
    find . -type f \( -iname '*sample*' -o -iname '*.jpg' -o -iname '*.jpeg' \
                   -o -iname '*.png' -o -iname '*.txt' -o -iname '*.nfo' \) -delete
fi

# --------------------------------------------------------------------------
# 2. Collect the file list ONCE, before anything moves
#    (the original streamed find into the loop and then moved whole parent
#     directories out from under it)
# --------------------------------------------------------------------------
mapfile -d '' files < <(find . -type f -iname '*.mkv' -print0)

if (( ${#files[@]} == 0 )); then
    say "No .mkv files found."
    exit 0
fi

# --------------------------------------------------------------------------
# 3. Season/episode detection
# --------------------------------------------------------------------------
season=''; episode=''; bare_num=''

parse_se() {
    local base=$1 cleaned n
    season=''; episode=''; bare_num=''

    # Case A: already tagged, e.g. S01E03 / s1e3 / S01.E03
    if [[ $base =~ [Ss]([0-9]{1,2})[[:space:]._-]*[Ee]([0-9]{1,3}) ]]; then
        season=$((10#${BASH_REMATCH[1]}))
        episode=$((10#${BASH_REMATCH[2]}))
        return 0
    fi

    # Case B: bare number, e.g. 103 -> S01E03, 1204 -> S12E04.
    # Strip the tokens that look like episode codes but are not, BEFORE
    # searching. This is what turned "...2022.1204..." into S20E22 before.
    cleaned=${base%.*}
    cleaned=$(sed -E '
        s/(^|[^0-9])(19|20)[0-9]{2}([^0-9]|$)/\1\3/g
        s/(2160|1080|720|576|480)[pi]?//gI
        s/[xh]?26[45]//gI
        s/(DDP?|AAC|AC3|DTS|MP3)[0-9.]*//gI
    ' <<<"$cleaned")

    n=$(grep -oE '(^|[^0-9])[0-9]{3,4}([^0-9]|$)' <<<"$cleaned" \
        | grep -oE '[0-9]{3,4}' | head -n 1)
    [[ -z $n ]] && return 1

    bare_num=$n
    if (( ${#n} == 3 )); then
        season=$((10#${n:0:1})); episode=$((10#${n:1:2}))
    else
        season=$((10#${n:0:2})); episode=$((10#${n:2:2}))
    fi
    return 0
}

# --------------------------------------------------------------------------
# 4. Main loop
# --------------------------------------------------------------------------
for file in "${files[@]}"; do
    # A previous iteration may have moved this file's parent directory.
    [[ -e $file ]] || { say "skip (already moved): $file"; continue; }

    # Junk that step 1 removes (or would remove, in dry-run mode)
    case ${file,,} in
        *sample*|*proof*) continue ;;
    esac

    base=$(basename "$file")
    dir=$(dirname "$file")
    say "Found: $file"

    if ! parse_se "$base"; then
        say "  !! no season/episode found — leaving it where it is"
        continue
    fi

    tag=$(printf 'S%02dE%02d' "$season" "$episode")
    folder=$(printf 'S%02d' "$season")
    say "  -> $tag"

    # Rename only if we inferred the numbers from a bare code
    if [[ -n $bare_num ]]; then
        newbase=${base/"$bare_num"/$tag}
        if [[ $newbase != "$base" ]]; then
            run mv -n -- "$file" "$dir/$newbase"
            file="$dir/$newbase"
            base=$newbase
        fi
    fi

    # Is there a Subs/Sub/Subtitles folder next to the file?
    # Note the parentheses — without them the -type d only applied to the
    # first -iname, so a *file* called "sub" counted as a subtitle folder.
    subs=''
    if [[ $dir != "." ]]; then
        subs=$(find "$dir" -maxdepth 1 -type d \
                    \( -iname 'subs' -o -iname 'sub' -o -iname 'subtitles' \) \
                    -print -quit)
    fi

    run mkdir -p -- "$folder"

    if [[ -n $subs && $dir != "." && $dir != "./$folder" ]]; then
        say "  moving folder $dir -> $folder/"
        run mv -n -- "$dir" "$folder/"
    else
        say "  moving file $base -> $folder/"
        run mv -n -- "$file" "$folder/"
    fi
done

# --------------------------------------------------------------------------
# 5. Tidy up
# --------------------------------------------------------------------------
if (( DRY )); then
    say "DRY  would delete empty directories"
else
    find . -mindepth 1 -type d -empty -delete
fi

# The original ended with `rm "$0"`, which deletes the script after one run.
# Left out on purpose — uncomment if you really want that.
# rm -- "$0"
