#!/bin/bash

THEME="$HOME/.config/rofi/power.rasi"

# Язык
LANG_SYS=$(echo $LANG | cut -c1-2)

if [ "$LANG_SYS" = "ru" ]; then
  POWEROFF="Выключить"
  REBOOT="Перезагрузить"
  SLEEP="Сон"
  EXIT="Выход"
  PROMPT="Питание"
else
  POWEROFF="Shutdown"
  REBOOT="Reboot"
  SLEEP="Sleep"
  EXIT="Exit"
  PROMPT="Power"
fi

CHOSEN=$(echo -e " $POWEROFF\n $REBOOT\n $SLEEP\n $EXIT" | rofi -dmenu -theme "$THEME" -p "  $PROMPT")

case "$CHOSEN" in
  " $POWEROFF") systemctl poweroff ;;
  " $REBOOT") systemctl reboot ;;
  " $SLEEP") systemctl suspend ;;
  " $EXIT"|"") exit 0 ;;
esac
