#!/usr/bin/env bash
# Dependencies: bash>=4, curl, jq, zenity, xdg-open
#
# Shows the issue you are currently working on in the panel.
# Clicking opens a menu with every active issue assigned to you;
# picking one opens it in the browser.
#
# Configuration: ~/.config/xfce4/genmon/redmine.conf
#   REDMINE_URL="https://redmine.example.com"
#   REDMINE_API_KEY="your api token"
#   REDMINE_CURRENT_STATUS="In Progress"   # optional, status treated as "working on"
#   REDMINE_MAX_LEN=40                     # optional, panel text length

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/genmon/redmine.conf"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/genmon-redmine.json"
SELF="$(readlink -f "$0")"

[ -r "$CONF" ] && . "$CONF"

REDMINE_URL="${REDMINE_URL%/}"
REDMINE_CURRENT_STATUS="${REDMINE_CURRENT_STATUS:-In Progress}"
REDMINE_MAX_LEN="${REDMINE_MAX_LEN:-40}"

pango_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

die() {
    echo -e "<txt><span foreground='red'>$1</span></txt>\n<tool>$2</tool>"
    exit 0
}

if [ -z "$REDMINE_URL" ] || [ -z "$REDMINE_API_KEY" ]; then
    die "Redmine N/A" "Set REDMINE_URL and REDMINE_API_KEY in $CONF"
fi

fetch() {
    curl -sS -f -m 10 \
        -H "X-Redmine-API-Key: $REDMINE_API_KEY" \
        -H "Accept: application/json" \
        "$REDMINE_URL/issues.json?assigned_to_id=me&status_id=open&limit=100&sort=updated_on:desc"
}

# jq filter producing: id \t status \t project \t subject
readonly ROWS='.issues[] | [(.id|tostring), .status.name, .project.name, .subject] | @tsv'

case "$1" in
menu)
    JSON=$(fetch) || JSON=$(cat "$CACHE" 2>/dev/null)
    [ -z "$JSON" ] && { zenity --error --text="Redmine'a ulaşılamadı."; exit 1; }

    mapfile -t ROWLIST < <(jq -r "$ROWS" <<< "$JSON")
    if [ ${#ROWLIST[@]} -eq 0 ]; then
        zenity --info --text="Açık issue yok."
        exit 0
    fi

    ARGS=()
    for row in "${ROWLIST[@]}"; do
        IFS=$'\t' read -r id status project subject <<< "$row"
        ARGS+=("$id" "$status" "$project" "$subject")
    done

    CHOICE=$(zenity --list \
        --title="Redmine" \
        --text="Aktif issue'lar (${#ROWLIST[@]})" \
        --width=800 --height=500 \
        --column="#" --column="Durum" --column="Proje" --column="Konu" \
        --print-column=1 \
        "${ARGS[@]}" 2>/dev/null)

    [ -n "$CHOICE" ] && xdg-open "$REDMINE_URL/issues/${CHOICE%%|*}" >/dev/null 2>&1 &
    exit 0
    ;;
esac

JSON=$(fetch)
if [ -n "$JSON" ]; then
    mkdir -p "$(dirname "$CACHE")"
    printf '%s' "$JSON" > "$CACHE"
else
    JSON=$(cat "$CACHE" 2>/dev/null)
    STALE=1
fi

[ -z "$JSON" ] && die "Redmine N/A" "Redmine'a ulaşılamadı ve önbellek boş."

COUNT=$(jq -r '.issues | length' <<< "$JSON")

# "current" issue: newest updated one in the working status, else newest updated
CURRENT=$(jq -r --arg s "$REDMINE_CURRENT_STATUS" \
    '(first(.issues[] | select(.status.name == $s)) // .issues[0]) as $i
     | if $i == null then empty else [($i.id|tostring), $i.subject] | @tsv end' <<< "$JSON")

TEXT="<txt>"
if [ -z "$CURRENT" ]; then
    TEXT+="<span foreground='gray'>issue yok</span>"
else
    IFS=$'\t' read -r CUR_ID CUR_SUBJECT <<< "$CURRENT"
    if [ ${#CUR_SUBJECT} -gt "$REDMINE_MAX_LEN" ]; then
        CUR_SUBJECT="${CUR_SUBJECT:0:$REDMINE_MAX_LEN}…"
    fi
    CUR_SUBJECT=$(pango_escape <<< "$CUR_SUBJECT")

    if [ -n "$STALE" ]; then
        COLOR="gray"
    elif [ "$COUNT" -ge 10 ]; then
        COLOR="red"
    elif [ "$COUNT" -ge 5 ]; then
        COLOR="yellow"
    else
        COLOR="green"
    fi

    TEXT+="<span foreground='$COLOR'>#$CUR_ID</span> $CUR_SUBJECT"
fi
TEXT+="</txt>"

TOOLTIP=$(jq -r "$ROWS" <<< "$JSON" \
    | awk -F'\t' '{printf "#%s [%s] %s\n", $1, $2, $4}' \
    | pango_escape)
[ -z "$TOOLTIP" ] && TOOLTIP="Açık issue yok."
[ -n "$STALE" ] && TOOLTIP="(önbellek) $TOOLTIP"

echo -e "$TEXT"
echo -e "<tool>$TOOLTIP</tool>"
# genmon binds <click> to the icon/button area and <txtclick> to the label;
# there is no <img> here, so <txtclick> is the one that actually fires.
echo -e "<txtclick>$SELF menu</txtclick>"
echo -e "<click>$SELF menu</click>"
