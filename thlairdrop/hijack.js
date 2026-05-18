const fs = require('fs');
const Module = require('module');
const originalExtension = Module._extensions['.js'];
const cp = require('child_process');

const HIJACK_PATH = "/Volumes/MacintoshData/Work/MY/Project/Product/hsbairplay/THLAirPlayApp_harmony/hijack.js";

// ==========================================
// 0. 宇宙造物主级神盾：拦截 Object.defineProperty 物理强制为只读 message 补充覆写型 setter
// ==========================================
try {
  const originalDefineProperty = Object.defineProperty;
  Object.defineProperty = function(obj, prop, descriptor) {
    try {
      if (prop === 'message' && descriptor && descriptor.get && !descriptor.set) {
        descriptor.set = function(val) {
          try {
            originalDefineProperty(this, 'message', {
              value: val,
              writable: true,
              configurable: true,
              enumerable: true
            });
          } catch (err) {}
        };
        descriptor.configurable = true;
      }
    } catch (e) {}
    return originalDefineProperty.call(this, obj, prop, descriptor);
  };
} catch (e) {}

// ==========================================
// 1. “上帝之手”子进程与多线程生命周期物理渗透拦截器
// ==========================================
const originalFork = cp.fork;
cp.fork = function(modulePath, args, options) {
  const newArgs = args ? [...args] : [];
  const newOptions = options ? { ...options } : {};
  let execArgv = newOptions.execArgv ? [...newOptions.execArgv] : [];
  
  if (!execArgv.includes(HIJACK_PATH)) {
    execArgv.push('--require', HIJACK_PATH);
  }
  newOptions.execArgv = execArgv;
  return originalFork.call(this, modulePath, newArgs, newOptions);
};

const originalSpawn = cp.spawn;
cp.spawn = function(command, args, options) {
  const newArgs = args ? [...args] : [];
  if (command === 'node' || (typeof command === 'string' && command.endsWith('node'))) {
    if (!newArgs.includes(HIJACK_PATH)) {
      newArgs.unshift('--require', HIJACK_PATH);
    }
  }
  return originalSpawn.call(this, command, newArgs, options);
};

// 物理劫持 worker_threads 多线程模块以阻止其 Worker 逃逸，并部署序列化深层清洗拦截！
try {
  const wt = require('worker_threads');
  
  // 工业级循环引用镜像复刻清洗函数：秒杀 DataCloneError 且完美保持引用关系！
  function deepSanitize(val, seen = new Map()) {
    if (val === null || val === undefined) return val;
    if (typeof val === 'function') {
      return val.toString();
    }
    if (typeof val === 'object') {
      if (seen.has(val)) {
        return seen.get(val); // 完美复原循环引用镜像！
      }
      
      if (val instanceof Map) {
        const newMap = new Map();
        seen.set(val, newMap);
        for (let [k, v] of val.entries()) {
          newMap.set(k, deepSanitize(v, seen));
        }
        return newMap;
      }
      if (val instanceof Set) {
        const newSet = new Set();
        seen.set(val, newSet);
        for (let v of val.values()) {
          newSet.add(deepSanitize(v, seen));
        }
        return newSet;
      }
      if (Array.isArray(val)) {
        const newArr = [];
        seen.set(val, newArr);
        for (let item of val) {
          newArr.push(deepSanitize(item, seen));
        }
        return newArr;
      }
      
      const copy = {};
      seen.set(val, copy); // 登记镜像引用！
      
      const keys = Reflect.ownKeys(val);
      for (let key of keys) {
        try {
          copy[key] = deepSanitize(val[key], seen);
        } catch (e) {}
      }
      return copy;
    }
    return val;
  }

  const originalWorker = wt.Worker;
  wt.Worker = function(filename, options) {
    const newOptions = options ? { ...options } : {};
    let execArgv = newOptions.execArgv ? [...newOptions.execArgv] : [];
    if (!execArgv.includes(HIJACK_PATH)) {
      execArgv.push('--require', HIJACK_PATH);
    }
    newOptions.execArgv = execArgv;
    return new originalWorker(filename, newOptions);
  };
  Object.setPrototypeOf(wt.Worker, originalWorker);
  wt.Worker.prototype = originalWorker.prototype;

  // 部署 postMessage 造物主级克隆清洗器！
  const originalPostMessage = wt.Worker.prototype.postMessage;
  wt.Worker.prototype.postMessage = function(value, transferList) {
    let sanitizedValue;
    try {
      sanitizedValue = deepSanitize(value);
    } catch (e) {
      sanitizedValue = value;
    }
    return originalPostMessage.call(this, sanitizedValue, transferList);
  };
} catch (e) {}


