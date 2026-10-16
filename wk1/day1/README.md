# Day 1 — Linux Filesystem Fundamentals

## Topics covered
- Linux navigation and shell commands
- Filesystem metadata and inodes
- Hard links and symbolic links
- File descriptors and open file descriptions
- fork(), dup(), and shared file offsets
- unlink() and file lifetimes
- du vs df
- Unix permissions and chmod
- Users, groups, and effective UIDs

## Key takeaways
- Filenames are directory entries that reference inodes.
- Hard links share an inode; symbolic links store a pathname.
- File descriptors reference open file descriptions.
- Deleting a pathname does not necessarily destroy the file.
- Directory permissions control traversal and entry modification.
- Linux selects owner, group, or others permissions based on process credentials.
