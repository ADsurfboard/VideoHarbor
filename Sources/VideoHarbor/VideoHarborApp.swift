import SwiftUI

@main
struct VideoHarborApp: App {
    @StateObject private var model = HarborAppModel()

    var body: some Scene {
        WindowGroup {
            HarborRootView(model: model)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("解析分享链接") {
                    model.selectedSection = .extract
                    model.resolveShareText()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
            CommandGroup(after: .pasteboard) {
                Button("粘贴并解析") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        model.shareText = text
                        model.selectedSection = .extract
                        model.resolveShareText()
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}
