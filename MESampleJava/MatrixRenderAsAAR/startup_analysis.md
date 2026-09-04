# Matrix-Startup 冷启动日志分析报告

## 日志来源

- 设备进程 PID: 10918
- ConnectionId: 963094
- 采样时间: 17:41:51.557 ~ 17:41:55.110
- 时间基准: `SystemClock.uptimeMillis()` (ts 列)

---

## 一、整体时间线总览

| 阶段 | 起始 ts | 结束 ts | 耗时 | 占比 |
|------|---------|---------|------|------|
| **1. 客户端发起绑定** | 30233713 | 30233805 | 92ms | 2.6% |
| **2. Service.onCreate 开销** | 30233805 | 30233812 | 7ms | 0.2% |
| **3. Godot 引擎初始化** | 30233812 | 30237081 | **3269ms** | **92.0%** |
| **4. Service.onBind** | 30237081 | 30237082 | 1ms | 0.0% |
| **5. 客户端 onServiceConnected → 注册成功** | 30237116 | 30237120 | 4ms | 0.1% |
| **6. 客户端 attachSurface（真实）** | 30237121 | 30237125 | 4ms | 0.1% |
| **7. 服务端 attachSurface** | 30237130 | 30237132 | 2ms | 0.1% |
| **8. GL 线程创建真实 Surface** | 30237132 | 30237266 | 134ms | 3.8% |
| **总计（冷启动 → 真实 Surface 就绪）** | 30233713 | 30237266 | **3553ms** | 100% |

---

## 二、详细阶段分析

### 阶段 1：客户端发起绑定（92ms）

```
[SDK] bindToService() called              ts=30233713
[SDK] bindToGodotService BEGIN            ts=30233713  state=DISCONNECTED
[SVC] onCreate BEGIN                      ts=30233805  pid=10918
```

- 客户端调用 `bindToService()` 后，Android 系统启动服务进程并回调 `onCreate()`。
- 92ms 为系统创建服务进程的开销，属正常范围。

### 阶段 2：Service.onCreate 前置开销（7ms）

```
[SVC] onCreate BEGIN                      ts=30233805
[SVC] godotEngineInitialization BEGIN     ts=30233812
```

- 7ms 用于通知渠道创建、前台服务设置等，开销极小。

### 阶段 3：Godot 引擎初始化（3269ms）— 瓶颈

此阶段是冷启动的绝对瓶颈，占总耗时 **92%**。内部细分：

| 子阶段 | 起始 ts | 结束 ts | 耗时 | 说明 |
|--------|---------|---------|------|------|
| Godot.onInit / onCreate | 30233828 | 30233828 | 0ms | 插件注册、命令行解析 |
| **Godot.onInitNativeLayer** | 30233837 | 30237026 | **3189ms** | **C++ 引擎初始化（核心瓶颈）** |
| Godot.onInitRenderViewMatrix | 30237026 | 30237076 | 50ms | GL RenderView 创建 |
| 首帧绘制（1x1 哑 Surface） | 30237076 | 30237077 | 1ms | 内部 dummy surface |
| 收尾 | 30237077 | 30237081 | 4ms | — |

**关键发现：`Godot.onInitNativeLayer` 耗时 3189ms，占总冷启动的 89.8%。**

该阶段调用 `GodotLib.initialize()` + `GodotLib.setup()`，涉及：
- C++ 引擎对象创建
- PCK 资源包加载
- 脚本系统初始化
- 渲染设备创建

### 阶段 4：Service.onBind（1ms）

```
[SVC] onBind BEGIN                        ts=30237081
[SVC] onBind END cost=1ms                 ts=30237082
```

- onBind 在 onCreate 结束后立即触发，仅创建 Messenger，开销可忽略。

### 阶段 5：客户端连接注册（4ms）

```
[SDK] onServiceConnected                  ts=30237116
[SDK] sendRegister retry=5                ts=30237116
[SVC] registerConnection BEGIN            ts=30237117
[SVC] registerConnection: Connected ack   ts=30237118  totalCost=1ms
[SDK] handleRegisterAck CONNECTED         ts=30237120
```

- `onServiceConnected` 在 `onBind END` 后 34ms 触发（系统调度延迟）。
- **注意：`sendRegister retry=5`** — 客户端在服务端就绪前已尝试注册 5 次，说明客户端的注册重试机制在等待服务端初始化期间持续工作。
- 注册到 ACK 往返仅 4ms，IPC 通信效率正常。

