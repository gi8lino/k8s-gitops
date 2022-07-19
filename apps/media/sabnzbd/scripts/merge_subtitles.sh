#!/usr/bin/env bash

set -o errexit
set -o pipefail

cd "${SAB_COMPLETE_DIR}"

FILENAME=$(find . -type f \( -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mp4' \) -and -not -iname "*sample*")

if [ -z "${FILENAME}" ]; then
    echo "no file to process found - skipping"
    exit 0
fi

SUBS=$(find -type f -iname "*.idx" -o -iname "*.srt" -o -name "*.sub")

if [ -z "${SUBS}" ]; then
    echo "no subs found - skipping"
    mv "$SAB_COMPLETE_DIR" /tv/
    exit 0
fi

while IFS= read -r SUB; do
    mkvmerge -o ${FILENAME}.merged ${FILENAME} ${SUB}
    rm -f ${FILENAME}
    mv ${FILENAME}.merged ${FILENAME}
done <<< "${SUBS}"

mv "$SAB_COMPLETE_DIR" /tv/
echo "finished merging subtitles"

exit 0
