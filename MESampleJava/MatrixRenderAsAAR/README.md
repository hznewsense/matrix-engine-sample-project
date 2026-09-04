# Matrix SDK 渲染接入文档（Demo 样例）

本文档基于 `MatrixRenderAsAAR` 样例工程，说明如何在 Android 应用中接入 Matrix SDK，启动 Matrix 渲染服务，并把渲染画面输出到一个 `SurfaceView`。

> 本工程对外提供两个产物：
> - **AAR**：`app/libs/MatrixSdk_AAR_1.2_20260529.aar`（SDK、Matrix 运行时、原生 so 均已打包在内）
> - **游戏资源 PCK**：`app/src/main/assets/game.pck`（Matrix 引擎导出的工程资源包）

---

## 1. 架构概述

Matrix SDK 采用 **“渲染服务 + 客户端 Surface”** 架构：

- **渲染服务** `MatrixService`：由 AAR 提供（Manifest 自动合并），以**前台服务**形式承载 Matrix 引擎实例，负责实际渲染。
- **引擎客户端** `MatrixEngineSuperClient` / `IEngineSuperClient`：应用进程内代理，负责绑定服务、管理生命周期、挂载/卸载 Surface。
- **渲染 Surface** `MatrixSurface` / `ISurface`：把一个 `SurfaceView` 包装成引擎渲染目标，支持触摸、透明度、相机视口等配置。
- **资源加载** `PCKManager`：把 `assets/game.pck` 部署到外部存储供引擎加载。

---

## 2. 环境要求

| 项 | 要求 |
| --- | --- |
| Android Studio | Ladybug+ |
| Android Gradle Plugin | 8.13.x（本工程 8.13.1） |
| JDK | 17 |
| compileSdk / targetSdk | 36 |
| minSdk | 30 |
| ABI | arm64-v8a |

---

## 3. 集成步骤

### 3.1 放置产物

```
app/
├── libs/
│   └── MatrixSdk_AAR_1.2_20260529.aar      # SDK AAR
└── src/main/
    └── assets/
        └── game.pck                        # Matrix 资源包
```

### 3.2 配置 Gradle 依赖

模块级 `app/build.gradle`：

```groovy
android {
    namespace 'com.ns.matrix.sample.aar'
    compileSdk { version = release(36) }

    defaultConfig {
        applicationId "com.ns.matrix.sample.aar"
        minSdk 30
        targetSdk 36
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    implementation libs.appcompat
    implementation libs.material
    // 引入 libs 目录下的全部本地 AAR
    implementation(fileTree("libs") { include("*.aar") })
}
```

> AAR 已内置 `arm64-v8a` 原生 so（Matrix 运行时 + GDExtension），**无需**额外往 `jniLibs` 拷贝 so。

### 3.3 配置 AndroidManifest

需要的权限与 `Application` 声明（`MatrixService` 由 AAR 的 Manifest 自动合并进来，**无需手动声明**）：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <application
        android:name=".MatrixServiceApp"
        android:label="@string/app_name"
        android:theme="@style/Theme.AppSampleService">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

## 4. Application 接入：加载资源 + 启动服务 + 初始化客户端

在自定义 `Application` 中完成三件事：**部署 PCK → 启动渲染服务 → 创建并绑定引擎客户端**。

```java
public class MatrixServiceApp extends Application {
    private static MatrixServiceApp instance;
    private IEngineSuperClient engineSuperClient;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        initializePckWithSmartLoading();   // 1. 部署 game.pck
        startMatrixServiceFromForeground(); // 2. 启动前台渲染服务
        initEngine();                      // 3. 创建并绑定引擎客户端
    }

    // 1. 将 assets/game.pck 智能部署到外部存储（已存在且未变化则跳过）
    private void initializePckWithSmartLoading() {
        File externalDir = getExternalFilesDir(null);
        if (externalDir == null) return;
        String externalPath = new File(externalDir, "game.obb").getAbsolutePath();
        PCKManager.INSTANCE.smartInstallPckFromAssets(this, externalPath);
    }

    // 2. 以前台服务形式启动 MatrixService
    private void startMatrixServiceFromForeground() {
        Intent intent = new Intent(this, MatrixService.class);
        startForegroundService(intent);
    }

    // 3. 创建引擎客户端并绑定服务（绑定为异步）
    public void initEngine() {
        if (engineSuperClient != null) return;
        engineSuperClient = MatrixEngineSuperClient.newBuilder(this)
                .withServicePackageName("com.ns.matrix.sample.aar") // 与 applicationId 一致
                .withServiceConnectionId(1000001)                    // 连接标识，自定义唯一值
                .withEngineClientListener(new IEngineSuperClientListener() {
                    @Override public void onStarted(boolean success) {}
                    @Override public void onBoundToService(boolean success) {}
                    @Override public void onUnboundToService() {}
                    // onStopped / onPaused / onResume / onSleep / onWakeup 可按需重写
                })
                .build();
        engineSuperClient.bindToService();
    }

    public IEngineSuperClient getEngineClient() {
        initEngine();
        return engineSuperClient;
    }

    public static MatrixServiceApp getInstance() { return instance; }
}
```

