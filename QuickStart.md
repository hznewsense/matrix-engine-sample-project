# Quick Start

本文档描述从环境配置到生成 Android APK 的最短可执行流程，基于当前仓库内的脚本：

- [`setup.bat`](setup.bat)
- [`build.bat`](build.bat)

适用目录结构：

- Matrix 工程：`MESample/`
- Android 工程：`MESampleJava`
- Matrix 编辑器：`MatrixEngine/Matrix1.3.0.exe`

## 0. 最简流程
在仓库根目录执行：

```bat
setup.bat  
```
成功后执行：

```
build.bat
```
成功后生成这些apk



```text
Apks\MatrixRenderService.apk
Apks\MatrixHMI.apk
Apks\MatrixSR.apk
Apks\MatrixUsedAsLib.apk
```


## 1. 环境要求

需要准备：

- Matrix Engine Editor `1.3.0`
- Python 3
- SCons
- Android SDK
- Android NDK `28.1.13356709`
- JDK 17 或 Android Studio 自带 JBR

当前脚本会自动解析并持久化这些环境变量：

- `ANDROID_HOME`
- `ANDROID_SDK_ROOT`
- `ANDROID_NDK_ROOT`
- `JAVA_HOME`

说明：

- `setup.bat` 会优先读取仓库根目录的 `.setup-user-env.cmd`。
- 当你在 `setup.bat` 里手动输入 Android SDK 路径时，脚本会把该路径写入 `.setup-user-env.cmd`，供后续 `setup.bat` 和 `build.bat` 复用。
- `build.bat` 也会读取 `.setup-user-env.cmd`，并在执行 Gradle 前自动同步 Android 工程的 `local.properties`。

## 2. 配置环境

在仓库根目录执行：

```bat
setup.bat
```

正常完成后会输出类似结果：

```bat
[ OK ] Python command: ...
[ OK ] SCons command: ...
[ OK ] Android NDK: ...
[ OK ] JAVA_HOME: ...
[ OK ] Environment setup complete.
Resolved environment:
  ANDROID_HOME     = C:\Users\luson\AppData\Local\Android\Sdk
  ANDROID_SDK_ROOT = C:\Users\luson\AppData\Local\Android\Sdk
  ANDROID_NDK_ROOT = C:\Users\luson\AppData\Local\Android\Sdk\ndk\28.1.13356709
  JAVA_HOME        = C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\

[ OK ] You can now run: build.bat
```

可选参数：

```bat
setup.bat --skip-jdk
setup.bat --skip-winget
setup.bat --persist-env
setup.bat --help
```

说明：

- `setup.bat` 负责检测并补齐本机环境变量，如果依赖没有满足，会自动安装相关依赖。
- `--persist-env` 会把本次解析到的环境变量写入系统环境变量；不带该参数时，只保证当前 `setup.bat` 进程内可见。
- 即使不使用 `--persist-env`，用户输入的 Android SDK 路径也会被写入 `.setup-user-env.cmd`。
- 安装 Android SDK / NDK 时，`sdkmanager` 输出会实时打印到终端；长时间下载时不再静默等待。
- 如果执行失败，可以查看相关的错误日志，然后手动安装依赖才能执行后面的步骤。



## 3. 完整生成 APK

推荐直接执行：

```bat
build.bat
```

`build.bat` 开始阶段会打印本次实际使用的依赖信息，例如：

```text
[INFO] Build dependencies:
  Python            = py -3
  SCons             = scons
  Android SDK       = C:\Users\...\Android\Sdk
  Android NDK       = C:\Users\...\Android\Sdk\ndk\28.1.13356709
  JDK               = C:\Program Files\...\jdk-17...
  Gradle            = ...\gradlew.bat
```

它会按顺序完成：

1. 编译 Android `.so`
2. 导出 `game.pck`
3. 拷贝 `.so` 和 `game.pck` 到 `MatrixRenderService`
4. 构建 `MatrixRenderService`、`MatrixHMI`、`MatrixSR` 三个 APK
5. 构建 `MatrixUsedAsLib` APK

最终输出：

```text
Apks\MatrixRenderService.apk
Apks\MatrixHMI.apk
Apks\MatrixSR.apk
Apks\MatrixUsedAsLib.apk
```

## 4. APK 用途、安装与启动

当前脚本会生成 4 个 APK：

- `Apks\MatrixRenderService.apk`
- `Apks\MatrixHMI.apk`
- `Apks\MatrixSR.apk`
- `Apks\MatrixUsedAsLib.apk`

### 4.1 Render As Service

用途：

- `MatrixRenderService.apk`：渲染 Service 宿主，负责启动渲染服务并承载引擎运行时。
- `MatrixHMI.apk`：HMI 演示 App，作为渲染服务客户端使用。
- `MatrixSR.apk`：SR 演示 App，作为另一套渲染服务客户端使用。

安装：

