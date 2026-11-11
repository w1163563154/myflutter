# myflutter

为 GitHub Issue #1 初始化的 Flutter 项目，保留 Flutter 官方计数器示例。支持 Android、iOS 和 Web；点击右下角 `+` 按钮可增加计数。

## 环境

- 安装 Flutter，并确保其附带的 Dart 满足 `>=3.11.5 <4.0.0`（见 `pubspec.yaml`）。
- 本项目生成及验证使用 Flutter `3.41.10-ohos-1.0.0`、Dart `3.11.5`。这是本机已安装的 Flutter 鸿蒙分支；项目没有添加鸿蒙平台或专用依赖。
- Android 开发需要 Android SDK、JDK 和已接受的 Android SDK 许可。使用 `flutter doctor -v` 检查环境；必要时运行 `flutter doctor --android-licenses`。
- iOS 开发需要 macOS、Xcode 及对应工具链；Windows 无法构建 iOS 应用。
- Web 开发可使用 Chrome。

## 开始运行

在项目根目录执行：

```sh
flutter pub get
flutter run -d chrome
```

运行到 Android 或 iOS 模拟器/设备：

```sh
flutter devices
flutter run -d <device-id>
```

将 `<device-id>` 替换为设备列表中的实际 ID；iOS 命令需在配置好 Xcode 的 macOS 上执行。

## 检查与构建

```sh
flutter analyze
flutter test
flutter build web
```

计数器测试验证初始值为 0，点击加号后变为 1。Web 构建输出位于 `build/web/`。

配置好对应工具链后，可以执行：

```sh
flutter build apk
# 以下命令仅适用于 macOS；正式分发还需要配置签名。
flutter build ios --no-codesign
```

## 目录

- `lib/main.dart`：计数器应用入口和页面。
- `test/widget_test.dart`：计数器交互测试。
- `android/`、`ios/`、`web/`：各平台工程。
- `pubspec.yaml`、`pubspec.lock`：依赖声明与应用依赖锁定文件。

Android 应用 ID 与 iOS Bundle ID 使用模板默认值 `com.example.myflutter`。正式发布前请替换为自己的标识，并配置应用名称、图标和正式签名；Android 模板的 release 构建当前使用 debug 签名。

## 本次验证

已通过 `flutter analyze`、`flutter test`（计数器交互测试）及 `flutter build web`。iOS 工程仅生成，未在 Windows 上编译；Android 未执行构建，本机尚有未接受的 SDK 许可，且 doctor 检测到 Google Maven 网络连接异常。
