#!/bin/bash

# Проверка зависимостей
MISSING=""
for cmd in nmcli rofi notify-send dunstify; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING="$MISSING $cmd"
    echo "Ошибка: $cmd не установлен"
  fi
done

if [ -n "$MISSING" ]; then
  exit 1
fi

THEME="$HOME/.config/rofi/wifi.rasi"
# Язык
LANG_SYS=$(echo $LANG | cut -c1-2)
if [ "$LANG_SYS" = "ru" ]; then
  SCAN="Список сетей"
  TOGGLE_ON="Включить WiFi"
  TOGGLE_OFF="Выключить WiFi"
  CURRENT="Текущее подключение"
  DISCONNECT="Отключиться"
  FORGET="Забыть сеть"
  FORGOTTEN="Сеть забыта"
  EXIT="Выход"
  PROMPT="WiFi"
  PROMPT_NETWORKS="Выбери сеть"
  NO_CONNECTION="Нет подключения"
  ENTER_PASS="Введи пароль: "
  CONNECTING="Подключение к"
  CONNECTED_OK="Подключено к"
  CONNECTED_FAIL="Не удалось подключиться к"
  DISCONNECTED="Отключено от"
  WIFI_OFF="WiFi выключен"
  WIFI_ON="WiFi включён"
  LOADING="Загрузка сетей..."
  LOADING_CURRENT="Получение информации..."
  YES="Да"
  NO="Нет"
else
  SCAN="Network list"
  TOGGLE_ON="Enable WiFi"
  TOGGLE_OFF="Disable WiFi"
  CURRENT="Current connection"
  DISCONNECT="Disconnect"
  FORGET="Forget network"
  FORGOTTEN="Network forgotten"
  EXIT="Exit"
  PROMPT="WiFi"
  PROMPT_NETWORKS="Select network"
  NO_CONNECTION="No connection"
  ENTER_PASS="Enter password: "
  CONNECTING="Connecting to"
  CONNECTED_OK="Connected to"
  CONNECTED_FAIL="Failed to connect to"
  DISCONNECTED="Disconnected from"
  WIFI_OFF="WiFi disabled"
  WIFI_ON="WiFi enabled"
  LOADING="Loading networks..."
  LOADING_CURRENT="Getting info..."
  YES="Yes"
  NO="No"
fi

get_signal_icon() {
  local SIGNAL=$1
  if [ "$SIGNAL" -ge 80 ]; then
    echo "󰤨 "
  elif [ "$SIGNAL" -ge 60 ]; then
    echo "󰤥 "
  elif [ "$SIGNAL" -ge 40 ]; then
    echo "󰤢 "
  elif [ "$SIGNAL" -ge 20 ]; then
    echo "󰤟 "
  else
    echo "󰤯 "
  fi
}

wifi_status() {
  nmcli radio wifi
}

current_connection() {
  nmcli -t -f NAME,TYPE connection show --active | grep '802-11-wireless' | cut -d: -f1
}

get_iface() {
  nmcli -t -f DEVICE,TYPE device | grep ':wifi$' | head -1 | cut -d: -f1
}

show_current() {
  CONN=$(current_connection)
  if [ -z "$CONN" ]; then
    echo "$NO_CONNECTION" | rofi -dmenu -theme "$THEME" -p "  $CURRENT"
    main_menu
    return
  fi

  notify-send "WiFi" "$LOADING_CURRENT" -t 10000

  IFACE=$(get_iface)
  SIGNAL=$(nmcli -t -f IN-USE,SIGNAL device wifi list | grep '^\*' | cut -d: -f2)
  ICON=$(get_signal_icon "$SIGNAL")
  IP4=$(nmcli -t -f IP4.ADDRESS device show "$IFACE" | head -1 | cut -d: -f2)
  IP6=$(nmcli -t -f IP6.ADDRESS device show "$IFACE" | head -1 | cut -d: -f2)
  GW=$(nmcli -t -f IP4.GATEWAY device show "$IFACE" | head -1 | cut -d: -f2)
  DNS=$(nmcli -t -f IP4.DNS device show "$IFACE" | head -1 | cut -d: -f2)

  pkill -x dunst && dunst &

  ACTION=$(echo -e "$ICON $CONN\n $SIGNAL%\n IPv4: $IP4\n IPv6: $IP6\n  $GW\n DNS: $DNS\n $FORGET" | rofi -dmenu -theme "$THEME" -p "  $CURRENT" -u 6)
  case "$ACTION" in
    " $FORGET")
      CONFIRM=$(echo -e "$YES\n$NO" | rofi -dmenu -theme "$THEME" -p "$FORGET?" -u 1)
      if [ "$CONFIRM" = "$YES" ]; then
        nmcli device disconnect "$IFACE" 2>/dev/null
        nmcli connection delete "$CONN" 2>/dev/null
        notify-send "WiFi" "$FORGOTTEN: $CONN" -t 10000
      else
        show_current
      fi
      ;;
    "") main_menu ;;
    *) show_current ;;
  esac
}

