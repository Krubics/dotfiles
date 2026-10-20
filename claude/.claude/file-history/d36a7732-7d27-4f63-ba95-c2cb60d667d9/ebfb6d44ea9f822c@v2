#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10
## style-11    style-12    style-13    style-14    style-15
#
## Usage:
##   rofi.sh                      # default: app launcher (drun)
##   rofi.sh file1 file2 dir/*    # show the given files/entries, open the picked one
##   find . -type f | rofi.sh     # show piped lines, print the picked one to stdout
##
## In file/dmenu mode: if the chosen entry is an existing path it is opened with
## xdg-open; otherwise the chosen line is printed to stdout (pipe-friendly).

dir="$HOME/.config/rofi/launchers/type-1"
theme='style-6'

## Logging ---------------------------------------------------------------------
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/rofi"
log_file="$log_dir/rofi-launcher.log"
mkdir -p "$log_dir" 2>/dev/null

log() {
    # $1 = level, $2 = message
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$log_file"
}

## Collect input: positional args first, otherwise piped stdin ----------------
input=""
if [ "$#" -gt 0 ]; then
    input="$(printf '%s\n' "$@")"
elif [ ! -t 0 ]; then
    # stdin is not a terminal (piped/redirected) -> read whatever was given
    input="$(cat)"
fi

## File / dmenu mode -----------------------------------------------------------
if [ -n "$input" ]; then
    count="$(printf '%s\n' "$input" | grep -c .)"
    log INFO "dmenu mode: showing $count entr$([ "$count" = "1" ] && echo y || echo ies)"

    selection="$(printf '%s\n' "$input" | rofi \
        -dmenu \
        -i \
        -p "files" \
        -theme "${dir}/${theme}.rasi")"
    rc=$?

    if [ -z "$selection" ]; then
        log INFO "dmenu closed with no selection (rc=$rc)"
        exit 0
    fi

    if [ -e "$selection" ]; then
        if xdg-open "$selection" >/dev/null 2>&1; then
            log INFO "opened: $selection"
        else
            log ERROR "xdg-open failed for: $selection"
            exit 1
        fi
    else
        # Not an existing path: emit the choice so callers/pipes can consume it
        printf '%s\n' "$selection"
        log WARNING "selection is not an existing path, printed to stdout: $selection"
    fi
    exit 0
fi

## Default: app launcher -------------------------------------------------------
log INFO "drun mode (app launcher)"
rofi \
    -show drun \
    -theme "${dir}/${theme}.rasi"
