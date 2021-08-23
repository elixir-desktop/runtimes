FROM dockcross/android-arm

# Setting up openssl
WORKDIR /work/
COPY install_openssl.sh /work/  
RUN ARCH=linux-armv4 ./install_openssl.sh

# RUN git clone --depth 1 -b diode/beta https://github.com/diodechain/otp.git
RUN git clone --depth 1 -b diode/beta https://github.com/diodechain/otp.git
ENV NDK_ROOT $CROSS_ROOT
# ENV NDK_ABI_PLAT androideabi$ANDROID_NDK_API
ENV NDK_ABI_PLAT androideabi19
ENV PATH $NDK_ROOT/bin:$PATH
ENV FC= CPP= LD=
ENV CFLAGS="-Os -fPIC" CXXFLAGS="-Os -fPIC"
ENV LIBS -L$NDK_ROOT/lib64/clang/11.0.5/lib/linux/ -lclang_rt.builtins-arm-android
# RUN env
WORKDIR /work/otp
RUN ./otp_build autoconf
# Build with debugger produces
# dbg_wx_filedialog_win.erl:22: behaviour wx_object undefined
RUN ./otp_build configure --with-ssl=/usr/local/openssl/ --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et --xcomp-conf=xcomp/erl-xcomp-arm-android.conf
# RUN echo "" > ./erts/emulator/sys/unix/erl_main.c
RUN ./otp_build boot -a
RUN ./otp_build release -a