#!/bin/bash
# =============================================================================
# LocalSend Rust Build Script for HarmonyOS
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="${SCRIPT_DIR}/rust"
TARGET_DIR="${RUST_DIR}/target"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# 检查环境
# =============================================================================

check_rust() {
    if ! command -v rustup &> /dev/null; then
        log_error "Rust not installed. Please install from https://rustup.rs/"
        exit 1
    fi
    
    log_info "Rust version: $(rustc --version)"
}

add_ohos_target() {
    log_info "Adding HarmonyOS Rust targets..."
    
    # HarmonyOS 目标三元组
    rustup target add aarch64-unknown-linux-ohos --toolchain stable 2>/dev/null || true
    rustup target add armv7-unknown-linux-ohos --toolchain stable 2>/dev/null || true
    rustup target add x86_64-unknown-linux-ohos --toolchain stable 2>/dev/null || true
    
    log_success "HarmonyOS targets added"
}

# =============================================================================
# 构建 Rust 库
# =============================================================================

build_rust() {
    local TARGET="$1"
    local RELEASE="${2:-true}"
    
    log_info "Building Rust library for ${TARGET}..."
    
    cd "${RUST_DIR}"
    
    local BUILD_TYPE="debug"
    if [ "$RELEASE" = "true" ]; then
        BUILD_TYPE="release"
    fi
    
    # 设置环境变量
    export RUSTFLAGS="-C target-feature=+crt-static"
    
    # 构建
    if [ "$RELEASE" = "true" ]; then
        cargo build --target "${TARGET}" --release
    else
        cargo build --target "${TARGET}"
    fi
    
    local LIB_PATH="${TARGET_DIR}/${TARGET}/${BUILD_TYPE}/liblocalsend_harmony.a"
    
    if [ -f "$LIB_PATH" ]; then
        log_success "Built: ${LIB_PATH}"
        log_info "Size: $(ls -lh "$LIB_PATH" | awk '{print $5}')"
    else
        log_error "Build failed: ${LIB_PATH} not found"
        return 1
    fi
}

build_all_targets() {
    log_info "Building all HarmonyOS targets..."
    
    local TARGETS=(
        "aarch64-unknown-linux-ohos"
        "armv7-unknown-linux-ohos"
        "x86_64-unknown-linux-ohos"
    )
    
    for TARGET in "${TARGETS[@]}"; do
        build_rust "$TARGET" true || log_warn "Failed to build ${TARGET}"
    done
    
    log_success "All targets built"
}

# =============================================================================
# 生成 C 头文件
# =============================================================================

generate_header() {
    log_info "Generating C header file..."
    
    cd "${RUST_DIR}"
    
    # 使用 cbindgen 生成头文件
    if command -v cbindgen &> /dev/null; then
        cbindgen --config cbindgen.toml --crate localsend_harmony --output "${SCRIPT_DIR}/include/localsend_rust.h"
        log_success "Header generated: include/localsend_rust.h"
    else
        log_warn "cbindgen not found, skipping header generation"
        log_info "Install with: cargo install cbindgen"
    fi
}

# =============================================================================
# 清理
# =============================================================================

clean() {
    log_info "Cleaning build artifacts..."
    
    cd "${RUST_DIR}"
    cargo clean
    
    log_success "Clean complete"
}

# =============================================================================
# 测试
# =============================================================================

test_rust() {
    log_info "Running Rust tests..."
    
    cd "${RUST_DIR}"
    cargo test
    
    log_success "Tests passed"
}

# =============================================================================
# 主函数
# =============================================================================

show_help() {
    echo "LocalSend Rust Build Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build [target]    Build Rust library (default: all targets)"
    echo "  all               Build all HarmonyOS targets"
    echo "  header            Generate C header file"
    echo "  clean             Clean build artifacts"
    echo "  test              Run Rust tests"
    echo "  setup             Setup Rust environment (add targets)"
    echo "  help              Show this help message"
    echo ""
    echo "Targets:"
    echo "  aarch64           arm64-v8a (64-bit ARM)"
    echo "  armv7             armeabi-v7a (32-bit ARM)"
    echo "  x86_64            x86_64 (64-bit x86)"
    echo ""
    echo "Examples:"
    echo "  $0 build aarch64           Build for arm64-v8a"
    echo "  $0 all                     Build all targets"
    echo "  $0 setup && $0 all         Setup and build"
}

main() {
    local COMMAND="${1:-help}"
    
    case "$COMMAND" in
        build)
            check_rust
            local TARGET="${2:-aarch64-unknown-linux-ohos}"
            
            # 简化目标名称
            case "$TARGET" in
                aarch64|arm64)
                    TARGET="aarch64-unknown-linux-ohos"
                    ;;
                armv7|arm32)
                    TARGET="armv7-unknown-linux-ohos"
                    ;;
                x86_64|x64)
                    TARGET="x86_64-unknown-linux-ohos"
                    ;;
            esac
            
            build_rust "$TARGET" true
            generate_header
            ;;
        
        all)
            check_rust
            build_all_targets
            generate_header
            ;;
        
        header)
            generate_header
            ;;
        
        clean)
            clean
            ;;
        
        test)
            test_rust
            ;;
        
        setup)
            check_rust
            add_ohos_target
            ;;
        
        help|--help|-h)
            show_help
            ;;
        
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
