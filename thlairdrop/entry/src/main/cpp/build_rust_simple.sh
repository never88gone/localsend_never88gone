#!/bin/bash
# =============================================================================
# LocalSend HarmonyOS - 简化 Rust 编译脚本
# =============================================================================
# 
# 此脚本使用标准 Linux target 编译 Rust 库
# 适用于快速测试和开发
# 
# 前置要求:
#   1. 安装 Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustups | sh
#   2. 添加 target: rustup target add aarch64-unknown-linux-gnu
# 
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="${SCRIPT_DIR}/rust"

echo "========================================"
echo "LocalSend Rust Build (Simple)"
echo "========================================"

# 检查 Rust
if ! command -v cargo &> /dev/null; then
    echo "Error: Cargo not found!"
    exit 1
fi

cd "${RUST_DIR}"

# 编译 release 版本
echo "Building release..."
cargo build --release

# 显示输出
echo ""
echo "Build output:"
ls -la target/release/*.a 2>/dev/null || echo "No static library found"
ls -la target/release/*.so 2>/dev/null || echo "No shared library found"

echo ""
echo "========================================"
echo "Done!"
echo "========================================"
