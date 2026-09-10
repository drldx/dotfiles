#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_pomodoro_state"
TIME_FILE="/tmp/waybar_pomodoro_time"
END_FILE="/tmp/waybar_pomodoro_end"
MODE_FILE="/tmp/waybar_pomodoro_mode"   # work, break
COUNT_FILE="/tmp/waybar_pomodoro_count" # completed work sessions count

# Durations in seconds
DUR_WORK=1500 # 25 mins
DUR_BREAK=300 # 5 mins

# Initialize defaults if not present
[[ ! -f "$STATE_FILE" ]] && echo "stopped" >"$STATE_FILE"
[[ ! -f "$MODE_FILE" ]] && echo "work" >"$MODE_FILE"
[[ ! -f "$COUNT_FILE" ]] && echo "0" >"$COUNT_FILE"
if [[ ! -f "$TIME_FILE" ]]; then
  echo "$DUR_WORK" >"$TIME_FILE"
fi

play_sound() {
  # Try playing a standard desktop sound theme event (PulseAudio/PipeWire)
  if command -v paplay &>/dev/null; then
    # Try looking for a standard system sound file, fall back gracefully if missing
    for sound in /usr/share/sounds/freedesktop/stereo/complete.oga /usr/share/sounds/freedesktop/stereo/message-new-instant.oga; do
      if [[ -f "$sound" ]]; then
        paplay "$sound" &>/dev/null &
        return
      fi
    done
  fi

  # Fallback to standard terminal bell if paplay or sound files aren't found
  echo -en "\a"
}

get_time_formatted() {
  local t=$(cat "$TIME_FILE")
  [ "$t" -lt 0 ] && t=0
  printf "%02d:%02d" $((t / 60)) $((t % 60))
}

case "$1" in
toggle)
  if [[ "$(cat "$STATE_FILE")" == "running" ]]; then
    # Pause: calculate exact remaining time based on target end time
    if [[ -f "$END_FILE" ]]; then
      now=$(date +%s)
      end=$(cat "$END_FILE")
      rem=$((end - now))
      [[ "$rem" -lt 0 ]] && rem=0
      echo "$rem" >"$TIME_FILE"
    fi
    echo "paused" >"$STATE_FILE"
  else
    # Start or Resume: set a new absolute end time based on remaining seconds
    rem=$(cat "$TIME_FILE")
    end_time=$(($(date +%s) + rem))
    echo "$end_time" >"$END_FILE"
    echo "running" >"$STATE_FILE"

    # Background timer loop using absolute timestamps (suspend-safe)
    while [[ "$(cat "$STATE_FILE")" == "running" ]]; do
      now=$(date +%s)
      end=$(cat "$END_FILE")
      rem=$((end - now))

      if [ "$rem" -le 0 ]; then
        current_mode=$(cat "$MODE_FILE")

        if [ "$current_mode" == "work" ]; then
          # Increment completed work count
          completed=$(($(cat "$COUNT_FILE") + 1))
          echo "$completed" >"$COUNT_FILE"

          echo "break" >"$MODE_FILE"
          echo "$DUR_BREAK" >"$TIME_FILE"

          play_sound
          notify-send "Pomodoro" "Time is up! Take a Break." -u normal
        else
          # Break finished, switch back to work
          echo "work" >"$MODE_FILE"
          echo "$DUR_WORK" >"$TIME_FILE"

          play_sound
          notify-send "Pomodoro" "Break over! Back to work." -u normal
        fi

        echo "stopped" >"$STATE_FILE"
        rm -f "$END_FILE"
        pkill -RTMIN+8 waybar
        break
      fi

      echo "$rem" >"$TIME_FILE"
      pkill -RTMIN+8 waybar
      sleep 1
    done
  fi
  pkill -RTMIN+8 waybar
  ;;
reset)
  echo "stopped" >"$STATE_FILE"
  echo "work" >"$MODE_FILE"
  echo "$DUR_WORK" >"$TIME_FILE"
  echo "0" >"$COUNT_FILE"
  rm -f "$END_FILE"
  pkill -RTMIN+8 waybar
  ;;
print)
  state=$(cat "$STATE_FILE")
  mode=$(cat "$MODE_FILE")

  # If running, dynamically calculate live remaining time for Waybar display
  if [ "$state" == "running" ] && [[ -f "$END_FILE" ]]; then
    now=$(date +%s)
    end=$(cat "$END_FILE")
    rem=$((end - now))
    [ "$rem" -lt 0 ] && rem=0
    echo "$rem" >"$TIME_FILE"
  fi

  time_str=$(get_time_formatted)

  # Assign icons/labels depending on current loop mode
  if [ "$state" == "running" ]; then
    case "$mode" in
    break) icon="☕" ;;
    *) icon="⏱" ;;
    esac
    echo "{\"text\": \"$icon $time_str\", \"class\": \"$mode running\"}"
  elif [ "$state" == "paused" ]; then
    echo "{\"text\": \"⏸ $time_str\", \"class\": \"$mode paused\"}"
  else
    # Default display text when stopped
    case "$mode" in
    break) text="☕ Break" ;;
    *) text="⏱ 25:00" ;;
    esac
    echo "{\"text\": \"$text\", \"class\": \"$mode stopped\"}"
  fi
  ;;
esac
