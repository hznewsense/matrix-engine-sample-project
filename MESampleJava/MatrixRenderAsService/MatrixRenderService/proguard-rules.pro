# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Matrix 引擎 Java 层（与 native 双向 JNI 调用）
-keep class org.godotengine.godot.** { *; }

# Matrix SDK（含 com.ns.matrix/com.ns.sdkclient，SDK 反射加载，manifest 按类名引用 Activity/Application）
-keep class com.ns.** { *; }

# 所有含 native 方法的类（JNI 入口签名不可改）
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留注解与泛型签名，供反射/序列化使用
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod