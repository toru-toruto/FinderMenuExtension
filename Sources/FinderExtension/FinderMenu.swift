import Cocoa
import FinderSync

/// Finder の右クリックメニューに項目を追加する拡張。
/// 拡張はサンドボックス内で動くため、ファイル作成や VS Code の起動などの実処理はホストアプリに依頼する。
@objc(FinderSync)
final class FinderSync: FIFinderSync {

    override init() {
        super.init()
        // すべてのフォルダでメニューを出すため、ルートを監視対象にする
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "")
        switch menuKind {
        case .contextualMenuForContainer:
            // フォルダ内の空欄を右クリックしたとき
            menu.addItem(withTitle: "新規テキスト書類", action: #selector(createTextFile(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "VSCodeで開く", action: #selector(openCurrentFolderInVSCode(_:)), keyEquivalent: "")
        case .contextualMenuForItems, .contextualMenuForSidebar:
            // ファイル・フォルダ（またはサイドバーの項目）を右クリックしたとき
            menu.addItem(withTitle: "VSCodeで開く", action: #selector(openSelectedItemsInVSCode(_:)), keyEquivalent: "")
        default:
            return nil
        }
        return menu
    }

    // MARK: - Actions

    @objc private func createTextFile(_ sender: AnyObject?) {
        guard let folder = FIFinderSyncController.default().targetedURL() else { return }
        sendToHostApp(action: "newfile", paths: [folder])
    }

    @objc private func openCurrentFolderInVSCode(_ sender: AnyObject?) {
        guard let folder = FIFinderSyncController.default().targetedURL() else { return }
        sendToHostApp(action: "vscode", paths: [folder])
    }

    @objc private func openSelectedItemsInVSCode(_ sender: AnyObject?) {
        let controller = FIFinderSyncController.default()
        let items = controller.selectedItemURLs() ?? []
        if !items.isEmpty {
            sendToHostApp(action: "vscode", paths: items)
        } else if let target = controller.targetedURL() {
            sendToHostApp(action: "vscode", paths: [target])
        }
    }

    // MARK: - Host app

    /// ホストアプリを URL スキーム経由で呼び出す。
    /// 例: findermenuextension://vscode?path=/Users/me/a&path=/Users/me/b
    private func sendToHostApp(action: String, paths: [URL]) {
        var components = URLComponents()
        components.scheme = "findermenuextension"
        components.host = action
        components.queryItems = paths.map { URLQueryItem(name: "path", value: $0.path) }
        guard let url = components.url else { return }

        // 拡張は <App>.app/Contents/PlugIns/<Ext>.appex にあるので、3 つ上がホストアプリ
        let hostApp = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open([url], withApplicationAt: hostApp, configuration: config) { _, error in
            if let error {
                NSLog("FinderMenuExtension: failed to call host app: \(error)")
            }
        }
    }
}
