#!/bin/bash
export VSN=1.1.1v
export VSN_HASH=d6697e2871e77238460402e9362d47d18382b15ef9f246aba6c7bd780d38a6b0

if [ -z "$OPENSSL_PREFIX" ]; then
export PREFIX=/usr/local/openssl
else
export PREFIX=$OPENSSL_PREFIX
fi 

if [ -z "$ARCH" ]; then
export BUILD_DIR=_build
export BASE_DIR=..
else
export BUILD_DIR=_build/$ARCH
export BASE_DIR=../..
fi

# install openssl
echo "Build and install openssl......"
mkdir -p $PREFIX/ssl && \
    mkdir -p $BUILD_DIR && \
    cd $BUILD_DIR && \
    wget -nc https://www.openssl.org/source/openssl-$VSN.tar.gz && \
    [ "$VSN_HASH" = "$(sha256sum openssl-$VSN.tar.gz | cut -d ' ' -f1)" ] && \
    tar xzf openssl-$VSN.tar.gz && \
    cp $BASE_DIR/patch/openssl-ios.conf openssl-$VSN/Configurations/15-ios.conf && \
    cd openssl-$VSN && \
    ./Configure $ARCH --prefix=$PREFIX "$@" && \
    make clean && make depend && make && make install_sw install_ssldirs

