CFLAGS=-Os -fPIC
CXXFLAGS=-Os -fPIC
CXX=ccache gcc
CC=ccache gcc

EXCLUDE=--exclude "*/examples/*" --exclude "*.beam" --exclude "*.h" --exclude "*.erl" --exclude "*.c" --exclude "*.a" --exclude "*.hrl"


armeabi-v7a/liberlang.so:
	docker build -t liberlang .
	mkdir -p armeabi-v7a
	docker run --rm --entrypoint tar liberlang c -C ./release/arm-unknown-linux-androideabi/erts-12.0/bin . | tar x -C armeabi-v7a
	docker run --rm --entrypoint find liberlang ./release/arm-unknown-linux-androideabi/ -name "*.so" -exec tar c "{}" + | tar x -C armeabi-v7a
	mv armeabi-v7a/beam.smp armeabi-v7a/liberlang.so
	# docker run --rm --entrypoint tar liberlang c $(EXCLUDE) -C /work/otp/release/arm-unknown-linux-androideabi/ . > armeabi-v7a/otp.tar

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