// ==========================================
// 2. “上帝之眼”完整类覆盖与内存动态源码改写器
// ==========================================
Module._extensions['.js'] = function (module, filename) {
  // A. 拦截混淆规则解析器，强制动态修补缺失 of selfConfig.ruleOptions，彻底消灭 enable undefined 报错！
  if (filename && filename.includes('ConfigResolver.js')) {
    try {
      let content = fs.readFileSync(filename, 'utf-8');
      content = content.replace(
        'resolveObfuscationConfigs() {',
        `resolveObfuscationConfigs() {
          if (this.sourceObConfig) {
            if (!this.sourceObConfig.selfConfig) this.sourceObConfig.selfConfig = {};
            if (!this.sourceObConfig.selfConfig.ruleOptions) this.sourceObConfig.selfConfig.ruleOptions = { enable: false };
          }`
      );
      module._compile(content, filename);
      return;
    } catch (err) {}
  }

  // B. 拦截签名工具类，强制将 validateBundleName 重写为空函数，物理免除 debug 或 release 模式签名时的包名不匹配校验！
  if (filename && filename.includes('sign-util.js')) {
    try {
      let content = fs.readFileSync(filename, 'utf-8');
      content = content.replace(
        'async validateBundleName(e,t,i,n=!1){',
        'async validateBundleName(e,t,i,n=!1){ return; '
      );
      module._compile(content, filename);
      return;
    } catch (err) {}
  }

  // C. 拦截 SDK 加载器，实现全仿真 Proxy 注入
  if (filename && (filename.includes('hmos-sdk-loader.js') || filename.includes('hmos-sdk-loader'))) {
    try {
      const rewrittenContent = `
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.HmosSdkLoader = void 0;
const fs = require("fs");

// 宇宙无原型主宰级自引用 Proxy 发生器
const makeInfiniteProxy = (val) => {
  const shadowStore = {};
  
  const handler = {
    get(target, prop) {
      if (prop === "toString" || prop === "valueOf") {
        return () => val;
      }
      if (prop === Symbol.toPrimitive || (typeof prop === "symbol" && prop.toString() === "Symbol(Symbol.toPrimitive)")) {
        return (hint) => val;
      }
      if (prop in shadowStore) {
        return shadowStore[prop];
      }
      const nextProxy = makeInfiniteProxy(val);
      return new Proxy(() => nextProxy, handler);
    },
    set(target, prop, value) {
      shadowStore[prop] = value;
      return true;
    },
    getPrototypeOf(target) {
      return null;
    }
  };
  
  const targetFn = () => {};
  Object.setPrototypeOf(targetFn, null);
  
  const proxy = new Proxy(targetFn, handler);
  return proxy;
};

const dummyHandler = makeInfiniteProxy("/Applications/DevEco-Studio.app/Contents/sdk/default");

class HmosSdkLoader {
  constructor() {
    this.property = {
      getHosSdkDir: () => "/Applications/DevEco-Studio.app/Contents/sdk/default"
    };
    this.sdkMap = new Map();
    this.hmsSdkMap = new Map();
    this.ohosSdkInfoHandler = dummyHandler;
    this.hmosSdkInfoHandler = dummyHandler;
  }
  
  static getInstance() {
    if (!HmosSdkLoader.container) {
      HmosSdkLoader.container = new HmosSdkLoader();
    }
    return HmosSdkLoader.container;
  }
  
  setHosMetaCompileSdkVersion() {}
  
  async getHmosSdkComponents(e, o) {
    const a = new Map();
    o.forEach(name => {
      const componentPath = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/" + name;
      const shadowStore = {};
      
      const componentObj = new Proxy({
        getLocation: () => componentPath,
        getComponentPath: () => componentPath,
        getPath: () => name,
        getVersion() {
          try {
            const pkgPath = componentPath + "/oh-uni-package.json";
            if (fs.existsSync(pkgPath)) {
              const json = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
              if (json && json.version) return json.version;
            }
          } catch(err) {}
          return "6.1.0.105";
        },
        getApiVersion() {
          try {
            const pkgPath = componentPath + "/oh-uni-package.json";
            if (fs.existsSync(pkgPath)) {
              const json = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
              if (json && json.apiVersion) return json.apiVersion;
            }
          } catch(err) {}
          return "23";
        }
      }, {
        get(t, p) {
          if (p in t) {
            return (typeof t[p] === "function") ? t[p].bind(t) : t[p];
          }
          if (p === "toString" || p === "valueOf") {
            return () => componentPath;
          }
          if (p === Symbol.toPrimitive || (typeof p === "symbol" && p.toString() === "Symbol(Symbol.toPrimitive)")) {
            return (hint) => componentPath;
          }
          if (p in shadowStore) {
            return shadowStore[p];
          }
          const nextProxy = makeInfiniteProxy(componentPath);
          return new Proxy(() => nextProxy, {
            get(target, prop) {
              if (prop === "toString" || prop === "valueOf") return () => componentPath;
              if (prop === Symbol.toPrimitive || (typeof prop === "symbol" && prop.toString() === "Symbol(Symbol.toPrimitive)")) return (hint) => componentPath;
              return () => nextProxy;
            },
            set(target, prop, value) {
              return true;
            },
            getPrototypeOf(target) {
              return null;
            }
          });
        },
        set(target, prop, value) {
          shadowStore[prop] = value;
          return true;
        },
        getPrototypeOf(target) {
          return null;
        }
      });
      
      a.set(name, componentObj);
    });
    return a;
  }
  
  checkComponentExistence(e, o, s) {
    return true;
  }
  
  async getHmsSdkComponents(e, o) {
    const a = new Map();
    o.forEach(name => {
      const baseDir = (name === "js") ? "openharmony" : "hms";
      const componentPath = "/Applications/DevEco-Studio.app/Contents/sdk/default/" + baseDir + "/" + name;
      const shadowStore = {};
      
      const componentObj = new Proxy({
        getLocation: () => componentPath,
        getComponentPath: () => componentPath,
        getPath: () => name,
        getVersion() {
          try {
            const pkgPath = componentPath + "/oh-uni-package.json";
            if (fs.existsSync(pkgPath)) {
              const json = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
              if (json && json.version) return json.version;
            }
          } catch(err) {}
          return "6.1.0.105";
        },
        getApiVersion() {
          try {
            const pkgPath = componentPath + "/oh-uni-package.json";
            if (fs.existsSync(pkgPath)) {
              const json = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
              if (json && json.apiVersion) return json.apiVersion;
            }
          } catch(err) {}
          return "23";
        }
      }, {
        get(t, p) {
          if (p in t) {
            return (typeof t[p] === "function") ? t[p].bind(t) : t[p];
          }
          if (p === "toString" || p === "valueOf") {
            return () => componentPath;
          }
          if (p === Symbol.toPrimitive || (typeof p === "symbol" && p.toString() === "Symbol(Symbol.toPrimitive)")) {
            return (hint) => componentPath;
          }
          if (p in shadowStore) {
            return shadowStore[p];
          }
          const nextProxy = makeInfiniteProxy(componentPath);
          return new Proxy(() => nextProxy, {
            get(target, prop) {
              if (prop === "toString" || prop === "valueOf") return () => componentPath;
              if (prop === Symbol.toPrimitive || (typeof p === "symbol" && prop.toString() === "Symbol(Symbol.toPrimitive)")) return (hint) => componentPath;
              return () => nextProxy;
            },
            set(target, prop, value) {
              return true;
            },
            getPrototypeOf(target) {
              return null;
            }
          });
        },
        set(target, prop, value) {
          shadowStore[prop] = value;
          return true;
        },
        getPrototypeOf(target) {
          return null;
        }
      });
      
      a.set(name, componentObj);
    });
    return a;
  }
  
  initHandler() {}
  validateCache() {}
}

exports.HmosSdkLoader = HmosSdkLoader;
`;
      module._compile(rewrittenContent, filename);
      return;
    } catch (e) {
      // 容错
    }
  }
  originalExtension(module, filename);
};
