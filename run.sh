#!/bin/bash

# validate user input
parser_validate() {
  value=$1
  min=1
  max=65535

  IFS='=' read -r container host <<< "$value"
  IFS=':' read -r containeruid containergid <<< "$container"
  IFS=':' read -r hostuid hostgid <<< "$host"

  if ! [[ $containeruid =~ ^[0-9]+$ ]]; then
    echo "UID \"$containeruid\" is not a number"
    exit 1
  elif ! [[ $containergid =~ ^[0-9]+$ ]]; then
    echo "GID \"$containergid\"  is not a number"
    exit 1
  elif (( containeruid < min || containeruid > max )); then
    echo "UID \"$containeruid\" is not in range $min-$max"
    exit 1
  elif (( containergid < min || containergid > max )); then
    echo "GID \"$containergid\" is not in range $min-$max"
    exit 1
  fi

  if ! [[ $hostuid =~ ^[0-9]+$ ]]; then
    echo "UID \"$hostuid\" is not a number"
    exit 1
  elif ! [[ $hostgid =~ ^[0-9]+$ ]]; then
    echo "GID \"$hostgid\" is not a number"
    exit 1
  elif (( hostuid < min || hostuid > max )); then
    echo "UID \"$hostuid\" is not in range $min-$max"
    exit 1
  elif (( hostgid < min || hostgid > max )); then
    echo "GID \"$hostgid\" is not in range $min-$max"
    exit 1
  else
    echo "$containeruid $containergid $hostuid $hostgid"
  fi
}

# create lxc mapping strings
create_map() {
  id_type=$1
  id_list=("${@:2}")
  ret=()

  for (( i=0; i<${#id_list[@]}; i+=2 )); do
    containerid=${id_list[i]}
    hostid=${id_list[i+1]}

    if (( i == 0 )); then
      ret+=("lxc.idmap: $id_type 0 100000 $containerid")
    else
      range_start=$((id_list[i-2] + 1))
      range_end=$((id_list[i-2] + 100001))
      range_diff=$((containerid - 1 - id_list[i-2]))
      ret+=("lxc.idmap: $id_type $range_start $range_end $range_diff")
    fi

    ret+=("lxc.idmap: $id_type $containerid $hostid")

    if (( i == ${#id_list[@]} - 2 )); then
      range_start=$((containerid + 1))
      range_end=$((containerid + 100001))
      range_diff=$((65535 - containerid))
      ret+=("lxc.idmap: $id_type $range_start $range_end $range_diff")
    fi
  done

  echo "${ret[@]}"
}

# collect user input
parser_inputs=("$@")
params=""
for input in "${parser_inputs[@]}"; do
  params+="$(parser_validate "$input") "
done

# create sorted uid/gid lists
map_args=($params)
uid_list=($(printf "%s\n" "${map_args[@]}" | sort -k1,1 | awk '{print $1, $3}'))
gid_list=($(printf "%s\n" "${map_args[@]}" | sort -k2,2 | awk '{print $2, $4}'))

# calls function that creates mapping strings
uid_map=$(create_map "u" "${uid_list[@]}")
gid_map=$(create_map "g" "${gid_list[@]}")

# output mapping strings
echo -e "\n# Add to /etc/pve/lxc/<container_id>.conf:"
for (( i=0; i<${#uid_map[@]}; i+=2 )); do
  echo "${uid_map[i]}"
  echo "${gid_map[i]}"
done

echo -e "\n# Add to /etc/subuid:"
for uid in "${uid_list[@]}"; do
  echo "root:${uid[1]}:1"
done

echo -e "\n# Add to /etc/subgid:"
for gid in "${gid_list[@]}"; do
  echo "root:${gid[1]}:1"
done
