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

# Обёртка для rofi
rofi_menu() {
  rofi -dmenu -theme "$THEME" "$@"
}

# Уведомление с заменой предыдущего
wifi_notify() {
  dunstify -r 9999 "WiFi" "$1"
}

# Обычное уведомление
wifi_notify_plain() {
  notify-send "WiFi" "$1" -t 10000
}

# Перезапуск dunst
restart_dunst() {
  pkill -x dunst && dunst &
}

# Подтверждение действия
confirm() {
  local PROMPT_TEXT="$1"
  ANSWER=$(echo -e "$YES\n$NO" | rofi_menu -p "$PROMPT_TEXT?" -u 1)
  [ "$ANSWER" = "$YES" ]
}

get_signal_icon() {
  local SIGNAL=$1
  if [ "$SIGNAL" -ge 80 ]; then echo "󰤨 "
  elif [ "$SIGNAL" -ge 60 ]; then echo "󰤥 "
  elif [ "$SIGNAL" -ge 40 ]; then echo "󰤢 "
  elif [ "$SIGNAL" -ge 20 ]; then echo "󰤟 "
  else echo "󰤯 "
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

connect_to_network() {
  local SSID="$1"
  local PASS="$2"

  wifi_notify "$CONNECTING $SSID..."
  if nmcli device wifi connect "$SSID" password "$PASS" 2>/dev/null; then
    wifi_notify "$CONNECTED_OK $SSID"
  else
    nmcli connection delete "$SSID" 2>/dev/null
    wifi_notify "$CONNECTED_FAIL $SSID"
    main_menu
  fi
}

show_current() {
  CONN=$(current_connection)
  if [ -z "$CONN" ]; then
    echo "$NO_CONNECTION" | rofi_menu -p "  $CURRENT"
    main_menu
    return
  fi

  wifi_notify_plain "$LOADING_CURRENT"

  IFACE=$(get_iface)
  SIGNAL=$(nmcli -t -f IN-USE,SIGNAL device wifi list | grep '^\*' | cut -d: -f2)
  ICON=$(get_signal_icon "$SIGNAL")
  IP4=$(nmcli -t -f IP4.ADDRESS device show "$IFACE" | head -1 | cut -d: -f2)
  IP6=$(nmcli -t -f IP6.ADDRESS device show "$IFACE" | head -1 | cut -d: -f2)
  GW=$(nmcli -t -f IP4.GATEWAY device show "$IFACE" | head -1 | cut -d: -f2)
  DNS=$(nmcli -t -f IP4.DNS device show "$IFACE" | head -1 | cut -d: -f2)

  restart_dunst

  ACTION=$(echo -e "$ICON $CONN\n $SIGNAL%\n IPv4: $IP4\n IPv6: $IP6\n  $GW\n DNS: $DNS\n $FORGET" | rofi_menu -p "  $CURRENT" -u 6)
  case "$ACTION" in
    " $FORGET")
      if confirm " $FORGET"; then
        nmcli device disconnect "$IFACE" 2>/dev/null
        nmcli connection delete "$CONN" 2>/dev/null
        wifi_notify_plain "$FORGOTTEN: $CONN"
      else
        show_current
      fi
      ;;
    "") main_menu ;;
    *) show_current ;;
  esac
}

show_networks() {
  wifi_notify_plain "$LOADING"

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
    BAND=$([ "$FREQ" -ge 5000 ] 2>/dev/null && echo "5GHz" || echo "2.4GHz")

    if echo "$SECURITY" | grep -q "WPA"; then
      SEC="WPA"
    elif [ "$SECURITY" = "--" ]; then
      SEC="Open"
    else
      SEC="$SECURITY"
    fi

    LINE_OUT="$ICON $SSID | $SIGNAL% | $BAND | $SEC"

    if [ "$SSID" = "$ACTIVE" ]; then
      NETWORKS_ACTIVE="$LINE_OUT  ✓"
    elif [ -z "$NETWORKS_OTHER" ]; then
      NETWORKS_OTHER="$LINE_OUT"
    else
      NETWORKS_OTHER="$NETWORKS_OTHER
$LINE_OUT"
    fi
  done < <(nmcli -t -f SSID,SIGNAL,SECURITY,FREQ device wifi list)

  NETWORKS="${NETWORKS_ACTIVE:+$NETWORKS_ACTIVE${NETWORKS_OTHER:+
}}$NETWORKS_OTHER"

  restart_dunst

  CHOSEN=$(echo "$NETWORKS" | rofi_menu -p "  $PROMPT_NETWORKS")
  [ -z "$CHOSEN" ] && main_menu && return

  SSID=$(echo "$CHOSEN" | sed 's/ |.*//' | awk '{print $2}')
  SAVED=$(nmcli -t -f NAME connection show | grep -Fx "$SSID")

  if [ -n "$SAVED" ]; then
    wifi_notify "$CONNECTING $SSID..."
    if nmcli connection up "$SSID" 2>/dev/null; then
      wifi_notify "$CONNECTED_OK $SSID"
      return
    fi
    nmcli connection delete "$SSID" 2>/dev/null
  fi

  PASS=$(rofi_menu -p "  $ENTER_PASS" -theme-str 'entry { enabled: true; visibility: false; }')
  [ -z "$PASS" ] && main_menu && return
  connect_to_network "$SSID" "$PASS"
}

confirm_disconnect() {
  if confirm " $DISCONNECT"; then
    CONN=$(current_connection)
    IFACE=$(get_iface)
    nmcli device disconnect "$IFACE" 2>/dev/null
    wifi_notify_plain "$DISCONNECTED $CONN"
  else
    main_menu
  fi
}

main_menu() {
  STATUS=$(wifi_status)
  TOGGLE=$([ "$STATUS" = "enabled" ] && echo " $TOGGLE_OFF" || echo " $TOGGLE_ON")
  CONN=$(current_connection)
  CURRENT_LABEL=$([ -n "$CONN" ] && echo " $CURRENT: $CONN" || echo " $CURRENT: $NO_CONNECTION")

  CHOSEN=$(echo -e "$CURRENT_LABEL\n $SCAN\n $DISCONNECT\n$TOGGLE\n $EXIT" | rofi_menu -p "  $PROMPT" -u 4)
  case "$CHOSEN" in
    " $SCAN") show_networks ;;
    " $DISCONNECT") confirm_disconnect ;;
    " $TOGGLE_OFF"|" $TOGGLE_ON")
      if [ "$STATUS" = "enabled" ]; then
        nmcli radio wifi off
        wifi_notify_plain "$WIFI_OFF"
      else
        nmcli radio wifi on
        wifi_notify_plain "$WIFI_ON"
      fi
      main_menu
      ;;
    " $EXIT"|"") exit 0 ;;
    *) show_current ;;
  esac
}

main_menu
