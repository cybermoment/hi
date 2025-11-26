# hi

一个使用 Flutter + Mapbox 打造的跨平台示例应用，目标体验接近 iOS 自带「地图」：支持实时定位、地点搜索、地图样式切换等核心能力，可同时运行在 iOS 与 Android 设备上。

## 功能亮点
- Mapbox 矢量地图渲染，内置标准 / 探索 / 卫星 3 种样式切换
- 使用 Geolocator 获取当前位置，并在地图中高亮展示
- 集成 Mapbox Geocoding API，实现搜索与快速飞行定位
- 统一的 Material 设计控件，顶层搜索栏 + 底部样式控制条

## 环境要求
1. Flutter 3.9+ 与对应的 Dart SDK
2. 有效的 Mapbox Access Token（可在 Mapbox Dashboard 创建）
3. iOS 需 Xcode 14+，Android 需 Android Studio/SDK 34+

## Access Token 配置
可任选以下方式中的一个，或全部替换：

1. **运行时注入（推荐）**
   ```bash
   flutter run --dart-define=MAPBOX_ACCESS_TOKEN=你的token
   ```
2. **Android**：编辑 `android/app/src/main/res/values/strings.xml` 中的 `mapbox_access_token`。
3. **iOS**：在 `ios/Runner/Info.plist` 里替换 `MGLMapboxAccessToken` 的值。

请确保原生层与 `lib/main.dart` 中读取的 Token 内容保持一致。

## 调试运行
```bash
flutter pub get
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=你的token
```

首次运行需要 `pod install`（iOS）与 Gradle 依赖下载（Android），请保持网络畅通。若要发布到商店，请为定位权限文案与图标做进一步本地化调整。
