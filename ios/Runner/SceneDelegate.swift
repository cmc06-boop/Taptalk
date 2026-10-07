import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
	private var pendingEmailLink: String?
	private var emailLinkChannel: FlutterMethodChannel?

	override func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		super.scene(scene, willConnectTo: session, options: connectionOptions)
		configureEmailLinkChannel()
		for activity in connectionOptions.userActivities {
			handleEmailLink(activity.webpageURL)
		}
		for context in connectionOptions.urlContexts {
			handleEmailLink(context.url)
		}
	}

	override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
		super.scene(scene, continue: userActivity)
		handleEmailLink(userActivity.webpageURL)
	}

	override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		super.scene(scene, openURLContexts: URLContexts)
		for context in URLContexts {
			handleEmailLink(context.url)
		}
	}

	private func configureEmailLinkChannel() {
		guard let controller = window?.rootViewController as? FlutterViewController else {
			return
		}
		let channel = FlutterMethodChannel(
			name: "com.taptalk/email_links",
			binaryMessenger: controller.binaryMessenger
		)
		channel.setMethodCallHandler { [weak self] call, result in
			guard call.method == "getInitialLink" else {
				result(FlutterMethodNotImplemented)
				return
			}
			result(self?.takePendingEmailLink())
		}
		emailLinkChannel = channel
	}

	private func handleEmailLink(_ url: URL?) {
		guard let url else { return }
		let link = url.absoluteString
		guard link.contains("oobCode") || link.contains("mode=signIn") ||
			link.contains("caregiver-recovery") else {
			return
		}
		pendingEmailLink = link
		configureEmailLinkChannel()
		emailLinkChannel?.invokeMethod("onLink", arguments: link)
	}

	private func takePendingEmailLink() -> String? {
		let link = pendingEmailLink
		pendingEmailLink = nil
		return link
	}

}
