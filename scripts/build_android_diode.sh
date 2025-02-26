#!/bin/bash
export OTP_TAG=OTP-26.2.5.6
export OTP_SOURCE=https://github.com/erlang/otp
mix package.android.runtime2 with_diode_nifs
