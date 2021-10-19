FROM dockcross/android-<%= @arch.id %>

# ENV
ENV NDK_ROOT $CROSS_ROOT
ENV ANDROID_NDK_HOME $CROSS_ROOT
ENV NDK_ABI_PLAT <%= @arch.android_name %><%= @arch.abi %>
ENV PATH $NDK_ROOT/bin:$PATH
ENV FC= CPP= LD= CC=clang AR=ar
ENV MAKEFLAGS "-j10 -O"

# Setting up openssl
COPY scripts/install_openssl.sh /work/
COPY patch /work/patch

# OpenSSL fails to detect this: 
RUN cp ${NDK_ROOT}/bin/llvm-ar ${NDK_ROOT}/bin/<%= @arch.cpu %>-linux-<%= @arch.android_name %>-ar
RUN cp ${NDK_ROOT}/bin/llvm-ranlib ${NDK_ROOT}/bin/<%= @arch.cpu %>-linux-<%= @arch.android_name %>-ranlib

RUN ARCH="android-<%= @arch.id %> -D__ANDROID_API__=<%= @arch.abi %>" ./install_openssl.sh

# Fetching OTP
RUN git clone <%= Runtimes.otp_source() %> otp && cd otp && git checkout <%= Runtimes.otp_tag() %>

<%= if @arch.id == "arm" do %>
ENV LIBS -L$NDK_ROOT/lib64/clang/12.0.5/lib/linux/ /usr/local/openssl/lib/libcrypto.a -lclang_rt.builtins-arm-android
<% else %>
ENV LIBS /usr/local/openssl/lib/libcrypto.a
<% end %>

# We need -z global for liberlang.so because:
# https://android-ndk.narkive.com/iNWj05IV/weak-symbol-linking-when-loading-dynamic-libraries
# https://android.googlesource.com/platform/bionic/+/30b17e32f0b403a97cef7c4d1fcab471fa316340/linker/linker_namespaces.cpp#100
ENV CFLAGS="-Os -fPIC" CXXFLAGS="-Os -fPIC" LDFLAGS="-z global"
# RUN env
WORKDIR /work/otp
RUN ./otp_build autoconf

# Build with debugger produces
# dbg_wx_filedialog_win.erl:22: behaviour wx_object undefined

# Build run #1, building the x86 based cross compiler which will generate the .beam files
<% 
config = "--with-ssl=/usr/local/openssl/ --disable-dynamic-ssl-lib --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et --xcomp-conf=xcomp/erl-xcomp-#{@arch.id}-android.conf"
config = if @arch.id == "x86_64", do: "--disable-jit #{config}", else: config
%>
RUN ./otp_build configure <%= config %>
RUN ./otp_build boot -a

# Build run #2, now creating the arm binaries, appliying the install flags only here...
ENV INSTALL_PROGRAM "/usr/bin/install -c -s --strip-program=llvm-strip"
RUN ./otp_build configure <%= config %> LDFLAGS="-z global"
RUN ./otp_build release -a
