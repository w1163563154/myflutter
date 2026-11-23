# 日常手账

Flutter 本地记录应用，采用温暖手账风格，支持 Android、iOS 和 Web。首页为个人记录和快递记录，原动画收进右上角“小工具”。

## 运行

需要 Flutter 自带 Dart >=3.11.5 <4.0.0。当前验证环境为 Flutter 3.41.10-ohos-1.0.0 / Dart 3.11.5；应用没有使用鸿蒙专用 API；图片选择使用 Flutter 维护的 file_selector 插件，动画使用 Flutter 自身绘制。

```sh
flutter pub get
flutter run -d chrome
# 查看并选择已连接设备
flutter devices
flutter run -d <device-id>
```

## 功能

- 个人记录：标题和正文笔记，支持新增、编辑、包含搜索和未保存返回提醒；列表突出月日、星期及更新时间。
- 密码库：首次设置至少 12 字符主密码，解锁后新增/编辑网站、网址、账号、密码和备注。密码默认遮挡，支持显示和立即锁定；切换主 Tab、进入工具、进入后台或闲置 60 秒自动锁定。持续输入会延长闲置时间。
- 快递记录：日历有记录的日期下显示圆点，按日期查看或跨日期搜索，数据库每次读取15条并滚动续载。所有文本字段选填，空白内容自动保存为“未填写”。
- 右上角“数据管理”：导出全部普通笔记/快递CSV，备份全部模块JSON，以及从备份恢复。密码库只写入密文。
- 小工具包含太阳系、粒子火花、点击水波和图片吸入四个演示入口。
- 图片吸入：默认展示离线风景插画，圆形吸入口可拖到整个页面（含图片外和标题栏），点击“吸入”后向选定位置连续拉伸弯曲并消失（约 1.6 秒）；播放中固定目标，“重置”可中止并恢复且保留位置，支持重播及系统减少动画设置。
- 圆形、三角形、正方形点击后碎裂并恢复，可独立重复播放。
- 支持本地选择 PNG/JPEG/WebP 图片（最大 20 MB），点击预览后原图碎片扩散、旋转、淡出并恢复，可替换图片，不上传服务器。
- 在水波演示区域任意点击，最多同时播放 8 个水波，播放结束自动清理。
- 动画遵循系统减少动画设置。

## 密码与笔记存储

`journal.db` 保存普通笔记与密码库；普通笔记不加密。密码条目整个对象使用 AES-256-GCM 加密，包含随机 nonce 和认证标签；主密码使用 PBKDF2-HMAC-SHA256、600000 次迭代和 32 字节随机盐派生密钥，加密校验值用于解锁。主密码不写入数据库。忘记主密码无法恢复密码条目；目前没有重置、明文密码导出、云同步或剪贴板功能。

## 导出、备份和恢复

两主页面右上角文件图标进入“数据管理”。笔记和快递分别导出带UTF-8 BOM的CSV，处理换行、引号和电子表格公式前缀；电话和编号建议在Excel按文本列导入以保留前导零。CSV用于查看，不能作为应用恢复文件。

完整备份为带版本JSON，包含全部笔记、快递、密码库盐/派生参数和加密密文，不包含主密码或明文密码。普通笔记和快递在文件中未加密。恢复先校验格式并显示数量，再要求保存当前完整备份；浏览器需确认下载完成后继续。笔记和快递新增导入，重复恢复会重复；备份含密码库时完整替换当前密码库，使用备份原主密码解锁，恢复后自动锁定。无密码库的备份不会清除当前密码库。支持50MB以内、每类最多10万条，导出和恢复需足够内存。

恢复使用数据库事务和失败补偿；两个数据库之间不保证进程强杀或断电时原子完成，请保留恢复前备份。文件选择与保存使用file_picker；Web插件新增后如遇旧插件注册缓存，可运行flutter clean、flutter pub get再重新构建。原生文件选择与保存需设备实测。

锁定会清除当前会话密钥及敏感界面内容；加密与会话测试不等同于独立安全认证。Web 数据存于当前站点的 IndexedDB，清除站点数据会丢失内容。旧 Web 版本错误的双斜杠路径会将数据库映射到根文件，当前版本在新数据库创建时复制其中对应表并保留源文件，不删除旧数据。

## 本地记录

