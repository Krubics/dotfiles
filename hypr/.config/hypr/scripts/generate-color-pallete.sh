#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"
echo "Current directory: $(pwd)"

cmd=("matugen"
    "image"
    "-t" "scheme-rainbow"
    "--dry-run"
    "--source-color-index" "0"
    "--json" "hex"
)

mkdir -p ../screenshots ../matugen-colors

wp_dir="/home/krubics/.config/hypr/wallpapers"
for wp in "$wp_dir"/*; do
    wp_file="${wp##*/}"
    wp_stem="${wp_file%%.*}"
    if [[ $wp == *.jpg || $wp == *.png ]]; then
        "${cmd[@]}" $wp > ../matugen-colors/$wp_stem.json
    elif [[ $wp == *.mp4 ]]; then
        if [ ! -f "../screenshots/$wp_stem.png" ]; then
            ffmpeg -y -ss 00:00:10 -i "$wp" -vframes 1 ../screenshots/$wp_stem.png
        fi
        "${cmd[@]}" ../screenshots/$wp_stem.png > ../matugen-colors/$wp_stem.json
    else
        echo "Unsupported file type: $wp"
    fi
done
