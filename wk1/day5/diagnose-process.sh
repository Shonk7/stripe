#!/usr/bin/env bash
set euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <PID>" >&2
    exit 1
fi

PID="$1"

if [[ ! "$PID" =~ ^[0-9]+$ ]] || [[ ! -d "/proc/$PID" ]]; then
    echo "Invalid or nonexistent PID: $PID" >&2
    exit 1
fi

STATUS="/proc/$PID/status"
STAT="/proc/$PID/stat"

echo "========== PROCESS DIAGNOSTIC REPORT =========="
echo "PID: $PID"
echo -e "$(grep -E "Name|State|PPid|Threads" "$STATUS")\n "

echo "========== MEMORY  =========="
echo -e "$(grep -E "VmSize|VmRSS|VmPeak|VmHWM" "$STATUS")\n"

echo "========== CPU  =========="
sed 's/^.*) //' "$STAT" | awk -v hz="$(getconf CLK_TCK)" '
{
    printf "User CPU time: %.2f seconds\n", $12 / hz
    printf "System CPU time: %.2f seconds\n", $13 / hz
}'

echo -e  "\n========== CONTEXT SWITCHES  =========="
echo -e "$(grep -E "voluntary_ctxt_switches|non_voluntary_ctxt_switches" "$STATUS")\n"

echo -e  "========= FILE DESCRIPTORS  =========="
for fd in /proc/"$PID"/fd/*; do
    [[ -e "$fd" || -L "$fd" ]] || continue
    fd_num=${fd##*/}
    target=$(readlink "$fd") || continue

    printf '%s -> %s\n' "$fd_num" "$target"
    
done
echo -e  "\n========= MEMORY MAPPINGS  =========="
echo -e "Total VMAs: $(wc -l < /proc/"$PID"/maps)\n"