### 阶段 6-7：Surface 挂载（6ms）

```
[SDK] attachSurface() begin               ts=30237121
[SDK] SurfaceGodot.attachToService END    ts=30237125  cost=4ms
[SVC] attachSurface BEGIN                 ts=30237130  attempt=0
[SVC] attachSurface END                   ts=30237132  totalCost=2ms
```

- 客户端发送 AttachSurface IPC（4ms）→ 服务端执行 `Godot.onSurfaceCreated` + `onSurfaceChanged`（2ms）。
- **存在重复调用**：服务端 `attachSurface` 被调用了两次（ts=30237130 和 ts=30237135），surfaceId 相同（1445862411），疑似客户端重复发送。

### 阶段 8：GL 线程创建真实 Surface（134ms）

```
[SVC] attachSurface END                   ts=30237132
[SVC] Renderer.onSurfaceCreated id=1445862411  ts=30237266
[SVC] Renderer.onSurfaceChanged id=1445862411 size=2880x1840  ts=30237266
```

- 从服务端 `attachSurface` 完成到 GL 线程回调 `onSurfaceCreated`，间隔 **134ms**。
- 此间隔为 GL 线程调度延迟 + EGL Surface 创建开销。
- 真实 Surface 分辨率为 2880x1840。

---

## 三、问题与发现

### 问题 1：首次 onDrawFrame 记录在 1x1 哑 Surface 上（日志误导）

```
[SVC] Renderer.onSurfaceChanged id=0 size=1x1            ts=30237077
[SVC] first onDrawFrame (GodotLib.step) id=0 cameraId=0  ts=30237077
```

`mFirstFrameLogged` 标志在 id=0 的 1x1 内部哑 Surface 上被置为 `true`，导致真实 Surface（id=1445862411, 2880x1840）的首次绘制未被记录。

**影响**：当前 "first onDrawFrame" 日志不能代表用户实际看到第一帧的时间。

**建议修复**：将 `mFirstFrameLogged` 改为按 surfaceId 跟踪，或仅在真实 Surface（非 id=0 或 size>1x1）上记录首次帧。

### 问题 2：attachSurface 重复调用

```
[SVC] attachSurface BEGIN  ts=30237130  surfaceId=1445862411  attempt=0
[SVC] attachSurface END    ts=30237132  totalCost=2ms
[SVC] attachSurface BEGIN  ts=30237135  surfaceId=1445862411  attempt=0
[SVC] attachSurface END    ts=30237136  totalCost=1ms
```

同一 surfaceId 被挂载了两次。可能是：
- 客户端 `attachAllSurface()` 与 `surfaceChanged` 事件同时触发了两次 AttachSurface IPC。
- 不会导致功能错误（第二次是幂等操作），但产生了不必要的 IPC 开销。

### 问题 3：客户端提前调用 attachSurface（无效尝试）

```
17:41:51.636  [SDK] attachSurface() begin          ts=30233792  (服务端尚未创建)
17:41:54.946  [SDK] SurfaceGodot.attachToService    ts=30237102  (onBind后但未onServiceConnected)
```

第一次 `attachSurface` 在服务端 `onCreate` 之前就调用了（cost=0ms，实际未发送 IPC）。第二次在 `onBind` 后、`onServiceConnected` 前调用（state=BINDING）。这两次都是无效尝试。

### 问题 4：sendRegister 重试 5 次

```
[SDK] sendRegister retry=5  ts=30237116
```

客户端在服务端初始化期间（3269ms）持续重试注册。虽然重试机制保证了连接最终成功，但 retry=5 意味着前 4 次注册请求可能被丢弃或失败。可考虑：
- 在服务端 `onBind` 返回 binder 后再开始注册，减少无效重试。
- 或在客户端收到 `onServiceConnected` 后再发送 `RegisterConnection`。

---

## 四、优化建议

### 优先级 P0：减少 onInitNativeLayer 耗时（3189ms）

这是冷启动的绝对瓶颈。可能的优化方向：

1. **PCK 资源延迟加载**：仅加载启动必需资源，其余异步加载。
2. **C++ 静态初始化优化**：检查全局对象构造函数耗时。
3. **脚本预编译缓存**：若 GDScript 编译在此阶段，考虑缓存编译结果。
4. **渲染设备延迟创建**：将 GL 上下文创建推迟到首帧前。

