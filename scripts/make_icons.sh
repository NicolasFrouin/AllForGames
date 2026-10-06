#!/usr/bin/env bash
# Regenerates the app icons of every platform from the SVG sources in assets/icon/:
#   icon.svg         the full icon (web, Android before 8, Windows from 48 px, macOS with padding and shadow)
#   icon_small.svg   the card alone, for 16 to 32 px (web favicon, small Windows sizes)
#   foreground.svg   Android adaptive layers (108 dp canvas)
#   background.svg   the felt alone; under icon.svg, it fills its corners: the full-bleed iOS and maskable web icons
#   monochrome.svg   Android 13 themed icon
# Renders PNG sources in build/icon/, runs flutter_launcher_icons for Android (flutter_launcher_icons.yaml), then
# writes the iOS, macOS, web and Windows icons over the existing files (their Contents.json and manifest stay).
# Needs rsvg-convert and ImageMagick 7 (brew install librsvg imagemagick).
set -euo pipefail
cd "$(dirname "$0")/.."

src=assets/icon
out=build/icon
mkdir -p "$out"

art() { sed -n '/<!-- art -->/,/<!-- \/art -->/s/^ *//p' "$src/$1.svg"; }
if ! diff <(art icon) <(art foreground) >/dev/null; then
  echo "The art of icon.svg and foreground.svg differ: keep them the same." >&2
  exit 1
fi

# render <svg name> <size px> <png>
render() { rsvg-convert -w "$2" -h "$2" "$src/$1.svg" -o "$3"; }
# resize <png> <size px> <png>; -strip keeps the output the same from run to run (no dates).
resize() { magick "$1" -resize "$2x$2" -depth 8 -strip "$3"; }

for name in icon foreground background monochrome; do
  render "$name" 1024 "$out/$name.png"
done

magick "$out/background.png" "$out/icon.png" -composite -alpha off -strip "$out/icon_full_bleed.png"

# macOS: the icon at 824 px on a 1024 px canvas with a soft shadow (Apple's grid).
render icon 824 "$out/icon_824.png"
magick -size 1024x1024 xc:none \
  \( "$out/icon_824.png" -fill black -colorize 100 -channel A -evaluate multiply 0.35 +channel \) \
  -geometry +100+112 -composite -blur 0x14 \
  "$out/icon_824.png" -geometry +100+100 -composite -depth 8 -strip "$out/icon_macos.png"

dart run flutter_launcher_icons

# iOS: Icon-App-<points>x<points>@<scale>x.png, RGB without alpha (PNG24).
for file in ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png; do
  name=${file##*Icon-App-}
  size=$(awk -v points="${name%%x*}" -v scale="${name##*@}" 'BEGIN { print points * int(scale) }')
  resize "$out/icon_full_bleed.png" "$size" "PNG24:$file"
done

# macOS: app_icon_<px>.png
for file in macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png; do
  size=${file##*_}
  resize "$out/icon_macos.png" "${size%.png}" "$file"
done

render icon 192 web/icons/Icon-192.png
render icon 512 web/icons/Icon-512.png
resize "$out/icon_full_bleed.png" 192 web/icons/Icon-maskable-192.png
resize "$out/icon_full_bleed.png" 512 web/icons/Icon-maskable-512.png
# 32 px: sharp in browser tabs on high-density screens.
render icon_small 32 web/favicon.png

for size in 16 24 32; do render icon_small "$size" "$out/windows-$size.png"; done
for size in 48 64 128 256; do render icon "$size" "$out/windows-$size.png"; done
magick "$out"/windows-{16,24,32,48,64,128,256}.png -define icon:png-compression-size=48 \
  windows/runner/resources/app_icon.ico
