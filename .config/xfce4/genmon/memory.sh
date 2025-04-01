#!/usr/bin/env bash
# Dependencies: bash>=3.2, coreutils, gawk

readonly TOTAL=$(free -b | awk '/^[Mm]em/{$2 = $2 / 1073741824; printf "%.2f", $2}')
readonly USED=$(free -b | awk '/^[Mm]em/{$3 = $3 / 1073741824; printf "%.2f", $3}')
readonly FREE=$(free -b | awk '/^[Mm]em/{$4 = $4 / 1073741824; printf "%.2f", $4}')

USED_PERCENT=$(awk -v used="$USED" -v total="$TOTAL" 'BEGIN {printf "%.0f", (used/total)*100}')

if [ $USED_PERCENT -ge 90 ]; then
    COLOR="red"
elif [ $USED_PERCENT -ge 50 ]; then
    COLOR="yellow"
else
    COLOR="green"
fi

INFO="<txt>"
INFO+="<span foreground='$COLOR'>${USED}</span> GiB / "
INFO+=" ${TOTAL} GiB"
INFO+="</txt>"

echo -e "${INFO}"