```bat
adb install -r Apks\MatrixRenderService.apk
adb install -r Apks\MatrixHMI.apk
adb install -r Apks\MatrixSR.apk
```

启动顺序：

1. 启动 `MatrixRenderService`
2. 启动 `MatrixHMI` 或 `MatrixSR`

### 4.2 Used As Library

用途：

- `Apks\MatrixUsedAsLib.apk`：`Used As Library` 模式演示 App，直接集成 `MatrixRenderAsAAR`。

安装：

```bat
adb install -r Apks\MatrixUsedAsLib.apk
```

启动方式：

- 直接启动 `MatrixUsedAsLib`

说明：

- `Render As Service` 模式需要先有服务端，再启动客户端。
- `Used As Library` 模式不依赖单独安装 `MatrixRenderService.apk`。

## 5. 推荐执行顺序

第一次拉起工程时建议按这个顺序执行：

```bat
setup.bat
build.bat --so
build.bat --pck
build.bat --apk-service
build.bat --apk-lib
```

如果要一键完成：

```bat
setup.bat
build.bat
```

## 6. 单独执行某一步

### 6.1 只编译 Android so

```bat
build.bat --so
```

输出文件：

```text
MESample\bin\libMESample.android.template_release.arm64.so
```

### 6.2 只生成 game.pck

```bat
build.bat --pck
```

输出文件：

```text
MESample\Pck\game.pck
```

### 6.3 只清理 game.pck

```bat
build.bat --clean-pck
```

### 6.4 只生成 Render as Service APK

前提是 `.so` 和 `game.pck` 已经准备好，并且已经复制到 Android 工程目录。

```bat
build.bat --apk-service
```

输出目录：

```text
Apks\
```

### 6.5 只生成 Used as Library APK

前提是 `game.pck` 已经准备好。

```bat
build.bat --apk-lib
```

输出文件：

```text
Apks\MatrixUsedAsLib.apk
```


## 7. 当前 Android 资源拷贝位置

`build.bat --apk-service` 会把构建结果复制到以下位置：

`game.pck` 复制到：

```text
MESampleJava\MatrixRenderAsService\MatrixRenderService\src\main\assets\game.pck
```

`.so` 复制到：

```text
MESampleJava\MatrixRenderAsService\MatrixRenderService\jniLibs\arm64-v8a\libMESample.android.template_release.arm64.so
```

`build.bat --apk-lib` 额外会复制到 `MatrixRenderAsAAR`：

`game.pck` 复制到：

```text
MESampleJava\MatrixRenderAsAAR\app\src\main\assets\game.pck
```

`.so` 复制到：

```text
MESampleJava\MatrixRenderAsAAR\merge\jniLibs\arm64-v8a\libMESample.android.template_release.arm64.so
```

## 8. 常用命令

完整构建：

```bat
build.bat
```

编译 `.so` + 导出 `pck`，但不打 APK：

```bat
build.bat --skip-apk-service --skip-apk-lib
```

只打 Render as Service APK：

```bat
build.bat --apk-service
```

只打 Used as Library APK：

```bat
build.bat --apk-lib
```

清理 APK 输出目录后只打 Render as Service APK：

```bat
build.bat --clean-apks --apk-service
```

查看帮助：

```bat
build.bat --help
```

## 9. 常见问题

### 9.1 `setup.bat` 失败

先确认：

- `Python 3` 已安装
- `Android SDK` 已安装
- `NDK 28.1.13356709` 已安装
- `JAVA_HOME` 可解析到有效 JDK/JBR

补充排查：

- 检查仓库根目录的 `.setup-user-env.cmd` 中 `ANDROID_HOME` / `ANDROID_SDK_ROOT` 是否指向真实存在的 SDK 目录。
- 如果是首次自动安装 SDK / NDK，确认网络可以访问 Android 仓库。

### 9.2 `build.bat --so` 失败

优先检查：

- `SCons` 是否可用
- `ANDROID_NDK_ROOT` 是否指向 `28.1.13356709`

### 9.3 `build.bat --pck` 失败

优先检查：

- `MatrixEngine\Matrix1.3.0.exe` 是否存在
- `MESample\project.godot` 是否存在

说明：

- 导出日志中的 license 红字不一定阻塞 `game.pck` 生成，需以最终是否生成 `MESample\Pck\game.pck` 为准。

### 9.4 APK 没生成

优先检查：

- `MESampleJava\MatrixRenderAsService\gradlew.bat` 是否存在
- `MatrixRenderService` 是否已经拿到最新的 `game.pck` 和 `.so`
- `JAVA_HOME` 是否有效
- `build.bat` 开始输出里的 `Android SDK` 是否为正确目录
- `MESampleJava\MatrixRenderAsService\local.properties` 与 `MESampleJava\MatrixRenderAsAAR\local.properties` 是否已被同步为正确的 `sdk.dir`
