CFLAGS=-Os -fPIC
CXXFLAGS=-Os -fPIC
CXX=ccache gcc
CC=ccache gcc

EXCLUDE=--exclude "*/examples/*" --exclude "*.beam" --exclude "*.h" --exclude "*.erl" --exclude "*.c" --exclude "*.a" --exclude "*.hrl"

ANDROID_ARM=armeabi-v7a
ANDROID_ARM64=arm64-v8a

all: ${ANDROID_ARM}/liberlang.so ${ANDROID_ARM64}/liberlang.so

${ANDROID_ARM}/liberlang.so:
	docker build -t liberlang -f xcomp/android-arm.dockerfile .
	mkdir -p ${ANDROID_ARM}
	docker run --rm --entrypoint tar liberlang c -C ./release/arm-unknown-linux-androideabi/erts-12.0/bin . | tar x -C ${ANDROID_ARM}
	docker run --rm --entrypoint find liberlang ./release/arm-unknown-linux-androideabi/ -name "*.so" -exec tar c "{}" + | tar x -C ${ANDROID_ARM}
	mv ${ANDROID_ARM}/beam.smp ${ANDROID_ARM}/liberlang.so

${ANDROID_ARM64}/liberlang.so:
	docker build -t liberlang64 -f xcomp/android-arm64.dockerfile .
	mkdir -p ${ANDROID_ARM64}
	docker run --rm --entrypoint tar liberlang64 c -C ./release/aarch64-unknown-linux-android/erts-12.0/bin . | tar x -C ${ANDROID_ARM64}
	docker run --rm --entrypoint find liberlang64 ./release/aarch64-unknown-linux-android/ -name "*.so" -exec tar c "{}" + | tar x -C ${ANDROID_ARM64}
	mv ${ANDROID_ARM64}/beam.smp ${ANDROID_ARM64}/liberlang64.so

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
test_main: src/test_main.cpp liberlang.so
	$(CXX) $(INCLUDE) -D_GNU_SOURCE src/test_main.cpp -L./ -lerlang -lstdc++ -lpthread -o test_main
