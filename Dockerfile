FROM dockcross/android-arm

# ENV
ENV NDK_ROOT $CROSS_ROOT
ENV ANDROID_NDK_HOME $CROSS_ROOT
# ENV NDK_ABI_PLAT androideabi$ANDROID_NDK_API
ENV NDK_ABI_PLAT androideabi21
ENV PATH $NDK_ROOT/bin:$PATH
ENV FC= CPP= LD= CC=clang AR=ar

# CC=/usr/arm-linux-androideabi/bin/arm-linux-androideabi-clang

# Setting up openssl
COPY install_openssl.sh /work/  
RUN ARCH="android-arm -D__ANDROID_API__=21" ./install_openssl.sh

# RUN git clone --depth 1 -b diode/beta https://github.com/diodechain/otp.git
RUN git clone --depth 1 -b diode/beta https://github.com/diodechain/otp.git

# We need -z global for liberlang.so because:
# https://android-ndk.narkive.com/iNWj05IV/weak-symbol-linking-when-loading-dynamic-libraries
# https://android.googlesource.com/platform/bionic/+/30b17e32f0b403a97cef7c4d1fcab471fa316340/linker/linker_namespaces.cpp#100
ENV CFLAGS="-Os -fPIC" CXXFLAGS="-Os -fPIC" LDFLAGS="-z global"
ENV LIBS -L$NDK_ROOT/lib64/clang/11.0.5/lib/linux/ /usr/local/openssl/lib/libcrypto.a -lclang_rt.builtins-arm-android
# RUN env
WORKDIR /work/otp
RUN ./otp_build autoconf

# Build with debugger produces
# dbg_wx_filedialog_win.erl:22: behaviour wx_object undefined

# Build run #1, building the x86 based cross compiler which will generate the .beam files
RUN ./otp_build configure --with-ssl=/usr/local/openssl/ --disable-dynamic-ssl-lib --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et --xcomp-conf=xcomp/erl-xcomp-arm-android.conf
RUN ./otp_build boot -a

# Build run #2, now creating the arm binaries, appliying the install flags only here...
ENV INSTALL_PROGRAM "/usr/bin/install -c -s --strip-program=arm-linux-androideabi-strip"
RUN ./otp_build configure --with-ssl=/usr/local/openssl/ --disable-dynamic-ssl-lib --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et --xcomp-conf=xcomp/erl-xcomp-arm-android.conf LDFLAGS="-z global"
RUN ./otp_build release -a