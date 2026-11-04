#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = BeeModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        _ = NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.persist()
        return .terminateNow
    }
}

@main
struct SpellingBeeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Spelling Bee", id: "spelling-bee") {
            RootView(model: appDelegate.model)
        }
        .defaultSize(width: 1100, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
#else
import Glibc

@main
enum SpellingBeeMain {
    static func main() {
        let message = "Spelling Bee runs on macOS 14 or later. See README.md.\n"
        _ = message.withCString { fputs($0, stderr) }
        exit(1)
    }
}
#endif
