# /bin/bash
export VSN=1.1.1k
export VSN_HASH=892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5
export PREFIX=/usr/local/openssl

# install openssl
echo "Build and install openssl......"
mkdir -p $PREFIX/ssl && \
    wget https://www.openssl.org/source/openssl-$VSN.tar.gz && \
    [ "$VSN_HASH" = "$(sha256sum openssl-$VSN.tar.gz | cut -d ' ' -f1)" ] && \
    tar xzf openssl-$VSN.tar.gz && \
    cd openssl-$VSN && \
    ./Configure $ARCH --prefix=$PREFIX "$@" && \
    make depend && make && make install_sw install_ssldirs

