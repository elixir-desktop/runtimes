#!/bin/bash
# called with `libtool -static -o <output> <input>...`

# remove the -static flag and handle -o flag properly
output=""
inputs=()
skip_next=false

# Create a temporary directory for extracting .a files
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

for arg in "$@"; do
    if $skip_next; then
        output="$arg"
        skip_next=false
    elif [ "$arg" = "-static" ]; then
        # Skip the -static flag
        continue
    elif [ "$arg" = "-o" ]; then
        skip_next=true
    else
        if [[ "$arg" == *.a ]]; then
            # Convert to absolute path if needed
            abs_path=$(readlink -f "$arg")
            # Extract .a file to temp directory
            mkdir -p "$temp_dir/$(basename "$arg")"
            cd "$temp_dir/$(basename "$arg")"
            ${AR:-ar} x "$abs_path"
            # Add all .o files from the extracted archive
            for obj in *.o; do
                if [ -f "$obj" ]; then
                    inputs+=("$temp_dir/$(basename "$arg")/$obj")
                fi
            done
            cd - > /dev/null
        else
            inputs+=("$arg")
        fi
    fi
done

# Now use the output file as the first argument to ar
echo ${AR:-ar} rcs "$output" "${inputs[@]}"
exec ${AR:-ar} rcs "$output" "${inputs[@]}"
