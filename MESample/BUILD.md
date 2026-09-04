# 编译说明

## 依赖

| 依赖 | 说明 |
|------|------|
| Python 3.x | 运行 SCons |
| SCons ≥ 4.0 | 构建系统，`pip install scons` |
| C++20 编译器 | Windows: MSVC (VS 2022)；Android: NDK clang |
| Android NDK | 编译 Android 平台时需要 |
| godot-cpp | Git submodule，位于 `Source/godot-cpp/` |

## 目录结构

```
MESample/
├── Source/              # C++ 源码与构建脚本
│   ├── SConstruct       # 主构建脚本
│   ├── godot-cpp/       # Godot C++ 绑定（submodule）
│   └── MESample/        # 业务源码
│       ├── Common/
│       ├── SelfVehicle/
│       └── Simulation/
├── bin/                 # 编译产物输出目录
│   ├── MESample.gdextension
│   ├── libMESample.windows.template_debug.x86_64.dll
│   └── libMESample.android.template_release.arm64.so
└── Pck/                 # 打包产物
```

## 编译命令

在 `Source/` 目录下执行：

### Windows Debug（编辑器开发）

```bash
cd Source
scons platform=windows target=template_debug
```

产物：`bin/libMESample.windows.template_debug.x86_64.dll`

### Windows Release

```bash
scons platform=windows target=template_release
```

产物：`bin/libMESample.windows.template_release.x86_64.dll`

### Android Release

```bash
scons platform=android target=template_release arch=arm64
```

产物：`bin/libMESample.android.template_release.arm64.so`

> 需要配置 `ANDROID_NDK_ROOT` 环境变量指向 NDK 路径。

## 清理

```bash
scons -c platform=windows target=template_debug
```

或直接删除 `Source/build/` 目录。
