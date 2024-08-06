#!/usr/bin/env bash

if ! command -v mkvmerge >/dev/null; then
  echo "mkvmerge not found"
  exit 1
fi

if [ ! -f /app/sabnzbd/scripts/merge_subtitles.sh ]; then
  echo "merge_subtitles.sh not found"
  exit 1
fi

if [ $(curl --write-out '%{http_code}' --silent --output /dev/null "localhost:8080/api?mode=status&apikey=$(sed --quiet --regexp-extended 's/^api_key\s\=\s(.*)$/\1/p' /config/sabnzbd.ini)") != "200" ]; then
  echo "sabnzbd not ready"
  exit 1
fi
