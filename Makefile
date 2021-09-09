CFLAGS=-Os -fPIC
CXXFLAGS=-Os -fPIC
CXX=ccache gcc
CC=ccache gcc

ANDROID_ARM=armeabi-v7a
ANDROID_ARM64=arm64-v8a
ANDROID_X86_64=x86_64

all: ${ANDROID_X86_64}-runtime.zip ${ANDROID_ARM}-runtime.zip ${ANDROID_ARM64}-runtime.zip

${ANDROID_ARM}-runtime.zip:
	docker build -t liberlang-${ANDROID_ARM} -f xcomp/android-arm.dockerfile .
	mkdir -p _build/${ANDROID_ARM}
	docker run --rm -w /work/otp/release/arm-unknown-linux-androideabi/ --entrypoint find liberlang-${ANDROID_ARM} . \( -name "*.so" -or -path "*erts-*/bin/*" \) -exec tar c "{}" + | tar x -C _build/${ANDROID_ARM}
	find _build/${ANDROID_ARM} -name beam.smp -execdir mv beam.smp liberlang.so \;
	cd _build/${ANDROID_ARM}; zip ../../${ANDROID_ARM}-runtime -r .

${ANDROID_ARM64}-runtime.zip:
	docker build -t liberlang-${ANDROID_ARM64} -f xcomp/android-arm64.dockerfile .
	mkdir -p _build/${ANDROID_ARM64}
	docker run --rm -w /work/otp/release/aarch64-unknown-linux-android/ --entrypoint find liberlang-${ANDROID_ARM64} . \( -name "*.so" -or -path "*erts-*/bin/*" \) -exec tar c "{}" + | tar x -C _build/${ANDROID_ARM64}
	find _build/${ANDROID_ARM64} -name beam.smp -execdir mv beam.smp liberlang.so \;
	cd _build/${ANDROID_ARM64}; zip ../../${ANDROID_ARM64}-runtime -r .

${ANDROID_X86_64}-runtime.zip:
	docker build -t liberlang-${ANDROID_X86_64} -f xcomp/android-x86_64.dockerfile .
	mkdir -p _build/${ANDROID_X86_64}
	docker run --rm -w /work/otp/release/x86_64-pc-linux-android/ --entrypoint find liberlang-${ANDROID_X86_64} . \( -name "*.so" -or -path "*erts-*/bin/*" \) -exec tar c "{}" + | tar x -C _build/${ANDROID_X86_64}
	find _build/${ANDROID_X86_64} -name beam.smp -execdir mv beam.smp liberlang.so \;
	cd _build/${ANDROID_X86_64}; zip ../../${ANDROID_X86_64}-runtime -r .

.PHONY: clean
clean:
	-rm -rf _build *.zip

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
