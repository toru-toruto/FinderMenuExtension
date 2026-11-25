# FinderMenuExtension

macOS の Finder の右クリックメニューに、便利な項目を追加する Finder Sync 拡張です。

| 右クリックした場所 | 追加される項目 |
|---|---|
| フォルダ内の空欄 | **新規テキスト書類** / **VSCodeで開く**（いま開いているフォルダ） |
| ファイル・フォルダ（複数選択も可） | **VSCodeで開く**（選んだもの） |
| サイドバーの項目 | **VSCodeで開く** |

- **新規テキスト書類**: 空の `名称未設定.txt` を作り、Finder で選択します。同じ名前があるときは `名称未設定 2.txt`、`名称未設定 3.txt` … と番号を付けます。
- **VSCodeで開く**: Visual Studio Code の新しいウィンドウで開きます（`code -n` と同じ動き）。

## 必要なもの

- macOS 13 以降
- Xcode（`swiftc` と `codesign` を使います）
- キーチェーンにある **Apple Development** 証明書（署名に使います）
- 「VSCodeで開く」を使う場合は Visual Studio Code

## インストール

```sh
./build.sh
```

ビルド・署名をして `~/Applications/FinderMenuExtension.app` に配置し、Finder 拡張を有効にします。コードを変更したあとも、同じコマンドで反映できます。

署名に使う証明書を指定したいときは、次のように実行します。

```sh
SIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" ./build.sh
```

メニューに出てこないときは、次を確認してください。

1. システム設定 → 一般 → ログイン項目と機能拡張 → Finder 拡張で、FinderMenuExtension がオンになっているか
2. Finder を再起動したか（Option を押しながら Dock の Finder を右クリック →「再度開く」）

デスクトップや書類フォルダで初めて「新規テキスト書類」を使うと、フォルダへのアクセスを許可するか聞かれます。

## 仕組み

```
Finder ──右クリック──▶ Finder 拡張 (FinderExtension.appex)
                          │ findermenuextension://<action>?path=...
                          ▼
                       ホストアプリ (FinderMenuExtension.app)
                          ├─ newfile: .txt を作成して Finder で選択
                          └─ vscode : VS Code 付属の code コマンドで開く
```

Finder 拡張はサンドボックスの中でしか動けないため、ファイルを作ったり他のアプリを起動したりできません。そこで拡張はメニューを出すことだけを担当し、実際の処理は URL スキーム経由でホストアプリに頼みます。ホストアプリは画面を持たず（`LSUIElement`）、処理が終わるとすぐ終了します。

## ファイル構成

| パス | 内容 |
|---|---|
| `Sources/FinderExtension/FinderMenu.swift` | Finder 拡張。メニュー項目を出し、ホストアプリを呼ぶ |
| `Sources/App/main.swift` | ホストアプリ。ファイル作成と VS Code の起動 |
| `Resources/App-Info.plist` | ホストアプリの Info.plist（URL スキームの登録） |
| `Resources/Extension-Info.plist` | Finder 拡張の Info.plist |
| `Resources/Extension.entitlements` | Finder 拡張のエンタイトルメント（App Sandbox） |
| `build.sh` | ビルド・署名・インストール・有効化 |

## アンインストール

```sh
pluginkit -e ignore -i local.findermenuextension.FinderExtension
rm -rf ~/Applications/FinderMenuExtension.app
```
