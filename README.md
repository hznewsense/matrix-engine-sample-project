# MESample

<p align="left">
  <img alt="Matrix Engine" src="https://img.shields.io/badge/Matrix%20Engine-1.3.0-blue">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Windows%20%7C%20Android-green">
  <img alt="Language" src="https://img.shields.io/badge/C%2B%2B-20-orange">
</p>

MESample 是 Matrix 引擎官方提供的 **3D Launcher + SR Sample Project**。项目基于 **Matrix Engine 1.3.0** 开发，面向智能座舱 3D HMI 场景，演示 3D 车控、SR 可视化、多屏渲染、Render as Service、Used as Library 等核心能力，可作为引擎学习、功能演示、性能验证和二次开发的 Starter Kit。

> Matrix Engine 是面向智能座舱场景的 3D HMI 引擎，覆盖编辑开发、运行调试、集成打包和量产部署全流程。

---

## 目录

- [项目定位](#项目定位)
- [Matrix 引擎能力概览](#matrix-引擎能力概览)
- [功能亮点](#功能亮点)
- [仓库结构](#仓库结构)
- [快速上手](#快速上手)
- [打开 MESample Matrix 工程](#打开-mesample-matrix-工程)
- [Android 工程结构与接入方式](#android-工程结构与接入方式)
- [Android 集成模式与打包部署](#android-集成模式与打包部署)
- [License 说明](#license-说明)
- [二次开发建议](#二次开发建议)
- [常见问题](#常见问题)
- [参考文档](#参考文档)


---

## 项目定位

MESample 主要用于以下场景：

- **引擎环境搭建与安装验证**：帮助开发者快速验证 Matrix Engine 编辑器、编译链路和 Android 部署链路是否可用。
- **基础功能演示**：展示 3D Launcher、SR 画面、车漆切换、车内外细节查看、多视图输出等典型车机 HMI 能力。
- **性能测试基线**：可作为渲染、内存、CPU/GPU 占用等指标的初始对照工程。
- **HMI Starter Kit**：提供可扩展的项目结构、C++ 业务模块和 Android 接入样例，便于在此基础上进行品牌化和量产级二次开发。

---

## Matrix 引擎能力概览

Matrix Engine 是专为汽车智能座舱打造的全栈式 3D HMI 引擎方案，核心由 Runtime、编辑器、工具链和模板工程组成。

| 模块 | 说明 | 在 MESample 中的体现 |
| --- | --- | --- |
| **Matrix Runtime** | 引擎运行时基座，可作为 Android 独立 Service 运行，也可打包为 AAR 嵌入客户 App。 | `MESampleJava/MatrixRenderAsService/MatrixRenderService` 展示 Render as Service，`MESampleJava/MatrixRenderAsAAR` 展示 Used as Library。 |
| **Matrix Core** | Matrix Engine 的车机化适配层，增强多视图渲染、平台抽象、安全隔离、部署配置等能力。 | 支持 Single Instance、多 Surface、多 Camera、多屏输出。 |
| **Matrix Framework** | 面向车机业务的上层框架，提供数据管线、算法库、通信库、逻辑功能库等通用能力。 | 为 3D Launcher / SR 业务提供可复用的车辆状态、场景和交互基础能力。 |
| **Matrix 编辑器** | 面向车模、场景、镜头、UI 等车机场景提供可视化工具。 | 必须使用 `MatrixEngine/Matrix1.3.0.exe` 打开本工程。 |
| **Matrix 工具链** | 覆盖数据录制回放、自动化测试、打包部署、日志分析等工程化能力。 | 可接入后续自动化构建、台架调试和性能测试流程。 |
| **模板工程** | 提供 ADAS、3D Launcher、APA、AI 等常见车机 HMI 模板。 | 本项目可视为 3D Launcher + SR 示例模板。 |

---

## 功能亮点

- **高质量 3D 车模展示**  
  支持车身、内饰、轮毂、灯光、车漆等细节展示；基于 PBR 材质实现车漆金属感、清漆层和环境反射效果。

- **3D Launcher 交互样例**  
  包含车内外细节查看、镜头切换、车辆状态展示等基础 Launcher 功能。

- **SR 可视化样例**  
  提供 SR 显示窗口，可用于展示智能驾驶可视化、环境感知或车辆周边信息的渲染能力。

- **Render as Service**  
  Matrix 引擎运行在独立 Android Service 中，HMI / SR App 通过连接 Service 并传入 Surface 获取渲染画面，实现渲染逻辑与客户端 App 解耦。

- **Multi-View / Single Instance**  
  在单一引擎实例内输出多路渲染画面，不同 View 可绑定不同 Camera 和 RenderTarget，适用于中控屏、仪表屏、副驾屏等多屏座舱场景。

- **Used as Library 能力验证**  
  支持将引擎能力以 AAR 方式集成到客户 App，为深度嵌入式集成提供参考。

- **C++ 业务扩展**  
  通过 GDExtension 集成 C++ 业务代码，便于接入车辆状态、仿真数据、通信链路和高性能业务逻辑。

---



## 仓库结构

> 实际目录名称以仓库为准，以下为推荐 README 说明结构。

```text
.
├── MatrixEngine/                         # Matrix Engine 编辑器目录
│   └── Matrix1.3.0.exe                   # 必须使用该编辑器打开 MESample 工程
│
├── MESample/                             # Matrix 工程目录
│   ├── Source/                           # C++ 源码与构建脚本
│   │   ├── SConstruct                    # SCons 主构建脚本
│   │   ├── godot-cpp/                    # Godot C++ 绑定，通常以 submodule 管理
│   │   └── MESample/                     # 业务源码
│   │       ├── Common/                   # 通用能力与工具类
│   │       ├── SelfVehicle/              # 自车模型与车辆状态逻辑
│   │       └── Simulation/               # 仿真数据与演示逻辑
│   │
│   ├── bin/                              # 编译产物输出目录
│   │   ├── MESample.gdextension
│   │   ├── libMESample.windows.template_debug.x86_64.dll
│   │   └── libMESample.android.template_release.arm64.so
│   │
│   └── Pck/                              # 资产打包产物，例如 game.pck
│
├── MESampleJava/                         # Android 工程目录
│   ├── MatrixRenderAsService/            # Render as Service 聚合工程
│   │   ├── MatrixRenderService/          # Android 渲染服务模块，加载 Runtime / so / game.pck
│   │   ├── MatrixHMI/                    # Android HMI 客户端模块，输出 3D Launcher 画面
│   │   └── MatrixSR/                     # Android SR 客户端模块，输出 SR 画面
│   └── MatrixRenderAsAAR/                # Used as Library 示例工程
│       ├── app/                          # Android Demo 应用，集成 Matrix SDK AAR 和 game.pck
│       ├── gradle/                       # Gradle Wrapper 与版本管理
│       └── README.md                     # AAR 集成说明与运行步骤
│
└── Docs/                                 # 设计文档、图片等补充材料
```

---

## 快速上手

所有从环境配置到生成 APK 的执行流程，统一以 [QuickStart.md](./QuickStart.md) 为准。

首次拉起工程，建议优先执行：

```bat
setup.bat
build.bat --so
build.bat --pck
build.bat --apk-service
build.bat --apk-lib
```

如果希望一键完成全部构建，也可以直接执行：

```bat
build.bat
```

如果需要分步骤执行，也请直接参考 [QuickStart.md](./QuickStart.md) 中这些命令：

```bat
build.bat --so
build.bat --pck
build.bat --apk-service
build.bat --apk-lib
build.bat --clean-pck
```

说明：

- `setup.bat` 负责解析并配置 Python、SCons、Android SDK、Android NDK、JDK 相关环境；必要时会自动安装缺失依赖。
- `setup.bat` 会优先读取并维护仓库根目录的 `.setup-user-env.cmd`，用于保存用户确认过的 Android SDK 路径。
- `build.bat` 启动时会读取 `.setup-user-env.cmd`，输出本次构建使用的 SDK / NDK / JDK / Gradle 信息，并在执行 Gradle 前自动同步 Android 工程的 `local.properties`。
- `build.bat` 负责生成 `.so`、`game.pck`，拷贝 Android 侧资源，并构建 `apk-service` 与 `apk-lib` 两类 APK 产物。
- 4 个 APK 的用途、安装方式和启动顺序，请直接参考 [QuickStart.md](./QuickStart.md) 的 “APK 用途、安装与启动” 章节。

---

## 打开 MESample Matrix 工程

> 注意：本工程依赖 Matrix Engine 1.3.0，必须使用仓库内 `MatrixEngine/Matrix1.3.0.exe` 打开。其他版本的编辑器不保证兼容。

推荐步骤：

1. 启动 `MatrixEngine/Matrix1.3.0.exe`。
2. 在项目管理器中选择 `MESample` Matrix 工程目录。
3. 打开工程后检查 GDExtension 是否正确加载。
4. 在编辑器内预览 3D Launcher / SR 场景，确认资源、脚本和插件无报错。

---

## Android 工程结构与接入方式

构建流程、命令和产物路径统一参考 [QuickStart.md](./QuickStart.md)。

MESample Android 侧包含两类示例工程：

- `MESampleJava/MatrixRenderAsService/`：Render as Service 聚合工程。
- `MESampleJava/MatrixRenderAsAAR/`：Used as Library 示例工程，用于展示将 Matrix Runtime 以 AAR 方式集成到单个 Android App。

`MESampleJava/MatrixRenderAsService/` 当前包含 3 个模块：

| 工程路径 | 类型 | 作用 | 主要参考文档 |
| --- | --- | --- | --- |
| `MESampleJava/MatrixRenderAsService/MatrixRenderService` | 服务端 / Render as Service | 独立运行 Matrix Runtime，加载业务 `.so` 与 `game.pck`，向 HMI / SR 输出多路渲染画面。 | [服务端接入文档](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsService/MatrixRenderService/服务端接入文档.md>) |
| `MESampleJava/MatrixRenderAsService/MatrixHMI` | 客户端 / Super Client | 连接 RenderService，传入 HMI Surface，显示 3D Launcher 画面。 | [超级客户端接入文档](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsService/MatrixHMI/超级客户端接入文档.md>) |
| `MESampleJava/MatrixRenderAsService/MatrixSR` | 客户端 / Super Client | 连接 RenderService，传入 SR Surface，显示 SR 可视化画面。 | [超级客户端接入文档](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsService/MatrixHMI/超级客户端接入文档.md>) |

`MESampleJava/MatrixRenderAsAAR/` 目录结构可概括为：

```text
MESampleJava/MatrixRenderAsAAR/
├── app/                  # Used as Library Demo App
├── gradle/               # Gradle Wrapper 配置
├── gradlew.bat           # Windows 构建入口
├── settings.gradle       # 工程模块声明
└── README.md             # Used as Library 接入说明
```

Used as Library 的工程结构、依赖方式、AAR / `game.pck` 放置、服务启动方式与运行步骤，请直接参考 [MESampleJava/MatrixRenderAsAAR/README.md](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsAAR/README.md>)。

> README 仅保留架构说明和关键接入链路；完整构建流程请以 [QuickStart.md](./QuickStart.md) 为准。完整 API、生命周期回调和排障说明请以各模块内文档为准。

构建产物与资源拷贝补充：

- 完整执行 `build.bat` 时，会同时生成 `apk-service` 和 `apk-lib` 两类 APK。
- `game.pck` 会复制到 `MESampleJava/MatrixRenderAsService/MatrixRenderService/src/main/assets/game.pck`。
- `libMESample.android.template_release.arm64.so` 会复制到 `MESampleJava/MatrixRenderAsService/MatrixRenderService/jniLibs/arm64-v8a/libMESample.android.template_release.arm64.so`。
- `game.pck` 也会复制到 `MESampleJava/MatrixRenderAsAAR/app/src/main/assets/game.pck`，供 `apk-lib` 使用。
- `libMESample.android.template_release.arm64.so` 也会复制到 `MESampleJava/MatrixRenderAsAAR/merge/jniLibs/arm64-v8a/libMESample.android.template_release.arm64.so`，供重新打包 AAR 使用。

使用边界：
- `MatrixRenderService` 的 AAR 接入、Application 初始化、PCK / `.so` 资源放置和渲染服务启动方式，以服务端接入文档为准。
- `MatrixHMI` 与 `MatrixSR` 的 Super Client 初始化、服务绑定、`SurfaceView` 接入、生命周期管理，以 [超级客户端接入文档](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsService/MatrixHMI/超级客户端接入文档.md>) 为准。
- `Used as Library` 的工程结构、依赖方式和集成限制，以 [MESampleJava/MatrixRenderAsAAR/README.md](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsAAR/README.md>) 为准。
- `game.pck`、Android `.so` 和 APK 的生成、清理、拷贝路径与命令，以 [QuickStart.md](./QuickStart.md) 为准。

---

## Android 集成模式与打包部署

这一章按“集成模式选择 -> 参考文档 -> 构建与部署入口”的顺序说明。完整构建命令、资源拷贝路径、单独构建 `.so` / `pck` / APK 的流程统一参考 [QuickStart.md](./QuickStart.md)。

### Render as Service

Render as Service 是 MESample 默认重点演示的集成方式。Matrix Runtime 运行在 `MESampleJava/MatrixRenderAsService/MatrixRenderService` 独立 Android Service 中，`MESampleJava/MatrixRenderAsService/MatrixHMI` 与 `MESampleJava/MatrixRenderAsService/MatrixSR` 通过连接 Service 并传入 Surface 接收渲染结果。

适合场景：

- 多 App 共用同一个渲染实例。
- HMI、SR、仪表等多屏多窗口需要统一渲染调度。
- 希望渲染进程与业务 App 进程隔离，提高稳定性。
- 客户端 App 前后台切换时仍希望渲染服务保持生命周期。

核心特点：

- 支持多客户端连接。
- 支持一个客户端关联多个 Surface。
- 支持不同 Surface 渲染不同 Camera 视角。
- 支持进程级隔离，降低客户端异常对渲染服务的影响。

接入与部署入口：

- 服务端接入说明以 [服务端接入文档](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsService/MatrixRenderService/服务端接入文档.md>) 为准。
- 客户端接入说明以 [超级客户端接入文档](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsService/MatrixHMI/超级客户端接入文档.md>) 为准。
- `game.pck`、Android `.so` 和 `apk-service` 的 3 个 APK 生成、清理与拷贝命令以 [QuickStart.md](./QuickStart.md) 为准。

APK 安装示例：

```bash
adb install -r Apks/MatrixRenderService.apk
adb install -r Apks/MatrixHMI.apk
adb install -r Apks/MatrixSR.apk
```

启动顺序：
1. 先启动 `MatrixRenderService` 对应的 Service APK。
2. 再启动 `MatrixHMI` 对应的 HMI APK。
3. 或启动 `MatrixSR` 对应的 SR APK。

### Used as Library

Used as Library 是另一种集成方式，可将 Matrix Runtime 与工程资产打包为 Android 标准 AAR / 资源包，由客户 App 直接集成。

适合场景：

- 单一 App 内深度定制。
- 对启动流程、生命周期、UI 层级有强控制需求。
- 希望减少跨进程通信成本。

接入与部署入口：

- 工程结构、AAR / `game.pck` 放置、服务启动与运行步骤以 [MESampleJava/MatrixRenderAsAAR/README.md](</E:/Work/Matrix/template/MESample/MESampleJava/MatrixRenderAsAAR/README.md>) 为准。
- `apk-lib` 的生成命令、`game.pck` 拷贝路径和 APK 输出位置以 [QuickStart.md](./QuickStart.md) 为准。
- `apk-lib` 构建时还会把最新 Android `.so` 复制到 `MESampleJava/MatrixRenderAsAAR/merge/jniLibs/arm64-v8a/`，再重新打包 `MatrixSdk_AAR_1.2.aar`。
- 如果需要重新生成 `game.pck` 或 Android `.so`，仍然使用 [QuickStart.md](./QuickStart.md) 中的 `build.bat --pck` 和 `build.bat --so`。

APK 安装示例：

```bash
    adb install -r Apks/MatrixUsedAsLib.apk
```

启动方式：
1. 直接启动 `MatrixUsedAsLib`。

Android 调试建议：

```bash
adb logcat | grep MatrixServiceApp
```

常见排查方向仍然包括：

- 客户端 `onStarted(false)`：检查客户端 SDK、初始化时机和 Application 注册。
- 客户端 `onBoundToService(false)`：检查 RenderService 是否已安装 / 启动、服务包名是否正确，以及 `<queries>` 是否声明目标包名。
- HMI / SR 黑屏：检查 `game.pck`、Android `.so`、ABI、CameraId、Surface attach 时机和 Service 日志。
- 服务端启动失败：检查前台服务权限、通知配置，以及 SDK 服务组件是否已正确合并到 Manifest。

---

## License 说明

Matrix Engine / MESample 在没有有效 license 的情况下仍可运行，但Android包的渲染画面会带有水印。

如果需要去除水印，需要获取有效 license 并按交付说明完成配置。

license 的获取方式和联系方式请参考仓库根目录的 [License.txt](E:/Work/Matrix/template/MESample/License.txt)。

---

## 二次开发建议

### C++ 业务逻辑

推荐在 `MESample/Source/MESample/` 下扩展业务能力：

```text
Common/         # 通用工具、基础数据结构、公共逻辑
SelfVehicle/    # 自车模型、车辆状态、车控映射
Simulation/     # 仿真数据、演示场景、Mock 信号
```

可扩展方向：

- 接入真实车身信号、CAN / SOME/IP / 共享内存数据。
- 增加车辆部件动画，例如车门、车窗、后备箱、充电口盖、座椅等。
- 扩展车漆、轮毂、内饰、灯光等可配置项。
- 增加 SR / ADAS 可视化对象，例如车道线、目标车、行人、障碍物等。

### 多视图渲染

如需新增屏幕或窗口，建议遵循以下步骤：

1. 在 Matrix 工程中新增 View、Camera 或 RenderTarget。
2. 在 Service 侧增加对应 Surface 绑定关系。
3. 在客户端 App 中创建并传入 Surface。
4. 校验输入事件坐标映射，确保触摸事件正确路由到目标 View。
5. 根据屏幕分辨率和芯片性能调整渲染配置。

### 工程化接入

建议在量产项目中补充：

- CI 构建脚本。
- 自动化打包流水线。
- 台架一键部署脚本。
- 性能基准测试。
- 渲染日志和输入信号录制回放。
- 版本化资产管理和 OTA 资产校验流程。

---

## 常见问题

| 问题 | 可能原因 | 处理建议 |
| --- | --- | --- |
| 工程无法打开或场景异常 | 使用了错误版本的 Matrix 编辑器 | 使用 `MatrixEngine/Matrix1.3.0.exe` 重新打开工程。 |
| `scons` 命令不存在 | 未安装 SCons | 先执行 `setup.bat`，如果仍失败，再按 [QuickStart.md](./QuickStart.md) 安装 `scons`。 |
| Android 编译找不到 NDK | `ANDROID_NDK_ROOT` 未配置或版本不匹配 | 先执行 `setup.bat`，并按 [QuickStart.md](./QuickStart.md) 确认 NDK `28.1.13356709`。 |
| Android 编译找不到 SDK | `.setup-user-env.cmd` 或 Android 工程 `local.properties` 指向了无效 SDK 目录 | 重新执行 `setup.bat`，确认仓库根目录 `.setup-user-env.cmd` 中路径有效，再查看 `build.bat` 开始输出的 `Android SDK` 路径。 |
| HMI / SR 黑屏 | `MESampleJava/MatrixRenderAsService/MatrixRenderService` 未启动、Surface 未连接、`.so` 或 `game.pck` 未拷贝 | 先按 [QuickStart.md](./QuickStart.md) 确认构建和资源拷贝，再检查 Android 日志与资源路径。 |
| Android `.so` 加载失败 | ABI 不匹配或库名不正确 | 确认使用 `arch=arm64` 编译，并检查 `bin/` 与 Service 工程中的库路径。 |
| 编辑器中 GDExtension 加载失败 | Windows Debug DLL 未编译或路径不匹配 | 重新执行 Windows Debug 构建，并检查 `MESample.gdextension` 配置。 |
| 多屏输入错位 | Surface 坐标和 View 逻辑坐标映射不一致 | 检查 View 配置、分辨率、缩放和事件路由优先级。 |

---

## 参考文档

- `服务端接入文档.md`：MatrixRenderService 服务端 AAR 接入、PCK / so 资源配置、Application 初始化与渲染服务启动说明。
- `超级客户端接入文档.md`：MatrixHMI / MatrixSR 客户端 Super Client 接入、服务绑定、Surface 管理、生命周期与排障说明。
- `Matrix引擎架构.docx`：Matrix Runtime、Matrix Core、Matrix Framework、Render as Service / Used as Library、多视图渲染等架构设计说明。
- Matrix Engine 1.3.0 编辑器与项目导出配置。

## 技术依赖说明

Matrix Engine 基于 Godot 技术栈深度定制。`project.godot`、`godot-cpp`、GDExtension、PCK 以及 Android Runtime 属于底层构建和运行依赖，保留这些名称是为了保证工程、资源和 SDK 接入说明准确。

---
