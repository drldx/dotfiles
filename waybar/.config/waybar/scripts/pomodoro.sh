#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_pomodoro_state"
TIME_FILE="/tmp/waybar_pomodoro_time"
END_FILE="/tmp/waybar_pomodoro_end"
MODE_FILE="/tmp/waybar_pomodoro_mode"   # work, short_break, long_break
COUNT_FILE="/tmp/waybar_pomodoro_count" # completed work sessions count

# Durations in seconds
DUR_WORK=5  # 25 mins
DUR_SHORT=3 # 5 mins
DUR_LONG=9  # 15 mins

# Initialize defaults if not present
[[ ! -f "$STATE_FILE" ]] && echo "stopped" >"$STATE_FILE"
[[ ! -f "$MODE_FILE" ]] && echo "work" >"$MODE_FILE"
[[ ! -f "$COUNT_FILE" ]] && echo "0" >"$COUNT_FILE"
if [[ ! -f "$TIME_FILE" ]]; then
  echo "$DUR_WORK" >"$TIME_FILE"
fi

get_time_formatted() {
  local t=$(cat "$TIME_FILE")
  [ "$t" -lt 0 ] && t=0
  printf "%02d:%02d" $((t / 60)) $((t % 60))
}

get_current_duration() {
  local mode=$(cat "$MODE_FILE")
  case "$mode" in
  short_break) echo "$DUR_SHORT" ;;
  long_break) echo "$DUR_LONG" ;;
  *) echo "$DUR_WORK" ;;
  esac
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

          # Every 4th work session triggers a long break, otherwise short break
          if [ $((completed % 4)) -eq 0 ]; then
            echo "long_break" >"$MODE_FILE"
            echo "$DUR_LONG" >"$TIME_FILE"
            notify-send "Pomodoro" "Great job! Time for a Long Break." -u normal
          else
            echo "short_break" >"$MODE_FILE"
            echo "$DUR_SHORT" >"$TIME_FILE"
            notify-send "Pomodoro" "Time is up! Take a Short Break." -u normal
          fi
        else
          # Break finished, switch back to work
          echo "work" >"$MODE_FILE"
          echo "$DUR_WORK" >"$TIME_FILE"
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
    short_break) icon="☕" ;;
    long_break) icon="🌴" ;;
    *) icon="⏱" ;;
    esac
    echo "{\"text\": \"$icon $time_str\", \"class\": \"$mode running\"}"
  elif [ "$state" == "paused" ]; then
    echo "{\"text\": \"⏸ $time_str\", \"class\": \"$mode paused\"}"
  else
    # Default display text when stopped
    case "$mode" in
    short_break) text="☕ Break" ;;
    long_break) text="🌴 Break" ;;
    *) text="⏱ 25:00" ;;
    esac
    echo "{\"text\": \"$text\", \"class\": \"$mode stopped\"}"
  fi
  ;;
esac
