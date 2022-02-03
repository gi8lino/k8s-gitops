#!/usr/bin/env bash

set -o errexit
set -o pipefail

cd "${SAB_COMPLETE_DIR}"

FILENAME=$(find . -type f -name "*.mkv" -and -not -iname "*sample*")

if [ -z "${FILENAME}" ]; then
    echo "no mkv file found - skipping"
    exit 0
fi

SUBS=$(find -type f -name "*.idx" -o -name "*.srt" -o -name "*.sub")

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
