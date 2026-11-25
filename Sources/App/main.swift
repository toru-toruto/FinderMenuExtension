import Cocoa

/// 画面を持たないホストアプリ。
/// Finder 拡張から findermenuextension://<action>?path=<path>[&path=<path>...] で呼ばれ、処理したらすぐ終了する。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private static let vscodeBundleID = "com.microsoft.VSCode"

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handle(url)
        }
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // URL なしで起動された場合（初回登録時など）も、少し待って終了する
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSApp.terminate(nil)
        }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "findermenuextension",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }
        let paths = (components.queryItems ?? [])
            .filter { $0.name == "path" }
            .compactMap(\.value)
        guard !paths.isEmpty else { return }

        switch url.host {
        case "newfile":
            createTextFile(in: URL(fileURLWithPath: paths[0], isDirectory: true))
        case "vscode":
            openInVSCode(paths)
        default:
            NSLog("FinderMenuExtension: unknown action \(url.host ?? "nil")")
        }
    }

    // MARK: - 新規テキスト書類

    /// 「名称未設定.txt」「名称未設定 2.txt」… のうち空いている名前で空ファイルを作り、Finder で選択する。
    private func createTextFile(in folder: URL) {
        let fm = FileManager.default
        let baseName = "名称未設定"
        var candidate = folder.appendingPathComponent("\(baseName).txt")
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) \(n).txt")
            n += 1
        }

        guard fm.createFile(atPath: candidate.path, contents: Data()) else {
            showError("ファイルを作成できませんでした", detail: candidate.path)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([candidate])
    }

    // MARK: - VSCodeで開く

    /// VS Code 付属の `code` コマンドで、新しいウィンドウに開く。
    private func openInVSCode(_ paths: [String]) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.vscodeBundleID) else {
            showError("Visual Studio Code が見つかりません", detail: "VS Code をインストールしてください。")
            return
        }
        let cli = appURL.appendingPathComponent("Contents/Resources/app/bin/code")

        let process = Process()
        process.executableURL = cli
        process.arguments = ["-n"] + paths
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            showError("VS Code を起動できませんでした", detail: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)
app.run()
