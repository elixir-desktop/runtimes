#!/bin/bash
VERSION=1.13.4
set -e

mkdir $1
cd $1
wget https://github.com/elixir-lang/elixir/archive/v${VERSION}.zip
unzip v${VERSION}.zip
cd elixir-${VERSION}
make
mv * ..
