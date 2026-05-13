use std::ffi::CStr;
use std::os::raw::c_char;
use std::sync::Mutex;
use std::thread;
use once_cell::sync::Lazy;
use tokio::sync::oneshot;
use crate::http::server::{start_with_port, TlsConfig};
use crate::http::state::ClientInfo;

// 全局的关闭信道
static SHUTDOWN_TX: Lazy<Mutex<Option<oneshot::Sender<()>>>> = Lazy::new(|| Mutex::new(None));

#[no_mangle]
pub extern "C" fn localsend_rust_hello() -> *mut c_char {
    let s = std::ffi::CString::new("Hello from Localsend Rust Core!").unwrap();
    s.into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn localsend_rust_free_string(s: *mut c_char) {
    if s.is_null() { return }
    let _ = std::ffi::CString::from_raw(s);
}

#[no_mangle]
pub extern "C" fn localsend_start_server(alias: *const c_char, port: u16) -> bool {
    let alias_str = unsafe {
        if alias.is_null() {
            "HarmonyOS Device".to_string()
        } else {
            CStr::from_ptr(alias).to_string_lossy().into_owned()
        }
    };

    let mut tx_guard = SHUTDOWN_TX.lock().unwrap();
    if tx_guard.is_some() {
        return false; // Already running
    }

    let (tx, rx) = oneshot::channel();
    *tx_guard = Some(tx);

    thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
            
        rt.block_on(async {
            let info = ClientInfo {
                alias: alias_str,
                version: "1.0".to_string(),
                device_model: Some("OpenHarmony Device".to_string()),
                device_type: Some(crate::model::discovery::DeviceType::Mobile),
                token: "random-token".to_string(),
            };

            if let Err(e) = start_with_port(port, None, info, true, rx).await {
                eprintln!("Failed to start localsend server: {}", e);
            }
        });
        
        if let Ok(mut lock) = SHUTDOWN_TX.lock() {
            *lock = None;
        }
    });

    true
}

#[no_mangle]
pub extern "C" fn localsend_stop_server() {
    let mut tx_guard = SHUTDOWN_TX.lock().unwrap();
    if let Some(tx) = tx_guard.take() {
        let _ = tx.send(());
    }
}

#[no_mangle]
pub extern "C" fn localsend_scan_devices() -> *mut c_char {
    // TODO: 实现真实的 UDP 发现。目前返回 Mock 数据以供 UI 测试。
    let mock_data = r#"[
        {"alias":"Mate 60 Pro","address":"192.168.1.101","port":53317,"deviceModel":"ALN-AL80","deviceType":"mobile"},
        {"alias":"MacBook Pro","address":"192.168.1.50","port":53317,"deviceModel":"MacBookPro18,2","deviceType":"desktop"},
        {"alias":"iPad Air","address":"192.168.1.120","port":53317,"deviceModel":"iPad13,1","deviceType":"tablet"}
    ]"#;
    let s = std::ffi::CString::new(mock_data).unwrap();
    s.into_raw()
}

#[no_mangle]
pub extern "C" fn localsend_get_network_info() -> *mut c_char {
    // 返回 Mock 网络信息
    let mock_info = r#"{"interfaces":[{"name":"wlan0","ipv4":"192.168.1.100","ipv6":"fe80::1"}]}"#;
    let s = std::ffi::CString::new(mock_info).unwrap();
    s.into_raw()
}

#[no_mangle]
pub extern "C" fn localsend_send_request(target_ip: *const c_char, port: u16, files_json: *const c_char) -> bool {
    // TODO: 实现发送逻辑
    true
}

