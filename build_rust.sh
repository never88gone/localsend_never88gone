#!/bin/bash
# 鸿蒙 Rust 交叉编译脚本
# 运行前请确保安装了对应的 Rust targets:
# rustup target add aarch64-unknown-linux-ohos x86_64-unknown-linux-ohos

set -e

# 默认 NDK 路径 (根据实际情况修改)
if [ -z "$OHOS_NDK_HOME" ]; then
    OHOS_NDK_HOME="/Volumes/MacintoshData/Develop/Huawei/OpenHarmony/Sdk/23/native"
fi
NDK_HOME=$OHOS_NDK_HOME

if [ ! -d "$NDK_HOME" ]; then
    echo "未找到 OHOS NDK 在: $NDK_HOME"
    echo "请设置 OHOS_NDK_HOME 环境变量指向您的 NDK 目录。"
    exit 1
fi

echo "使用 NDK: $NDK_HOME"

# 编译器路径
CLANG="$NDK_HOME/llvm/bin/clang"
AR="$NDK_HOME/llvm/bin/llvm-ar"

# 进入 core 目录
cd "$(dirname "$0")/core"

# 编译 aarch64
echo "Compiling for aarch64..."
CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER="$CLANG" \
CC_aarch64_unknown_linux_ohos="$CLANG" \
CXX_aarch64_unknown_linux_ohos="$CLANG++" \
AR_aarch64_unknown_linux_ohos="$AR" \
CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_RUSTFLAGS="-C link-arg=--target=aarch64-linux-ohos" \
cargo build --target aarch64-unknown-linux-ohos --release --lib

# 编译 x86_64
echo "Compiling for x86_64..."
CARGO_TARGET_X86_64_UNKNOWN_LINUX_OHOS_LINKER="$CLANG" \
CC_x86_64_unknown_linux_ohos="$CLANG" \
CXX_x86_64_unknown_linux_ohos="$CLANG++" \
AR_x86_64_unknown_linux_ohos="$AR" \
CARGO_TARGET_X86_64_UNKNOWN_LINUX_OHOS_RUSTFLAGS="-C link-arg=--target=x86_64-linux-ohos" \
cargo build --target x86_64-unknown-linux-ohos --release --lib

# 复制生成的 so 到 harmony/entry/libs
echo "Copying to harmony project..."
DEST_DIR="../thlairdrop/entry/libs"

mkdir -p "$DEST_DIR/arm64-v8a"
mkdir -p "$DEST_DIR/x86_64"

cp target/aarch64-unknown-linux-ohos/release/liblocalsend.so "$DEST_DIR/arm64-v8a/"
cp target/x86_64-unknown-linux-ohos/release/liblocalsend.so "$DEST_DIR/x86_64/"

echo "Done!"
