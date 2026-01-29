#!/usr/bin/env bash

#set -x
if [[ -p ./fifo-in ]];
then
  rm fifo-in
fi

mkfifo fifo-in

trap 'echo "Interrupt"; rm -f fifo-in fifo-out; exit 1' SIGINT

while true; do
  if read -r line < fifo-in; then
    /bin/bash -c "$line" 2>&1
  fi
done

