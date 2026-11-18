#!/usr/bin/env bash -x

MUSL_HASH=6b558025200a5ed1308e2ce2675217afec71b6c5a9d561e52262ca948d59905e
OTP_VERSION=$1
OPENSSL_VERSION=$2

echo $(uname -a)
echo OPENSSL_VERSION=$OPENSSL_VERSION
echo OTP_VERSION=$OTP_VERSION
apk update
apk add automake autoconf gcc curl wget make musl-dev linux-headers patchelf file
wget https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz
wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
tar xzf otp_src_$OTP_VERSION.tar.gz
tar xzf openssl-$OPENSSL_VERSION.tar.gz
mkdir sysroot

# Build OpenSSL
cd openssl-$OPENSSL_VERSION
./config no-asm no-tests no-shared --prefix=$(pwd)/../sysroot
make -j4 && make install_sw
cd ..

# Build Erlang
cd otp_src_$OTP_VERSION
./configure --without-javac --without-jinterface --without-wx --without-termcap --without-megaco --with-ssl=$(pwd)/../sysroot --disable-dynamic-ssl-lib
make -j4
RELEASE_ROOT="$(pwd)/release/otp_aarch64_linux_${OTP_VERSION}" make release -j
cd release/otp*
printf "ERLANG_OTP=$OTP_VERSION\nOPENSSL=$OPENSSL_VERSION\nMUSL_HASH=$MUSL_HASH\n" > burrito_runtime_manifest.txt

# yeehaw - this replaces the musl runtime/interpreter path
find . -executable -exec file {} \; | grep -i ELF | grep -i interpreter | cut -d: -f1 | xargs -I '{}' ash -c "patchelf --set-interpreter /tmp/libc-musl-$MUSL_HASH.so {}"
cd ../

tar czf otp_${OTP_VERSION}_linux_any_aarch64.tar.gz ./otp*
