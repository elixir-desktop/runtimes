#!/bin/bash
VERSION=1.16.3
set -e

mkdir $1
cd $1
wget https://github.com/elixir-lang/elixir/archive/v${VERSION}.zip
unzip v${VERSION}.zip
cd elixir-${VERSION}
make
mv * ..


# Install rebar3
echo "Installing rebar3..."
mkdir -p ~/.mix
curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o ~/.mix/rebar3 || {
    # Fallback to GitHub if S3 fails
    curl -fsSL https://github.com/erlang/rebar3/releases/latest/download/rebar3 -o ~/.mix/rebar3
}
chmod +x ~/.mix/rebar3