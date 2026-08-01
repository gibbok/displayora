import AppKit

@main
final class DisplayoraApp: NSObject, NSApplicationDelegate {
    static func main() {
        let application = NSApplication.shared
        let delegate = DisplayoraApp()

        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = Greeting.message
        alert.runModal()

        NSApplication.shared.terminate(nil)
    }
}
