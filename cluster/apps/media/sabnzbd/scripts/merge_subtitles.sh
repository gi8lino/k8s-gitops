#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s nullglob

DEST_DIR="/tv"

# log prints a normal informational message.
log() {
    printf '%s\n' "$*"
}

# skip exits successfully when there is nothing useful or safe to process.
# This prevents SABnzbd from treating intentional skips as script failures.
skip() {
    log "$*"
    exit 0
}

# die exits with an error for real script failures, such as missing tools,
# missing directories, or unsafe file states.
die() {
    log "ERROR: $*" >&2
    exit 1
}

# move_job moves the completed SABnzbd job directory into the final
# destination directory. It changes to / first so the current working
# directory is not inside the folder being moved.
move_job() {
    cd /
    mv -- "$JOB_DIR" "$DEST_DIR"/
}

command -v mkvmerge >/dev/null 2>&1 || die "mkvmerge not found"

JOB_DIR="${SAB_COMPLETE_DIR:-${1:-}}"
PP_STATUS="${SAB_PP_STATUS:-${7:-}}"
SAB_STATE="${SAB_STATUS:-}"

[[ -n "$JOB_DIR" ]] || die "SAB_COMPLETE_DIR / argument 1 is empty"
[[ -d "$JOB_DIR" ]] || die "job directory does not exist: $JOB_DIR"
[[ -d "$DEST_DIR" ]] || die "destination directory does not exist: $DEST_DIR"

case "$PP_STATUS" in
    ""|0)
        ;;
    *)
        skip "SABnzbd post-processing failed; skipping. SAB_PP_STATUS=$PP_STATUS SAB_STATUS=${SAB_STATE:-unknown} SAB_FAIL_MSG=${SAB_FAIL_MSG:-none}"
        ;;
esac

case "${SAB_STATE,,}" in
    ""|completed)
        ;;
    failed|running)
        skip "SABnzbd job is not completed successfully; skipping. SAB_STATUS=$SAB_STATE SAB_FAIL_MSG=${SAB_FAIL_MSG:-none}"
        ;;
    *)
        log "warning: unknown SAB_STATUS=$SAB_STATE; continuing because SAB_PP_STATUS is OK"
        ;;
esac

cd "$JOB_DIR"

mapfile -d '' videos < <(
    find . -type f \
        \( -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mp4' \) \
        ! -iname '*sample*' \
        -print0
)

if ((${#videos[@]} == 0)); then
    skip "no video file to process found - skipping"
fi

if ((${#videos[@]} > 1)); then
    printf 'found multiple video files:\n' >&2
    printf '  %s\n' "${videos[@]}" >&2
    die "refusing to guess which video should receive subtitles"
fi

video="${videos[0]}"

mapfile -d '' raw_subs < <(
    find . -type f \
        \( -iname '*.srt' -o -iname '*.idx' -o -iname '*.sub' \) \
        ! -iname '*sample*' \
        -print0
)

subs=()

for sub in "${raw_subs[@]}"; do
    case "${sub,,}" in
        *.sub)
            # VobSub subtitles are stored as .idx + .sub pairs.
            # mkvmerge should receive the .idx file, not both files separately.
            idx_matches=( "${sub%.*}".[iI][dD][xX] )

            if ((${#idx_matches[@]} > 0)); then
                continue
            fi
            ;;
    esac

    subs+=( "$sub" )
done

if ((${#subs[@]} == 0)); then
    log "no subtitles found - moving job without remuxing"
    move_job
    exit 0
fi

case "${video,,}" in
    *.mkv)
        final="$video"
        ;;
    *)
        # mkvmerge writes Matroska output, even when the input is MP4 or AVI.
        # Use an .mkv extension so the file extension matches the container.
        final="${video%.*}.mkv"
        [[ ! -e "$final" ]] || die "target file already exists: $final"
        ;;
esac

tmp="${final%.*}.merged.$$.mkv"

# cleanup removes an unfinished temporary mux file if mkvmerge or mv fails.
cleanup() {
    [[ -n "${tmp:-}" && -e "$tmp" ]] && rm -f -- "$tmp"
}

trap cleanup EXIT

log "merging subtitles into: $final"

mkvmerge -o "$tmp" "$video" "${subs[@]}"

rm -f -- "$video"
mv -- "$tmp" "$final"
tmp=""

move_job

log "finished merging subtitles"
exit 0