show_networks() {
  notify-send "WiFi" "$LOADING" -t 10000

  TMPFILE=$(mktemp)
  nmcli -t -f SSID,SIGNAL,SECURITY,FREQ device wifi list > "$TMPFILE"

  ACTIVE=$(current_connection)
  NETWORKS_ACTIVE=""
  NETWORKS_OTHER=""

  while IFS= read -r LINE; do
    SSID=$(echo "$LINE" | cut -d: -f1)
    SIGNAL=$(echo "$LINE" | cut -d: -f2)
    SECURITY=$(echo "$LINE" | cut -d: -f3)
    FREQ=$(echo "$LINE" | cut -d: -f4 | grep -o '^[0-9]*')

    [ -z "$SSID" ] && continue

    ICON=$(get_signal_icon "$SIGNAL")

    if [ "$FREQ" -ge 5000 ] 2>/dev/null; then
      BAND="5GHz"
    else
      BAND="2.4GHz"
    fi

    if echo "$SECURITY" | grep -q "WPA"; then
      SEC="WPA"
    elif [ "$SECURITY" = "--" ]; then
      SEC="Open"
    else
      SEC="$SECURITY"
    fi

    if [ "$SSID" = "$ACTIVE" ]; then
      NETWORKS_ACTIVE="$ICON $SSID | $SIGNAL% | $BAND | $SEC  ✓"
    else
      if [ -z "$NETWORKS_OTHER" ]; then
        NETWORKS_OTHER="$ICON $SSID | $SIGNAL% | $BAND | $SEC"
      else
        NETWORKS_OTHER="$NETWORKS_OTHER
$ICON $SSID | $SIGNAL% | $BAND | $SEC"
      fi
    fi
  done < "$TMPFILE"

  rm "$TMPFILE"

  if [ -n "$NETWORKS_ACTIVE" ]; then
    NETWORKS="$NETWORKS_ACTIVE
$NETWORKS_OTHER"
  else
    NETWORKS="$NETWORKS_OTHER"
  fi

  pkill -x dunst && dunst &

  CHOSEN=$(echo "$NETWORKS" | rofi -dmenu -theme "$THEME" -p "  $PROMPT_NETWORKS")
  [ -z "$CHOSEN" ] && main_menu && return

  SSID=$(echo "$CHOSEN" | sed 's/ |.*//' | awk '{print $2}')

  SAVED=$(nmcli -t -f NAME connection show | grep -Fx "$SSID")

  if [ -n "$SAVED" ]; then
    dunstify -r 9999 "WiFi" "$CONNECTING $SSID..."
    if nmcli connection up "$SSID" 2>/dev/null; then
      dunstify -r 9999 "WiFi" "$CONNECTED_OK $SSID"
    else
      nmcli connection delete "$SSID" 2>/dev/null
      PASS=$(rofi -dmenu -theme "$THEME" -p "  $ENTER_PASS" -theme-str 'entry { enabled: true; visibility: false; }')
      [ -z "$PASS" ] && main_menu && return
      dunstify -r 9999 "WiFi" "$CONNECTING $SSID..."
      if nmcli device wifi connect "$SSID" password "$PASS" 2>/dev/null; then
        dunstify -r 9999 "WiFi" "$CONNECTED_OK $SSID"
      else
        nmcli connection delete "$SSID" 2>/dev/null
        dunstify -r 9999 "WiFi" "$CONNECTED_FAIL $SSID"
        main_menu
      fi
    fi
  else
    PASS=$(rofi -dmenu -theme "$THEME" -p "  $ENTER_PASS" -theme-str 'entry { enabled: true; visibility: false; }')
    [ -z "$PASS" ] && main_menu && return
    dunstify -r 9999 "WiFi" "$CONNECTING $SSID..."
    if nmcli device wifi connect "$SSID" password "$PASS" 2>/dev/null; then
      dunstify -r 9999 "WiFi" "$CONNECTED_OK $SSID"
    else
      nmcli connection delete "$SSID" 2>/dev/null
      dunstify -r 9999 "WiFi" "$CONNECTED_FAIL $SSID"
      main_menu
    fi
  fi
}

confirm_disconnect() {
  CONFIRM=$(echo -e "$YES\n$NO" | rofi -dmenu -theme "$THEME" -p "$DISCONNECT?" -u 1)
  if [ "$CONFIRM" = "$YES" ]; then
    CONN=$(current_connection)
    IFACE=$(get_iface)
    nmcli device disconnect "$IFACE" 2>/dev/null
    notify-send "WiFi" "$DISCONNECTED $CONN" -t 10000
  else
    main_menu
  fi
}

main_menu() {
  STATUS=$(wifi_status)
  if [ "$STATUS" = "enabled" ]; then
    TOGGLE=" $TOGGLE_OFF"
  else
    TOGGLE=" $TOGGLE_ON"
  fi
  CONN=$(current_connection)
  if [ -n "$CONN" ]; then
    CURRENT_LABEL=" $CURRENT: $CONN"
  else
    CURRENT_LABEL=" $CURRENT: $NO_CONNECTION"
  fi
  CHOSEN=$(echo -e "$CURRENT_LABEL\n $SCAN\n $DISCONNECT\n$TOGGLE\n $EXIT" | rofi -dmenu -theme "$THEME" -p "  $PROMPT" -u 4)
  case "$CHOSEN" in
    " $SCAN") show_networks ;;
    " $DISCONNECT") confirm_disconnect ;;
    " $TOGGLE_OFF"|" $TOGGLE_ON")
      if [ "$STATUS" = "enabled" ]; then
        nmcli radio wifi off
        notify-send "WiFi" "$WIFI_OFF" -t 10000
      else
        nmcli radio wifi on
        notify-send "WiFi" "$WIFI_ON" -t 10000
      fi
      main_menu
      ;;
    " $EXIT"|"") exit 0 ;;
    *) show_current ;;
  esac
}

main_menu
