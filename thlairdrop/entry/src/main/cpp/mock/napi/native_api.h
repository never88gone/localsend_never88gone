#ifndef NAPI_NATIVE_API_H
#define NAPI_NATIVE_API_H

#include <stdint.h>
#include <stddef.h>

typedef struct napi_env__* napi_env;
typedef struct napi_value__* napi_value;
typedef struct napi_callback_info__* napi_callback_info;
typedef struct napi_threadsafe_function__* napi_threadsafe_function;

typedef enum {
    napi_default = 0,
    napi_tsfn_release = 0,
    napi_tsfn_blocking = 0
} napi_threadsafe_function_release_mode;

typedef void (*napi_threadsafe_function_call_js)(napi_env env, napi_value js_cb, void* context, void* data);

#define NAPI_AUTO_LENGTH (size_t)(-1)
#define EXTERN_C_START extern "C" {
#define EXTERN_C_END }

typedef napi_value (*napi_callback)(napi_env env, napi_callback_info info);

typedef struct {
    const char* utf8name;
    napi_value name;
    napi_callback method;
    napi_callback getter;
    napi_callback setter;
    napi_value value;
    int attributes;
    void* data;
} napi_property_descriptor;

typedef napi_value (*napi_addon_register_func)(napi_env env, napi_value exports);

typedef struct {
    int nm_version;
    int nm_flags;
    const char* nm_filename;
    napi_addon_register_func nm_register_func;
    const char* nm_modname;
    void* nm_priv;
    void* reserved[4];
} napi_module;

void napi_module_register(napi_module* mod);
void napi_get_cb_info(napi_env env, napi_callback_info info, size_t* argc, napi_value* argv, napi_value* this_arg, void** data);
void napi_get_value_string_utf8(napi_env env, napi_value value, char* buf, size_t bufsize, size_t* result);
void napi_get_value_int32(napi_env env, napi_value value, int32_t* result);
void napi_get_boolean(napi_env env, bool value, napi_value* result);
void napi_create_string_utf8(napi_env env, const char* str, size_t length, napi_value* result);
void napi_create_int32(napi_env env, int32_t value, napi_value* result);
void napi_get_undefined(napi_env env, napi_value* result);
void napi_call_function(napi_env env, napi_value recv, napi_value func, size_t argc, const napi_value* argv, napi_value* result);
void napi_release_threadsafe_function(napi_threadsafe_function func, int mode);
void napi_create_threadsafe_function(napi_env env, napi_value func, napi_value async_resource, napi_value async_resource_name, size_t max_queue_size, size_t initial_thread_count, void* thread_finalize_data, void* thread_finalize_cb, void* context, napi_threadsafe_function_call_js call_js_cb, napi_threadsafe_function* result);
void napi_call_threadsafe_function(napi_threadsafe_function func, void* data, int mode);
void napi_define_properties(napi_env env, napi_value exports, size_t property_count, const napi_property_descriptor* properties);

#endif
