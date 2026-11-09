import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureAudioSession()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    try? AVAudioSession.sharedInstance().setActive(true)
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      // .playAndRecord lets the same session play music/videos and record
      // voice messages.  .defaultToSpeaker keeps playback on the speaker, and
      // the category is not silenced by the iPhone mute switch.
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [
          .defaultToSpeaker,
          .allowBluetooth,
          .allowBluetoothA2DP,
          .allowAirPlay,
          .mixWithOthers,
        ]
      )
      try session.setActive(true)
    } catch {
      NSLog("OpenChat audio session error: \(error)")
    }

    NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: session,
      queue: .main
    ) { notification in
      guard
        let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: raw)
      else { return }
      if type == .ended {
        try? session.setActive(true)
      }
    }
  }
}
