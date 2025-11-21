#!/bin/bash
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    openssl-3.0.9 \
    zlib-1.3.1 \
    curl-8.8.0 \
    ohos-sdk \
    curl-8.8.0-ohos-arm64 \
    zlib-1.3.1-ohos-arm64 \
    openssl-3.0.9-ohos-arm64

# 准备 ohos-sdk
mkdir ohos-sdk
curl -L -O https://repo.huaweicloud.com/openharmony/os/6.0-Release/ohos-sdk-windows_linux-public.tar.gz
tar -zxf ohos-sdk-windows_linux-public.tar.gz -C ohos-sdk
cd ohos-sdk/linux
unzip -q native-*.zip
cd ../..

# 设置交叉编译所需的环境变量
export OHOS_SDK=${WORKDIR}/ohos-sdk/linux
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=aarch64-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=aarch64-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-D__MUSL__=1"
export CXXFLAGS="-D__MUSL__=1"

# 编译 openssl
curl -L -O https://github.com/openssl/openssl/releases/download/openssl-3.0.9/openssl-3.0.9.tar.gz
tar -zxf openssl-3.0.9.tar.gz
cd openssl-3.0.9/
./Configure --prefix=${WORKDIR}/openssl-3.0.9-ohos-arm64 linux-aarch64 no-shared
make -j$(nproc)
make install
cd ..

# 编译 zlib
curl -L -O https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=${WORKDIR}/zlib-1.3.1-ohos-arm64 --static
make -j$(nproc)
make install
cd ..

# 编译 curl
curl -L -O  https://curl.se/download/curl-8.8.0.tar.gz
tar -zxf curl-8.8.0.tar.gz
cd curl-8.8.0/
./configure \
    --host=aarch64-linux \
    --prefix=${WORKDIR}/curl-8.8.0-ohos-arm64 \
    --enable-static \
    --disable-shared \
    --with-openssl=${WORKDIR}/openssl-3.0.9-ohos-arm64 \
    --with-zlib=${WORKDIR}/zlib-1.3.1-ohos-arm64 \
    --with-ca-bundle=/etc/ssl/certs/cacert.pem \
    --with-ca-path=/etc/ssl/certs \
    CPPFLAGS="-D_GNU_SOURCE"
make -j$(nproc)
make install
cd ..

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
curl_license=$(cat curl-8.8.0/COPYING; echo)
openssl_license=$(cat openssl-3.0.9/LICENSE.txt; echo)
openssl_authors=$(cat openssl-3.0.9/AUTHORS.md; echo)
zlib_license=$(cat zlib-1.3.1/LICENSE; echo)
printf '%s\n' "$(cat <<EOF
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

curl
=============
$curl_license

openssl
=============
==license==
$openssl_license
==authors==
$openssl_authors

zlib
=============
$zlib_license
EOF
)" > curl-8.8.0-ohos-arm64/licenses.txt

# 打包最终产物
tar -zcf curl-8.8.0-ohos-arm64.tar.gz curl-8.8.0-ohos-arm64
