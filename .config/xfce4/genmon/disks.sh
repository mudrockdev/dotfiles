disk_names=$(lsblk -d -o NAME | grep -E '^(sd|nvme|hd)')

TEXT="<txt>"

disk_array=($disk_names)
num_disks=${#disk_array[@]}
current_disk=0

for disk in $disk_names; do
    ((current_disk++))

    total_size=$(lsblk -b -d -o SIZE "/dev/$disk" | tail -n 1)

    df_output=$(df -B1 | grep "/dev/${disk}[p]*[0-9]" 2>/dev/null)

    total_used=0
    total_avail=0

    declare -A processed_partitions

    while read -r line; do
        if [ ! -z "$line" ]; then
            partition=$(echo "$line" | awk '{print $1}')

            if [ "${processed_partitions[$partition]}" != "1" ]; then
                used=$(echo "$line" | awk '{print $3}')
                avail=$(echo "$line" | awk '{print $4}')

                total_used=$((total_used + used))
                total_avail=$((total_avail + avail))

                processed_partitions[$partition]="1"
            fi
        fi
    done <<< "$df_output"

    unset processed_partitions

    total_hr=$(numfmt --to=iec-i --suffix=B $total_size)
    used_hr=$(numfmt --to=iec-i --suffix=B $total_used)
    avail_hr=$(numfmt --to=iec-i --suffix=B $total_avail)

    if [ $((total_used + total_avail)) -ne 0 ]; then
        usage_percent=$((total_used * 100 / (total_used + total_avail)))
    else
        usage_percent=0
    fi

    if [ $usage_percent -ge 90 ]; then
        color="red"
    elif [ $usage_percent -ge 50 ]; then
        color="yellow"
    else
        color="green"
    fi

    TEXT+="$disk "
    TEXT+="<span foreground='$color'>$avail_hr</span>"

    if [ $current_disk -lt $num_disks ]; then
        TEXT+=" / "
    fi
done

TEXT+="</txt>"
echo -e "$TEXT"
