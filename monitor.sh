#!/usr/bin/env bash

if [[ $# -eq 0 ]]
then
  echo -e "-i interface name required"
  exit 1
fi

interface=''
while getopts 'i:' opt 2>/dev/null; do
  case "$opt" in
    i) interface="${OPTARG}"
      ;;
    ?) echo "Undefined option"
      exit 1
      ;;
  esac
done

if [[ -z "$interface" ]];
then
  echo "-i is required"
  exit 1
fi

ifconfig "${interface}" down > /dev/null 2>&1 &&
airmon-ng check kill > /dev/null 2>&1 &&
iw dev "${interface}" set type monitor > /dev/null 2>&1 &&
ifconfig "${interface}" up > /dev/null 2>&1

if [[ $? -ne 0 ]]
then
  echo "Error"
  exit 1
fi

echo -e "Interface ${interface} is in monitor mode.\n"
ifconfig "${interface}"
echo -e "\n"
iw dev