“快递记录”Tab 支持日期、名字、电话、编号、备注五个字段；所有文本字段选填，未填写或仅含空格时自动保存为“未填写”，兼容历史空编号。点击“添加”填写保存，列表默认加载今天的数据，支持选择日期和返回今天。输入关键词时跨所有日期对名字、电话、编号和备注做包含匹配，结果按日期从新到旧排列；清空搜索后恢复当前所选日期，不区分英文字母大小写，`%`、`_` 和引号按普通字符处理。电话与编号按文本保存，保留前导零，编号可重复。新增后自动切到新记录日期并清空搜索。

Android/iOS 首次使用自动在应用私有数据库目录创建 `local_records.db`，使用 SQLite schema v1。Web 使用 SQLite WASM，通过 IndexedDB 持久保存；`web/sqlite3.wasm`、`web/sqflite_sw.js` 随构建打包，无需运行时从 CDN 下载数据库资源。浏览器数据归属于当前站点（含端口），调试时建议固定端口；手机和浏览器数据各自独立。清除应用或站点数据会清除记录，点击快递卡片可修改；左滑展开四分之一宽的红色删除按钮，点击并确认后删除，删除后可撤销。当前不提供云同步。

仅验证记录页可用 `flutter run -d chrome --web-port=8933 --dart-define=RECORDS=true`。正常启动不带该参数，从底部导航进入。Web 数据库运行资源由 `dart run sqflite_common_ffi_web:setup` 生成；升级 SQLite 相关依赖后需重新生成并验证添加和刷新后读取。Web 适配依赖仍被上游标为实验性，已在 Chrome 实测持久化。

模块：`lib/records/record.dart` 数据模型，`record_repository.dart` 数据库访问，`database_native.dart`/`database_web.dart` 平台适配，`records_page.dart` 列表与筛选，`record_form.dart` 添加表单。

## 动画模块

- `lib/home_shell.dart`：底部导航与切换。
- `lib/animation_gallery.dart`：动画列表和演示路由。
- `lib/image_suction_demo.dart`、`lib/suction_mesh.dart`：图片吸入页面、纹理网格与局部形变；示例插画位于 `assets/images/suction_landscape.png`，由项目自行绘制。
- `packages/particle_sparks`：独立 Flutter 包，导出 `ParticleSparksDemo`、`ParticleShape`、`SparkShape` 和 `ImageParticles`。
- `packages/tap_ripple`：独立 Flutter 包，导出 `TapRippleDemo`。

两个包均通过本地 path 依赖接入，可单独执行分析与测试。

## 验证

在根目录执行：

```sh
flutter analyze
flutter test
flutter build web
```

再分别在 `packages/particle_sparks` 和 `packages/tap_ripple` 中执行 `flutter analyze`、`flutter test`。测试覆盖 Tab 切换、列表状态保留、演示页的进入与返回、形状重播和恢复、水波重叠清理及退出安全性；图片吸入测试覆盖网格形变、完成与重置、重播、减少动画、图片加载失败重试和加载中退出。

Web 输出位于 `build/web/`。Android 调试安装包位于 `build/app/outputs/flutter-apk/app-debug.apk`，已验证构建；本机没有连接设备，未实测原生软键盘与后台锁定。Android 需要 Android SDK、JDK 与已接受的 SDK 许可，可执行 `flutter doctor -v` 检查；iOS 需要 macOS 与 Xcode，无法在 Windows 编译。

应用标识仍为模板值 `com.example.myflutter`，发布前需修改名称、图标、应用标识及签名；Android 模板 release 当前使用 debug 签名。

## 3D 太阳系

动画集新增“3D 太阳系”：three_js 0.3.0 的真实球体、透视相机和光照，包含太阳、八大行星与土星环。拖动旋转、双指/滚轮缩放；支持暂停、0.25–4 倍速度、恢复视角及轨道/中文名称开关。尺寸、距离、速度和原创程序纹理用于展示，不代表精确天文比例或真实地表图。纹理和 WebGL 绑定脚本随应用离线打包，第三方脚本许可见 web/gles_bindings.LICENSE.txt。

直接进入验证页面：`flutter run -d chrome --dart-define=SOLAR_SYSTEM=true`。Android 构建需要 CMake 3.31.4（flutter_angle 原生依赖），支持 OpenGL 的设备；Web 需要 WebGL2。后台停止场景刷新，恢复保留视角；系统减少动画设置下初始暂停。

太阳系补充：月球绕地球公转并随地球运动，使用原创陨石坑纹理。定位下拉可以切换太阳、八大行星、月球和全景；选定目标后相机跟随目标。选择“平移”可单指/鼠标左键移动画面，旋转模式下可用双指平移或鼠标右键平移，放大后仍可自由观察。恢复视角返回太阳系全景。
