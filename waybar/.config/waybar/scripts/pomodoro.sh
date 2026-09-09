#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_pomodoro_state"
TIME_FILE="/tmp/waybar_pomodoro_time"

# Initialize if not present
[[ ! -f "$STATE_FILE" ]] && echo "stopped" >"$STATE_FILE"
[[ ! -f "$TIME_FILE" ]] && echo "1500" >"$TIME_FILE" # 25 mins in seconds

get_time_formatted() {
  local t=$(cat "$TIME_FILE")
  printf "%02d:%02d" $((t / 60)) $((t % 60))
}

case "$1" in
toggle)
  if [[ "$(cat "$STATE_FILE")" == "running" ]]; then
    echo "paused" >"$STATE_FILE"
  else
    echo "running" >"$STATE_FILE"
    # Background timer loop
    while [[ "$(cat "$STATE_FILE")" == "running" ]]; do
      t=$(cat "$TIME_FILE")
      if [ "$t" -le 0 ]; then
        notify-send "Pomodoro" "Time is up! Take a break." -u normal
        echo "stopped" >"$STATE_FILE"
        echo "1500" >"$TIME_FILE"
        pkill -RTMIN+8 waybar
        break
      fi
      echo $((t - 1)) >"$TIME_FILE"
      pkill -RTMIN+8 waybar
      sleep 1
    done
  fi
  pkill -RTMIN+8 waybar
  ;;
reset)
  echo "stopped" >"$STATE_FILE"
  echo "1500" >"$TIME_FILE"
  pkill -RTMIN+8 waybar
  ;;
print)
  state=$(cat "$STATE_FILE")
  time_str=$(get_time_formatted)
  if [ "$state" == "running" ]; then
    echo "{\"text\": \"⏱ $time_str\", \"class\": \"running\"}"
  elif [ "$state" == "paused" ]; then
    echo "{\"text\": \"⏸ $time_str\", \"class\": \"paused\"}"
  else
    echo "{\"text\": \"⏱ 25:00\", \"class\": \"stopped\"}"
  fi
  ;;
esac