涉及的包名：

```java
import com.ns.matrix.PCKManager;
import com.ns.matrix.MatrixService;
import com.ns.matrixengine.IEngineSuperClient;
import com.ns.matrixengine.IEngineSuperClientListener;
import com.ns.sdkclient.MatrixEngineSuperClient;
```

---

## 5. Activity 接入：创建并挂载渲染 Surface

### 5.1 布局

`res/layout/activity_main.xml` 放一个全屏 `SurfaceView`：

```xml
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">

    <SurfaceView
        android:id="@+id/surfaceView"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />
</LinearLayout>
```

### 5.2 构建 Surface 并挂载

```java
public class MainActivity extends AppCompatActivity {
    private ISurface surface;
    private IEngineSuperClient engineClient;
    private SurfaceView surfaceView;
    private int cameraId = 0; // 视口/相机 ID

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        initMatrixSurface();
    }

    private void initMatrixSurface() {
        engineClient = MatrixServiceApp.getInstance().getEngineClient();
        surfaceView = findViewById(R.id.surfaceView);
        surface = MatrixSurface.newBuilder(this, surfaceView)
                .withCameraId(cameraId)     // 指定渲染到的视口
                .withTouchSupport(true)     // 是否转发触摸事件
                .withAlphaValue(1.0f)       // 透明度 0~1
                .build();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (surface == null || engineClient == null) return;
        engineClient.attachSurface(surface); // 把 Surface 挂载到引擎
    }
}
```

涉及的包名：

```java
import com.ns.matrixengine.ISurface;
import com.ns.sdkclient.MatrixSurface;
```

---

## 6. 核心 API 速查

### 6.1 `MatrixEngineSuperClient.Builder`

| 方法 | 说明 |
| --- | --- |
| `newBuilder(Context)` | 创建构建器 |
| `withServicePackageName(String)` | 渲染服务所在包名（通常即本应用 `applicationId`） |
| `withServiceConnectionId(int)` | 连接唯一标识 |
| `withEngineClientListener(IEngineSuperClientListener)` | 生命周期/绑定回调 |
| `build()` | 返回 `IEngineSuperClient` |

### 6.2 `IEngineSuperClient`

| 方法 | 说明 |
| --- | --- |
| `bindToService()` | 绑定渲染服务（**异步**） |
| `isBoundToService()` | 是否已绑定 |
| `attachSurface(ISurface)` | 挂载 Surface；服务未就绪时返回 `false` |
| `detachSurface(ISurface)` | 卸载指定 Surface |
| `start()` / `stop()` / `pause()` / `resume()` / `sleep()` / `wakeup()` | 引擎生命周期控制 |

### 6.3 `MatrixSurface.Builder`

| 方法 | 说明 |
| --- | --- |
| `newBuilder(Context, SurfaceView)` | 创建构建器 |
| `withCameraId(int)` | 渲染目标视口 ID |
| `withTouchSupport(boolean)` | 是否启用触摸转发 |
| `withAlphaValue(float)` | 透明度 |
| `build()` | 返回 `ISurface` |

### 6.4 `ISurface`

| 方法 | 说明 |
| --- | --- |
| `getId()` | 引擎分配的 surface id（0 表示尚未成功挂载） |
| `getSize()` | 当前尺寸 |
| `show()` / `hide()` | 显示/隐藏 |
| `enableTouch()` / `disableTouch()` | 开关触摸 |
| `resize(int, int)` | 调整尺寸 |
| `setAlpha(float)` | 设置透明度 |
| `setCameraId(int)` | 切换视口 |
| `setStretchMode(int)` | 拉伸模式 |

---

## 7. 关键时序与注意事项

1. **绑定是异步的**：`bindToService()` 立即返回，真正绑定完成需要一小段时间。`attachSurface()` 只有在服务绑定就绪后才会成功（返回 `true`）。
2. **挂载时机**：若在 `onResume()` 中调用 `attachSurface()` 时服务尚未绑定完成，挂载会失败，画面可能停留在默认 `1×1`。建议**根据 `attachSurface()` 返回值或 `IEngineSuperClientListener.onBoundToService(true)` 做重试/补挂**，并在挂载成功后确保 `SurfaceView` 的真实尺寸已通过 `SurfaceHolder` 回调送达引擎。
3. **前台服务权限**：必须声明 `FOREGROUND_SERVICE` 等权限，否则服务启动失败。
4. **PCK 部署**：`smartInstallPckFromAssets` 会比对并跳过未变化的资源；更新 `game.pck` 后会自动重新部署。
5. **ABI**：当前仅提供 `arm64-v8a`，请在真机或对应架构模拟器上运行。

---

## 8. 构建与运行

1. 确认 `app/libs/` 下存在 AAR、`app/src/main/assets/` 下存在 `game.pck`。
2. Gradle Sync。
3. 连接 arm64 设备，运行 `app`。
4. 首次启动会部署 PCK 并拉起前台渲染服务，随后 `MainActivity` 的 `SurfaceView` 显示 Matrix 渲染画面。

---

**文档版本**：1.2
**适配 SDK**：MatrixSdk_AAR_1.2_20260529
