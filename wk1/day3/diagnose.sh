#!/usr/bin/env bash
set -euo pipefail

TARGET=""
REQUIREMENTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            # TODO: Validate and store the next argument
            if [[ $# -ge 2 ]]; then
		TARGET=$2   
	       	shift 2	
	else
		echo "Invalid arguments"
		exit 2
	    fi
	    ;;
        --require)
            # TODO: Add the next argument to REQUIREMENTS
	    if [[ $# -lt 2 ]]; then
   		 echo "Missing value for --require" >&2
    		exit 2
	    fi
	    REQUIREMENTS+=("$2")
	    shift 2
	    ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

# TODO: Check that TARGET is not empty and is a directory
if [[ -z "$TARGET" || ! -d "$TARGET" ]];  then
	echo "$TARGET is empty or not a directory" >&2;
	exit 2
fi	

# TODO: Print username, UID, and umask
echo "Username: "$(whoami)" UID: "$(id -u)" umask: "$(umask)""
# TODO: Loop through REQUIREMENTS and check each dependency
for cmd in "${REQUIREMENTS[@]}"; do
    # Check each command
    if ! command -v "$cmd"; then
    	echo "not installed "$cmd""
	exit 2
    fi
done
# TODO: Check directory permissions using -r, -w, and -x
if [[ ! -r "$TARGET" || !  -w "$TARGET" || !  -x "$TARGET" ]]; then
	echo "Don'= have -rwx perms"
	exit 2
fi
echo "Diagnostics complete"
