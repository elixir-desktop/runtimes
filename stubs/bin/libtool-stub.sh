#!/bin/bash
# called with `libtool -static -o <output> <input>...`

# remove the -static flag and handle -o flag properly
output=""
inputs=()
skip_next=false

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
        inputs+=("$arg")
    fi
done

# Now use the output file as the first argument to ar
exec ${AR:-ar} rcs "$output" "${inputs[@]}"
