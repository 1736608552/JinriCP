# JinriCP 纯净原生 Android 客户端 (方案 A)

本工程是针对 `https://5721004.xyz/` 的纯原生跨平台 Flutter 客户端，**彻底移除了所有网页端广告、弹窗推广与第三方追踪代码**。

## 🌟 核心特性
- 🚫 **100% 零广告 / 纯净体验**：直接在客户端底层解析 HTML DOM 树中的目录和文件结构，彻底剥离所有 Google Ads、VPN 推广和弹窗广告。
- 🎬 **原生 ExoPlayer 播放器**：基于 `chewie` + `video_player`（底层调用 Android 原生 ExoPlayer），实现硬件加速解码、手势音量/亮度控制、倍速播放与全屏切换。
- 📑 **季数与分集导航**：内置抽屉侧边栏快速切换 JinriCP 第一至六季、PandaClass 第一至七季。
- 📂 **多级子目录支持**：支持深入文件夹浏览与面包屑导航返回。
- 🌐 **防封动态域名切换**：可在设置中一键切换备用域名（如 `https://jinricp.azurewebsites.net`）。

## 🚀 编译与打包 APK 步骤

1. **进入项目目录**：
   ```bash
   cd /vol1/@apphome/GoogleAntigravityCLI/home/.gemini/antigravity-cli/scratch/jinri_video_app
   ```

2. **初始化 Flutter 平台文件（如果是新环境）**：
   ```bash
   flutter create . --org com.jinri.pureapp
   ```

3. **获取依赖**：
   ```bash
   flutter pub get
   ```

4. **配置 Android 网络权限与明文传输**：
   在 `android/app/src/main/AndroidManifest.xml` 中确保包含以下权限和配置：
   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android">
       <uses-permission android:name="android.permission.INTERNET"/>
       <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
       <application
           android:label="JinriCP 纯净版"
           android:name="${applicationName}"
           android:icon="@mipmap/ic_launcher"
           android:usesCleartextTraffic="true">
           <!-- ... -->
       </application>
   </manifest>
   ```

5. **编译生成 Release APK**：
   ```bash
   flutter build apk --release
   ```
   生成的 APK 文件位于：
   `build/app/outputs/flutter-apk/app-release.apk`
