#!/bin/bash
export OTP_TAG=OTP-26.2.5.6
export OTP_SOURCE=https://github.com/erlang/otp
export OTP_SOURCE=$HOME/projects/otp
mix package.android.runtime with_diode_nifs
