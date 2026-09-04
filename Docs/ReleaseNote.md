# Matrix Engine 1.3.0

## Matrix 版本摘要

### Matrix-1.3.0 版本

#### 1. 新增特性

- **Godot 引擎基线**
  - 合入 Godot 引擎 4.7 分支，基础版本由 4.6.1 升级至 4.7.1-rc。

- **Android 与 Matrix 服务**
  - 重构 Matrix SDK、客户端/服务端组件及 Java 包命名空间，统一服务、资产加载器、PCK 管理和渲染视图接口。
  - 增加集成演示应用、前台服务通知和心跳处理。
  - 支持多视口 Vulkan 适配；设备不支持 Vulkan 时自动降级到 GLES3。

- **渲染与内容能力**
  - 引入数据管线 MatrixData 服务和 AIDL 通信，支持数据查询、数据接收、连接初始化和动态 native SO 加载。
  - 引入并完善 SR 渲染模块基础能力，包括对象池、车道线、斑马线、Stop Line、Road Edge 和 SurfaceBuilder。
  - 增强 IBL、环境贴图、地面反射和 Matrix ACES 色调映射材质支持。
  - 改进 Compatibility/GLES3 的 TAA 静态收敛和动态场景检测。
  - 优化 Camera3D 控制器，移除 SpringArm3D 依赖并增加投影偏移配置。

#### 2. bug 修复

- 修复 Android 14+ 后台冻结导致的黑屏和连接延迟。
- 修复后台回前台时渲染线程和 Surface 附着问题。
- 修复 EGL Surface 生命周期问题：创建失败记录、空指针判断、销毁前解绑当前 Surface，降低 `EGL_BAD_ALLOC` 和黑屏风险。
- 修复 TAA 收敛后动态效果被冻结的问题。
- 延迟 Matrix delegate 创建到场景初始化阶段，修复测试启动时的 MatrixManager 生命周期问题。
- 修复 Inspector 插件、LicenseManager、CommandTool/ProfilerService 和静态 `StringName` 相关资源泄漏。

#### 3. 构建与发布

- Android AAR 构建从 `flatDir` 本地库切换为 Gradle project dependencies，修复 fat AAR 未重新打包更新 native library 的问题。
- 增加 Android 发布版本 Godot 库构建任务、构建体积优化和 map 文件分析工具。
- 支持 release 构建 profile、签名和 debug symbols 配置，并通过构建选项裁剪不使用的模块。
- 增加 Windows 编辑器、Android 服务 AAR 和 release 同步流程的自动化检查。

### Matrix-1.2.0 版本

1. `Matrix-1.2.0` 是本次版本比较的上一个正式版本 tag。
2. 本文不重复展开 1.2.0 的历史条目，1.3.0 的所有变更均以该 tag 为比较基线。

### Matrix-1.1.0 版本

#### 1. 新增特性

- 多视口渲染增加独立世界能力，只显示 `MultiSurfViewport` 节点下的内容。
- 增加多视口拉伸模式配置：
  - `Ignore = 0`：保持原有像素，不缩放。
  - `Keep = 1`：保持原有宽高比。
  - `Keep_Width = 2`：保持宽度。
  - `Keep_Height = 3`：保持高度。
  - `Expend = 4`：平铺。
- 增加数据表资源类 `DataTable`。
- 增强 `CommandTool`，增加常用 ADB、性能 stat、timescale、debug remote 和 debug wireframe 指令。
- 增加 `CameraController3D`，支持单指滑动、双指缩放、预设镜头平滑切换和镜头回正。

#### 2. bug 修复

- 增强 CS 连接稳定性。
- 修复 `SurfaceGodot` 触摸事件处理和生命周期管理问题。
- 简化 PCK 文件可用性检查逻辑。

### Matrix-1.0.1 版本

#### 1. 新增特性

- 添加 Java 与 C++ 的 JNI 信号通道。

### Matrix-1.0.0 版本

#### 1. 新增特性

- 增加多视口渲染功能，基于 `MultiSurfViewport` 类。
- 增加屏幕日志打印功能，基于 `CommandTool` 类。
