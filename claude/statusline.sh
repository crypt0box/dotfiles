#!/bin/bash
# Claude Code Status Line
# Model (Effort) | Context used % | Usage limit (current session / 5h window)

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
max_ctx=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
limit_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
used_pct_int=$(awk "BEGIN {printf \"%.0f\", ${used_pct:-0}}")

if [ "$used_pct_int" -ge 60 ] 2>/dev/null; then
  brain="💀"
elif [ "$used_pct_int" -ge 30 ] 2>/dev/null; then
  brain="🫠"
else
  brain="🧠"
fi

if awk "BEGIN {exit !(${max_ctx:-0} >= 1000000)}"; then
  max_ctx_disp="$(awk "BEGIN {printf \"%.1f\", ${max_ctx:-0} / 1000000}")M"
else
  max_ctx_disp="$(awk "BEGIN {printf \"%.0f\", ${max_ctx:-0} / 1000}")k"
fi

model_part="🤖 $model"
if [ -n "$effort" ]; then
  model_part="$model_part | ⚡️ $effort"
fi

# Usage limit bar (rate_limits is absent for API users / before first response)
limit_part=""
if [ -n "$limit_pct" ]; then
  limit_int=$(awk "BEGIN {printf \"%.0f\", $limit_pct}")
  filled=$(((limit_int + 5) / 10))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0

  bar=""
  for ((i = 0; i < 10; i++)); do
    if [ "$i" -lt "$filled" ]; then bar+="▓"; else bar+="░"; fi
  done

  if [ "$limit_int" -ge 80 ]; then
    color=$'\033[31m'
    batt="🪫"
  elif [ "$limit_int" -ge 50 ]; then
    color=$'\033[33m'
    batt="🔋"
  else
    color=$'\033[32m'
    batt="🔋"
  fi
  reset=$'\033[0m'

  # Local time when the 5h window resets
  reset_part=""
  if [ -n "$resets_at" ]; then
    reset_part=" ($(date -r "$resets_at" +%H:%M))"
  fi

  limit_part=" | ${batt} ${color}${bar}${reset} ${limit_int}%${reset_part}"
fi

printf "%s | %s %s%% (%s)%s" "$model_part" "$brain" "$used_pct_int" "$max_ctx_disp" "$limit_part"
