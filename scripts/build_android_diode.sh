#!/bin/bash
export OTP_TAG=OTP-26.2.5.6
export OTP_SOURCE=https://github.com/erlang/otp
export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/26.1.10909125/
mix package.android.runtime2 with_diode_nifs
