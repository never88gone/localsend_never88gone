#!/bin/bash
# LocalSend HarmonyOS Rust 构建脚本
# 
# 使用方法:
#   ./build_rust.sh setup    - 添加 HarmonyOS Rust 目标
#   ./build_rust.sh build    - 编译 Rust 库
#   ./build_rust.sh all      - setup + build
#   ./build_rust.sh clean    - 清理构建

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="$SCRIPT_DIR"
TARGET_DIR="$RUST_DIR/target"

# HarmonyOS Rust 目标
OHOS_TARGETS=(
    "aarch64-unknown-linux-ohos"
    "armv7-unknown-linux-ohos"
    "x86_64-unknown-linux-ohos"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Rust 工具链
check_rust() {
    if ! command -v rustup &> /dev/null; then
        log_error "rustup 未安装，请先安装 Rust: https://rustup.rs"
        exit 1
    fi
    
    if ! command -v cargo &> /dev/null; then
        log_error "cargo 未安装"
        exit 1
    fi
    
    log_info "Rust 工具链检查通过"
    rustc --version
    cargo --version
}

# 添加 HarmonyOS 目标
setup_targets() {
    log_info "添加 HarmonyOS Rust 目标..."
    
    for target in "${OHOS_TARGETS[@]}"; do
        log_info "添加目标: $target"
        rustup target add "$target" || log_warn "目标 $target 可能已存在"
    done
    
    log_info "HarmonyOS 目标设置完成"
}

# 编译 Rust 库
build_rust() {
    log_info "开始编译 Rust 库..."
    
    cd "$RUST_DIR"
    
    # 编译所有 HarmonyOS 目标
    for target in "${OHOS_TARGETS[@]}"; do
        log_info "编译目标: $target"
        
        cargo build --release --target "$target" || {
            log_error "编译 $target 失败"
            exit 1
        }
        
        log_info "完成: $target"
    done
    
    log_info "Rust 库编译完成"
    
    # 显示生成的库文件
    echo ""
    log_info "生成的库文件:"
    for target in "${OHOS_TARGETS[@]}"; do
        lib_path="$TARGET_DIR/$target/release/liblocalsend_harmony.a"
        if [ -f "$lib_path" ]; then
            size=$(ls -lh "$lib_path" | awk '{print $5}')
            echo "  $target: $size"
        fi
    done
}

# 生成 C 头文件
generate_header() {
    log_info "生成 C 头文件..."
    
    cd "$RUST_DIR"
    
    # 确保 cbindgen 已安装
    if ! command -v cbindgen &> /dev/null; then
        log_info "安装 cbindgen..."
        cargo install cbindgen
    fi
    
    # 生成头文件
    cbindgen --config cbindgen.toml --crate localsend_harmony --output "$SCRIPT_DIR/../include/localsend_rust.h" || {
        log_warn "cbindgen 生成失败，使用手动头文件"
    }
    
    log_info "头文件生成完成"
}

# 清理构建
clean_build() {
    log_info "清理构建..."
    cd "$RUST_DIR"
    cargo clean
    log_info "清理完成"
}

# 主函数
main() {
    case "${1:-}" in
        setup)
            check_rust
            setup_targets
            ;;
        build)
            check_rust
            build_rust
            generate_header
            ;;
        all)
            check_rust
            setup_targets
            build_rust
            generate_header
            ;;
        clean)
            clean_build
            ;;
        *)
            echo "使用方法: $0 {setup|build|all|clean}"
            echo ""
            echo "命令说明:"
            echo "  setup  - 添加 HarmonyOS Rust 目标"
            echo "  build  - 编译 Rust 库"
            echo "  all    - setup + build"
            echo "  clean  - 清理构建"
            exit 1
            ;;
    esac
}

main "$@"
