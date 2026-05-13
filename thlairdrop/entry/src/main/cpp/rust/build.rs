use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=src/lib.rs");

    // 生成 C 头文件
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_path = PathBuf::from(&crate_dir).join("..").join("include").join("localsend_rust.h");

    // 确保输出目录存在
    if let Some(parent) = out_path.parent() {
        std::fs::create_dir_all(parent).ok();
    }

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_language(cbindgen::Language::C)
        .with_include_guard("LOCALSEND_RUST_H")
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(&out_path);

    println!("cargo:warning=Generated C header at: {:?}", out_path);
}
