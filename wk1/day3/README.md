# Day 3 — Users, Permissions, Environment and Bash Scripts

## Goal
Understand identity/permission checks and write Bash diagnostics that validate inputs, dependencies and failure conditions.

## Identity and ownership
```bash
whoami; id; id alice
ls -l /home/alice/secret.txt
chown alice:alice secret.txt
chmod 600 secret.txt
sudo -u bob cat /home/alice/secret.txt
```
- UID identifies a user; GID identifies a group.
- `chown alice:alice` sets user owner and group owner.
- `600`: only owner can read/write. `640`: owner read/write; group read.
- Group membership changes usually require new process/login credentials to take effect.
- Access to a file also requires traversal permission on its parent directories.

## `umask`
`umask` **removes** bits from the mode requested at creation:
```text
result = requested_mode & ~umask
```
Typical requested modes: regular files `666`, directories `777`.

| umask | New file | New directory |
|---|---|---|
| `022` | `644` | `755` |
| `027` | `640` | `750` |
| `077` | `600` | `700` |
| `000` | `666` | `777` |

`umask 000` does **not** make ordinary newly created files executable. Creation mode depends on the application, so these are typical examples.

## Shell variables vs environment
```bash
MY_VAR=hello
bash -c 'echo "$MY_VAR"'     # not inherited unless exported
export MY_VAR
bash -c 'echo "$MY_VAR"'     # inherited
```
- `export` includes a variable in the environment of future child processes.
- Children receive their own environment; changing it does not mutate the parent's environment.
- `$PATH` determines where the shell looks for executable commands.
- `command -v curl >/dev/null 2>&1` checks whether `curl` can be resolved.

## Bash arguments and tests
| Syntax | Meaning |
|---|---|
| `$0` | Script name / invocation |
| `$1`, `$2` | Positional arguments |
| `$#` | Argument count |
| `"$@"` | All arguments, preserving boundaries |
| `${1:-none}` | Default if argument unset or empty |
| `shift 2` | Remove first two arguments |
| `[[ -z "$x" ]]` | String empty |
| `[[ -n "$x" ]]` | String nonempty |
| `[[ -d "$x" ]]` | Directory exists |
| `[[ -f "$x" ]]` | Regular file exists |
| `[[ -r "$x" ]]` | Read access |
| `[[ -w "$x" ]]` | Write access |
| `[[ -x "$x" ]]` | Execute/search access |

**Syntax reminder:** `[[` and `]]` require spaces. `if ! command -v "$cmd"; then` runs a command and tests its exit status; do not put a command invocation inside `[[ ... ]]`.

## Defensive scripting
```bash
#!/usr/bin/env bash
set -euo pipefail
```
- `-e`: exit on many unhandled command failures; **not** a complete exception-free error strategy.
- `-u`: error on unbound variables.
- `pipefail`: detect failures earlier in pipelines.
- `if`, `while`, `&&`, `||` and other contexts have special `set -e` behavior.
- Write errors to stderr with `>&2`; use meaningful nonzero exit statuses.
- Don't automatically install dependencies in a diagnostic script; report what's missing.

## Lab: `diagnose.sh`
Intended invocation:
```bash
./diagnose.sh --path /tmp --require grep --require awk
```
Checklist:
- [ ] `--path` is present and names a directory (empty directories are valid).
- [ ] Each `--require` has a value; repeatable flags are supported.
- [ ] Reject missing values and unknown flags.
- [ ] Print username, UID and umask.
- [ ] Check required commands with `command -v`.
- [ ] Report directory read/write/traverse permissions.
- [ ] Return zero for success and nonzero for invalid inputs or failed checks.

Important pitfalls discovered in the lab:
```bash
[[ -z "$TARGET" || ! -d "$TARGET" ]]   # correct invalid-path test
# NOT: [[ ! -z "$TARGET" || ! -d "$TARGET" ]]

REQUIREMENTS+=("$2")                   # quote array elements
# Before reading $2, validate $# >= 2 and reject option-like missing values.
```

## Active recall
1. Why is `umask 027` different for files and directories?
2. Why does an exported variable appear in a child shell but not vice versa?
3. Why is `"$@"` safer than `$*` for forwarding arguments?
4. Why should missing `--require` values be checked before reading `$2`?
5. What is wrong with `if [[! -r "$TARGET" ]]; then`?
6. Why shouldn't a diagnostic script silently run `sudo apt install`?

## Revisit the lab
Test `diagnose.sh` against `/tmp`, an empty directory, a nonexistent directory, an absent command, missing flag values and unknown flags. Inspect exit codes with `echo $?`.
