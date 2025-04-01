#!/usr/bin/env bash

TEXT="<txt>"

ip=$(ip a show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z "$ip" ]; then
    ip=$(ip a show | grep -E "enp[0-9]+s0" -A2 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
fi

if [ -n "$ip" ]; then
    TEXT+="$ip"
else
    TEXT+="IP N/A"
fi

TEXT+="</txt>"

echo -e "$TEXT"
