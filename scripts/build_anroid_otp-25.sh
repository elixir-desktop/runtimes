#!/bin/bash
export OTP_TAG=OTP-25.0.4
export OTP_SOURCE=https://github.com/erlang/otp
mix package.android.runtime
mix package.android.nif
