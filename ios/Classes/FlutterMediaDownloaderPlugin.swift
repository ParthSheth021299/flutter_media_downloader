import Flutter
import UIKit


public class FlutterMediaDownloaderPlugin: NSObject, FlutterPlugin , UIDocumentPickerDelegate, UNUserNotificationCenterDelegate{
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "showCustomNotification", binaryMessenger: registrar.messenger())
    let instance = FlutterMediaDownloaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    UNUserNotificationCenter.current().delegate = instance
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "showCustomNotification":
            if let arguments = call.arguments as? [String: Any],
               let title = arguments["title"] as? String,
               let body = arguments["body"] as? String {
                showCustomNotification(title: title, body: body)
            } else {
                print("Invalid arguments for custom notification")
            }
            result(nil)
    case "openMediaFile":
       if let arguments = call.arguments as? [String: Any], let filePath = arguments["filePath"] as? String {
           openMediaFile(filePath: filePath, result: result)
             } else {
               result(false)
             }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

   private func showCustomNotification(title: String, body: String) {
       let content = UNMutableNotificationContent()
       content.title = title
       content.body = body
       content.sound = UNNotificationSound.default // Add sound to the notification

       let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
       let request = UNNotificationRequest(identifier: "showCustomNotification", content: content, trigger: trigger)

       UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
           if granted {
               UNUserNotificationCenter.current().add(request) { error in
                   if let error = error {
                       print("Error showing custom notification: \(error)")
                   } else {

                       print("Custom notification added successfully")
                   }
               }

           } else {
               print("Permission denied for notifications.")
           }
       }
   }
   private func openMediaFile(filePath: String, result: @escaping FlutterResult) {
       let fileURL = URL(fileURLWithPath: filePath)

       let documentPicker = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
       documentPicker.delegate = self
       documentPicker.modalPresentationStyle = .formSheet

       if let viewController = UIApplication.shared.keyWindow?.rootViewController {
           viewController.present(documentPicker, animated: true, completion: nil)
       }
   }
}

extension FlutterMediaDownloaderPlugin: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return UIApplication.shared.windows.first!.rootViewController!
    }

}
