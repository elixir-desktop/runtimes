#!/bin/bash

# ensure there is rebar3 in path
export PATH=$PATH:~/.mix
unset CC
unset CXX

# mix has priority over `make` for projects like exqlite
if [ -f "mix.exs" ]; then
    exec mix do deps.get, release --overwrite
fi

if [ -f "Makefile" ]; then
    exec make
fi

if [ -f "rebar.config" ]; then
    exec /root/.mix/rebar3 compile
fi

echo "Could not identify how to build this nif"
exit 1