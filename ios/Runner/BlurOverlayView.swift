import Flutter
import UIKit

class BlurOverlayFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return BlurOverlayView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

class BlurOverlayView: NSObject, FlutterPlatformView {
  private var _view: BlurOverlayUIView

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) {
    _view = BlurOverlayUIView(frame: frame)
    super.init()
  }

  func view() -> UIView {
    return _view
  }
}

class BlurOverlayUIView: UIView {
  private let blurView: UIVisualEffectView

  override init(frame: CGRect) {
    // systemUltraThinMaterial 最轻量的毛玻璃，接近 Apple 地图
    // 注意：不要设置 alpha < 1，会导致模糊渲染异常
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    blurView = UIVisualEffectView(effect: blurEffect)
    super.init(frame: frame)
    backgroundColor = .clear
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurView.frame = bounds
    addSubview(blurView)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    blurView.frame = bounds
  }
}