### 优先级 P1：修复首帧日志准确性

修改 `MatrixGodotRenderer.java` 中的 `mFirstFrameLogged` 逻辑，使其仅在真实 Surface 上记录：

```java
// 方案 A：按 surfaceId 跟踪
private final Set<Integer> mFirstFrameLoggedSurfaceIds = new HashSet<>();

if (isGodotDraw && mFirstFrameLoggedSurfaceIds.add(id)) {
    Log.i("Matrix-Startup", "[SVC] first onDrawFrame surfaceId=" + id + " ...");
}

// 方案 B：跳过 id=0 的哑 Surface
if (isGodotDraw && !mFirstFrameLogged && id != 0) {
    mFirstFrameLogged = true;
    Log.i("Matrix-Startup", "[SVC] first onDrawFrame (real surface) ...");
}
```

### 优先级 P2：减少无效 attachSurface 调用

- 在 `EngineClientGodot.attachSurface()` 中增加状态检查，仅在 `CONNECTED` 状态下才调用 `surfaceGodot.attachToService()`。
- 或在 `SurfaceGodot.attachToService()` 中检查连接状态，非 `CONNECTED` 时排队等待。

### 优先级 P3：减少 GL 线程调度延迟（134ms）

从 `attachSurface END` 到 `Renderer.onSurfaceCreated` 的 134ms 间隔，可调查：
- GL 线程是否在此时被阻塞或休眠。
- 是否需要主动唤醒 GL 线程（如 `requestRender()`）。

---

## 五、时间线可视化

```
ts=30233713 ──┬── 客户端 bindToService
              │
              │  92ms (系统启动服务进程)
              │
ts=30233805 ──┼── Service.onCreate BEGIN
              │
              │  7ms (通知/前台服务设置)
              │
ts=30233812 ──┼── godotEngineInitialization BEGIN
              │
              │  16ms (Godot 构造 + onInit/onCreate)
              │
ts=30233828 ──┤  Godot.onInit / onCreate
              │
              │  9ms
              │
ts=30233837 ──┤  Godot.onInitNativeLayer BEGIN
              │
              │  ╔══════════════════════════════╗
              │  ║  3189ms C++ 引擎初始化       ║  ← 核心瓶颈
              │  ║  (GodotLib.initialize+setup) ║
              │  ╚══════════════════════════════╝
              │
ts=30237026 ──┤  Godot.onInitNativeLayer END
              │
              │  50ms (RenderView 创建)
              │
ts=30237076 ──┤  onInitRenderViewMatrix END
              │  Renderer.onSurfaceCreated id=0 (1x1 哑 Surface)
              │  first onDrawFrame id=0 (哑 Surface 首帧)
              │
              │  5ms
              │
ts=30237081 ──┼── godotEngineInitialization END (3269ms)
              │  Service.onCreate END (3276ms)
              │  Service.onBind BEGIN → END (1ms)
              │
              │  34ms (系统调度 onServiceConnected)
              │
ts=30237116 ──┤  onServiceConnected → sendRegister
              │
              │  4ms (IPC 注册往返)
              │
ts=30237120 ──┤  handleRegisterAck CONNECTED
              │  onGodotConnected → attachSurface
              │
              │  4ms (客户端 attachSurface IPC)
              │  2ms (服务端 attachSurface)
              │
ts=30237132 ──┤  服务端 attachSurface END
              │
              │  134ms (GL 线程调度 + EGL Surface 创建)
              │
ts=30237266 ──┴── Renderer.onSurfaceCreated id=1445862411 (2880x1840)
                  Renderer.onSurfaceChanged id=1445862411 size=2880x1840
                  ★ 真实 Surface 就绪，总耗时 3553ms
```

---

## 六、结论

| 指标 | 值 |
|------|-----|
| 冷启动总耗时 | **3553ms** |
| 核心瓶颈 | `onInitNativeLayer` (C++ 引擎初始化) = **3189ms** (89.8%) |
| IPC 通信总耗时 | ~15ms (可忽略) |
| GL 线程调度延迟 | 134ms |
| 系统调度延迟 | ~126ms (进程创建 + onServiceConnected) |
| 日志准确性问题 | 首帧日志记录在 1x1 哑 Surface 上，需修复 |
