# Day 1 — Filesystems and Shell Fundamentals

## Goal
Navigate and inspect Linux filesystems confidently, and understand what files, links, permissions and file descriptors mean at the kernel level.

## Core mental model
- A **pathname** is a directory-entry-based route to a file; it is not the file itself.
- An **inode** stores file metadata (owner, permissions, size, timestamps, link count, pointers to data), not the filename.
- A **directory** maps names to inode numbers.
- A **file descriptor (FD)** is a per-process integer referring to an open file description in the kernel. Duplicated or inherited FDs can share a file offset.

## Commands to know
```bash
pwd; ls -lah; cd /tmp
mkdir -p app/{src,logs,config}
cp source dest; mv old new; rm file
stat file; file file; ls -li file
ln original hardlink
ln -s original symlink
readlink symlink
find . -type f -name '*.log'
du -sh .; df -h .
id; whoami; chmod 640 file; chown user:group file
ls -ld directory
man stat
```

## Hard links vs symbolic links
| Property | Hard link | Symbolic link |
|---|---|---|
| Refers to | Same inode | Pathname |
| Inode | Shared | Own inode |
| Survives removal of original name | Yes | Usually becomes dangling |
| Cross-filesystem | Generally no | Yes |
| Directory links | Normally prohibited | Allowed |

`rm`/`unlink()` removes a directory entry, not necessarily the underlying file data. Data can remain until both the link count is zero and no process has the file open.

## Permissions
- File: `r` read contents, `w` modify contents, `x` execute.
- Directory: `r` list names, `w` change entries (usually requires `x` too), `x` traverse/search.
- `chmod 750 dir` → owner `rwx`, group `r-x`, others `---`.
- The **sticky bit** on a shared writable directory (e.g. `/tmp`) restricts who can delete/rename entries, even when directory write permission exists.
- Access checks depend on effective credentials, groups, ACLs and other security controls, not just the mode bits shown by `ls`.

## FDs and offsets
- `0` stdin, `1` stdout, `2` stderr.
- `fork()` inherits descriptors referring to the same open file descriptions; offsets may therefore be shared.
- `dup()` also refers to the same open file description.
- Two independent `open()` calls normally create separate open file descriptions and offsets.
- Inspect with `ls -l /proc/$$/fd`.

## `du` vs `df`
- `du` estimates disk usage attributable to reachable directory trees.
- `df` reports filesystem allocation/free space.
- An unlinked but still-open file can consume space shown by `df` without being reachable by `du`.

## Common traps
- A symlink's target path may be relative to the symlink's directory, not your shell's working directory.
- `chmod` on a directory has different implications from `chmod` on a file.
- Removing a pathname does not immediately invalidate an already-open FD.
- `ls -l` shows permissions; `stat` gives richer metadata.

## Active recall — answer without notes
1. What is the difference between a filename, inode, and FD?
2. Why does deleting an open log file not always free disk space?
3. Why do hard links share content but symlinks can become dangling?
4. What does the `x` bit mean on a directory?
5. How can two processes share a file offset?
6. Why might `du` and `df` disagree?

## Revisit the lab
Inspect `app/` and `final-challenge/`. Use `stat`, `ls -li`, `readlink`, and `/proc/$$/fd` to explain what you observe.
