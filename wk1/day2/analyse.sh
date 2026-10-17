#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-app.log}"

echo "===== APPLICATION LOG REPORT ====="
echo

echo "Total events: $(wc -l < "$LOG_FILE")"
echo "Total errors: $(grep -c ' ERROR ' "$LOG_FILE" || true)"
echo "Total warnings: $(grep -c ' WARN ' "$LOG_FILE" || true)"

echo
echo "Events by severity:"
echo "$(awk '{print($2)}' "$LOG_FILE" | sort | uniq -c | sort -rn)"


echo
echo "Errors by service:"
echo "$(awk '$2 == "ERROR" {count[$3]++} END {for (service in count) print service, count[service]}' "$LOG_FILE")"

echo
echo "Top 5 error messages:"
echo "$(grep 'ERROR' "$LOG_FILE" | cut -d ' ' -f 4- | sort | uniq -c | sort -rn)"
echo
echo "===== END REPORT ====="
