CFLAGS=-Os -fPIC
CXXFLAGS=-Os -fPIC
CXX=ccache gcc
CC=ccache gcc

.PHONY: docker
docker:
	docker build -t liberlang .

otp:
	git clone --depth 1 -b diode/beta https://github.com/diodechain/otp.git

.PHONY: local
local: otp
	cd otp; ./otp_build autoconf
	cd otp; ./otp_build configure --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et
#	echo "" > ./otp/erts/emulator/sys/unix/erl_main.c
	cd otp; ./otp_build boot -t

liberlang.so: otp/bin/x86_64-unknown-linux-gnu/beam.smp
	cp $< $@

BUILD=x86_64-unknown-linux-gnu
INCLUDE=-I./otp/erts/emulator/sys/common/ -I./otp/erts/emulator/sys/unix/ -I./otp/erts/emulator/beam/ -I./otp/erts/include/internal/ -I./otp/erts/include/$(BUILD)/ -I./otp/erts/include/internal/$(BUILD)/ -I./otp/erts/emulator/$(BUILD)/opt/jit/ -I./otp/erts/$(BUILD)/
test_main: src/test_main.c liberlang.so
	$(CC) $(INCLUDE) -L./ -lerlang -D_GNU_SOURCE src/test_main.c -o test_main