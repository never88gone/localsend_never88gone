//! LocalSend HarmonyOS FFI Module
//!
//! This module provides FFI bindings for the LocalSend core library.

// 重新导出 core 库的所有 FFI 函数
pub use localsend::ffi::*;

// 额外的 HarmonyOS 特定功能
use std::ffi::CString;
use std::os::raw::c_char;

/// 获取设备指纹
#[no_mangle]
pub extern "C" fn localsend_get_fingerprint() -> *mut c_char {
    // 生成一个基于设备信息的指纹
    let fingerprint = localsend::crypto::hash::sha256_hex(b"harmonyos-localsend-device");
    let s = CString::new(fingerprint).unwrap();
    s.into_raw()
}

/// 设置设备别名
#[no_mangle]
pub extern "C" fn localsend_set_alias(_alias: *const c_char) -> bool {
    // TODO: 实现设置别名
    true
}

/// 获取已注册设备数量
#[no_mangle]
pub extern "C" fn localsend_get_device_count() -> i32 {
    // TODO: 实现获取设备数量
    0
}

/// 获取已注册设备列表
#[no_mangle]
pub extern "C" fn localsend_get_registered_devices() -> *mut c_char {
    // 返回空数组
    let s = CString::new("[]").unwrap();
    s.into_raw()
}

/// 获取待处理请求
#[no_mangle]
pub extern "C" fn localsend_get_pending_requests() -> *mut c_char {
    // 返回空数组
    let s = CString::new("[]").unwrap();
    s.into_raw()
}

/// 发送多播公告
#[no_mangle]
pub extern "C" fn localsend_send_announcement() -> bool {
    // TODO: 实现多播公告
    true
}

/// 检查服务器是否运行
#[no_mangle]
pub extern "C" fn localsend_is_server_running() -> bool {
    // TODO: 实现检查服务器状态
    false
}
