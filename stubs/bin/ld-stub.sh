#!/bin/bash
echo ld.lld "$@"
exec $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld "$@"