# Day 2 — Pipes, Redirection and Log Analysis

## Goal
Compose reliable shell pipelines to transform and investigate text data without writing a full program.

## Standard streams and redirection
- FD `0`: stdin; FD `1`: stdout; FD `2`: stderr.
- `>` overwrites stdout destination; `>>` appends.
- `2> errors.txt` redirects stderr; `2>&1` makes stderr point where stdout currently points.
- **Order matters:** `cmd >out 2>&1` combines both into `out`; `cmd 2>&1 >out` leaves stderr at the original stdout destination.
- `cmd1 | cmd2` connects `cmd1` stdout to `cmd2` stdin. Stderr is not piped by default.

```bash
ls /missing >output.txt 2>errors.txt
ls /missing >combined.txt 2>&1
cat app.log | grep ERROR | wc -l
```

## Exit status and pipe failures
- `$?` is the status of the last foreground command/pipeline.
- Convention: `0` success; nonzero failure (meaning varies by command).
- Without `pipefail`, a pipeline's status is usually that of its last command.
- `set -o pipefail` makes a pipeline fail if any command fails (status of rightmost failing command).
- A producer may receive `SIGPIPE` when its pipe reader exits early (e.g. `head`).

## Quoting and expansion
```bash
name='hello world'
printf '%s\n' "$name"   # one argument
printf '%s\n' $name     # word splitting: two arguments
printf '%s\n' "$(pwd)"  # command substitution
printf '%s\n' *.log     # glob expansion
```
- Prefer double quotes around variable expansions (`"$file"`).
- Single quotes prevent parameter and command expansion.
- `$(command)` substitutes captured stdout; it does not capture stderr by default.

## Text processing toolkit
| Command | Main purpose | Example |
|---|---|---|
| `grep` | Filter matching lines | `grep 'ERROR' app.log` |
| `cut` | Select delimited fields | `cut -d ' ' -f 4-` |
| `sort` | Order lines | `sort` / `sort -rn` |
| `uniq -c` | Count **adjacent** equal lines | `sort | uniq -c` |
| `wc -l` | Count lines | `wc -l < app.log` |
| `head` / `tail` | First / last lines | `head -n 5` |
| `sed` | Stream editing | `sed 's/ERROR/CRITICAL/g'` |
| `awk` | Field processing/aggregation | `awk '{print $2}'` |

`uniq` only combines consecutive duplicates; **sort first** for frequency counts.

## Lab log format
Synthetic `app.log` contains 1,000 lines in the form:
```text
TIMESTAMP LEVEL SERVICE MESSAGE...
```
The lab script `analyse.sh` produces `report.txt`.

## Useful pipelines
```bash
# Count severities
awk '{print $2}' app.log | sort | uniq -c | sort -rn

# Errors by service (order unspecified)
awk '$2 == "ERROR" { count[$3]++ }
     END { for (s in count) print s, count[s] }' app.log

# Five most frequent error messages
grep 'ERROR' app.log | cut -d ' ' -f 4- | sort | uniq -c | sort -rn | head -n 5

# Count ERROR lines
grep -c 'ERROR' app.log

# Preview a replacement without modifying the file
sed 's/ERROR/CRITICAL/g' app.log | head
```

## Common traps
- `grep` with no matches returns `1`, which may interact with `set -e` / `pipefail`.
- `head` can close a pipe early, causing upstream `SIGPIPE`.
- `sed -i` modifies the file; omit `-i` to preview.
- `awk` associative-array iteration order is not guaranteed; sort the output if ordering matters.
- `echo "$(pipeline)"` is usually redundant; run the pipeline directly.
- Space-delimited `cut` assumes consistent formatting; use `awk` when fields are variable.

## Active recall
1. Why does `2>&1 >file` behave differently from `>file 2>&1`?
2. Why must `sort` usually precede `uniq -c`?
3. What changes when `pipefail` is enabled?
4. What does `awk '$2 == "ERROR"'` test?
5. Why can `grep ... | head` report a failure under `pipefail`?
6. When would you choose `awk` instead of `cut`?

## Revisit the lab
Run `./analyse.sh app.log > report.txt`, verify the counts and manually inspect the top error messages.
