# 灵感动画集

Flutter 动画示例应用，支持 Android、iOS 和 Web。

## 运行

需要 Flutter 自带 Dart >=3.11.5 <4.0.0。当前验证环境为 Flutter 3.41.10-ohos-1.0.0 / Dart 3.11.5；应用没有使用鸿蒙专用 API 或第三方动画依赖。

```sh
flutter pub get
flutter run -d chrome
# 查看并选择已连接设备
flutter devices
flutter run -d <device-id>
```

## 功能

- 动画集 / 视频集 / 我的三个底部 Tab，250ms 淡入与位移过渡，保留列表滚动状态。
- 动画集包含粒子火花、点击水波两个演示入口。
- 圆形、三角形、正方形点击后碎裂并恢复，可独立重复播放。
- 在水波演示区域任意点击，最多同时播放 8 个水波，播放结束自动清理。
- 遵循系统减少动画设置。视频集与我的目前为空状态页面。

## 模块

- `lib/home_shell.dart`：底部导航与切换。
- `lib/animation_gallery.dart`：动画列表和演示路由。
- `packages/particle_sparks`：独立 Flutter 包，导出 `ParticleSparksDemo`、`ParticleShape` 和 `SparkShape`。
- `packages/tap_ripple`：独立 Flutter 包，导出 `TapRippleDemo`。

两个包均通过本地 path 依赖接入，可单独执行分析与测试。

## 验证

在根目录执行：

```sh
flutter analyze
flutter test
flutter build web
```

再分别在 `packages/particle_sparks` 和 `packages/tap_ripple` 中执行 `flutter analyze`、`flutter test`。测试覆盖 Tab 切换、列表状态保留、两个演示的进入与返回、形状重播和恢复、水波重叠清理及退出安全性。

Web 输出位于 `build/web/`。Android 需要 Android SDK、JDK 与已接受的 SDK 许可，可执行 `flutter doctor -v` 检查；iOS 需要 macOS 与 Xcode，无法在 Windows 编译。本次未验证 Android/iOS 构建。

应用标识仍为模板值 `com.example.myflutter`，发布前需修改名称、图标、应用标识及签名；Android 模板 release 当前使用 debug 签名。
