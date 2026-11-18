#!/usr/bin/env bash -x

OTP_VERSION=$1
OPENSSL_VERSION=$2

echo $(uname -a)
echo OPENSSL_VERSION=${OPENSSL_VERSION}
echo OTP_VERSION=${OTP_VERSION}
brew update && brew upgrade
brew install autoconf elixir
wget https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz
wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
mkdir sysroot
tar xzf otp_src_$OTP_VERSION.tar.gz
tar xzf openssl-$OPENSSL_VERSION.tar.gz

# Build OpenSSL
cd openssl-$OPENSSL_VERSION
CC="cc -arch x86_64 -arch arm64" ./config no-tests no-shared no-asm --prefix=$(pwd)/../sysroot
CC="cc -arch x86_64 -arch arm64" make && make install_sw
cd ..

# Build Erlang (x86_64)
cd otp_src_$OTP_VERSION
arch -x86_64 ./configure --without-javac --without-jinterface --without-wx --without-termcap --without-megaco --with-ssl=$(pwd)/../sysroot --disable-dynamic-ssl-lib
arch -x86_64 make -j4
arch -x86_64 make release -j

# Build Erlang/OTP (aarch64)
arch -arm64 ./configure --without-javac --without-jinterface --without-wx --without-termcap --without-megaco --with-ssl=$(pwd)/../sysroot --disable-dynamic-ssl-lib
arch -arm64 make -j4
arch -arm64 make release -j

# Combine in universal release
cd release
mkdir otp_universal_apple_darwin_$OTP_VERSION
printf "ERLANG_OTP=$OTP_VERSION\nOPENSSL=$OPENSSL_VERSION\n" > otp_universal_apple_darwin_$OTP_VERSION/burrito_runtime_manifest.txt
merge-lipo.pl $(pwd)/x86_64* $(pwd)/aarch64* $(pwd)/otp_universal_apple_darwin_$OTP_VERSION
cp -r $(pwd)/x86_64*/erts-*/include/ $(pwd)/otp_universal_apple_darwin_$OTP_VERSION/erts-*/

tar czf otp_${OTP_VERSION}_macos_universal.tar.gz ./otp_universal_apple_darwin_$OTP_VERSION
