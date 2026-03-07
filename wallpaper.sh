#!/bin/bash

# Папки с обоями
STATIC_DIR="$HOME/Wallpaper"
LIVE_DIR="$HOME/Wallpaper/live"
PREVIEW_DIR="/tmp/wallpaper-previews"

# Настройки rofi
THEME="$HOME/.config/rofi/wallpaper.rasi"

ROFI_OPTS=(-dmenu -show-icons -theme "$THEME")

mkdir -p "$PREVIEW_DIR"

# Язык
LANG_SYS=$(echo $LANG | cut -c1-2)

if [ "$LANG_SYS" = "ru" ]; then
  LIVE="Живые"
  STATIC="Статичные"
  EXIT="Выход"
  PROMPT="Обои"
  PROMPT_LIVE="Живые обои"
  PROMPT_STATIC="Статичные обои"
else
  LIVE="Live"
  STATIC="Static"
  EXIT="Exit"
  PROMPT="Wallpaper"
  PROMPT_LIVE="Live wallpaper"
  PROMPT_STATIC="Static wallpaper"
fi

show_live() {
  find "$LIVE_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.gif" \) | while read -r VIDEO; do
    NAME=$(basename "$VIDEO")
    PREVIEW="$PREVIEW_DIR/$NAME.jpg"
    [ ! -f "$PREVIEW" ] && ffmpeg -i "$VIDEO" -vframes 1 -q:v 2 "$PREVIEW" -y 2>/dev/null
  done

  CHOSEN=$(find "$PREVIEW_DIR" -type f -name "*.jpg" | while read -r PREVIEW; do
    NAME=$(basename "$PREVIEW" .jpg)
    echo -en "$NAME\0icon\x1f$PREVIEW\n"
  done | rofi "${ROFI_OPTS[@]}" -p " $PROMPT_LIVE")

  [ -z "$CHOSEN" ] && return 1

  xprop -root -remove _XROOTPMAP_ID 2>/dev/null
  xprop -root -remove ESETROOT_PMAP_ID 2>/dev/null
  pkill xwinwrap 2>/dev/null
  sleep 0.3
  xwinwrap -fs -fdt -ni -b -nf -ov -s -st -sp -- \
    mpv --wid="%WID" --loop --no-audio --no-osc --vo=x11 "$LIVE_DIR/$CHOSEN" &
  return 0
}

show_static() {
  CHOSEN=$(find "$STATIC_DIR" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | while read -r IMG; do
    NAME=$(basename "$IMG")
    echo -en "$NAME\0icon\x1f$IMG\n"
  done | rofi "${ROFI_OPTS[@]}" -p " $PROMPT_STATIC")

  [ -z "$CHOSEN" ] && return 1

  xprop -root -remove _XROOTPMAP_ID 2>/dev/null
  xprop -root -remove ESETROOT_PMAP_ID 2>/dev/null
  pkill xwinwrap 2>/dev/null
  sleep 0.3
  feh --bg-max "$STATIC_DIR/$CHOSEN"
  return 0
}

main_menu() {
  TYPE=$(echo -e " $LIVE\n $STATIC\n $EXIT" | rofi -dmenu -theme "$THEME" -p "  $PROMPT")

  case "$TYPE" in
    " $LIVE") show_live || main_menu ;;
    " $STATIC") show_static || main_menu ;;
    " $EXIT"|"") exit 0 ;;
  esac
}

main_menu
