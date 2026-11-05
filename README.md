# launchpad-lite

Raycast の代わりに使う、最小限の macOS ランチャー。

- アプリのあいまい検索と起動(日本語名と打ち間違いにも対応)
- ウィンドウの移動とサイズ変更
- スクリーンショットと、撮った範囲を画面に浮かべる表示
- スリープ
- 外付けマウスのポインター・ホイール・ボタンの設定
- キーボードの F1〜F12 の割り当てと、キーの置き換え

## 動作環境

- macOS 14 以上(Apple Silicon)

## インストール

### Releases から

1. [Releases](https://github.com/mosidas/launchpad-lite/releases) から `LaunchpadLite-<バージョン>.zip` をダウンロードして展開する。
2. `LaunchpadLite.app` を `/Applications` へ移す。
3. 配布物はアドホック署名だけで公証していないため、初回の起動は Gatekeeper に止められる。ターミナルで `xattr -dr com.apple.quarantine /Applications/LaunchpadLite.app` を実行し、隔離属性を外す。
4. `LaunchpadLite.app` を開く。

### ソースからビルドする

1. Swift 6.0 以上を含む Xcode か Command Line Tools をインストールする。
2. `scripts/bundle.sh` を実行する。`dist/LaunchpadLite.app` ができる。
3. `LaunchpadLite.app` を `/Applications` へコピーして開く。

## 使い方

LaunchpadLite は Dock に出ず、メニューバーにアイコンが出る。

1. システム設定 > プライバシーとセキュリティ > アクセシビリティで LaunchpadLite を許可する。
2. システム設定 > キーボード > キーボードショートカットで、Spotlight のショートカット(⌘Space)を無効にする。
3. ⌘Space を押す。ランチャーが開く。
4. アプリ名の一部を入力し、Return を押す。一覧の先頭のアプリが起動する。

ホットキーの一覧と、マウス・キーボード・スクリーンショットの設定は、メニューバーのアイコンから「設定…」を開いて確かめる。

## 開発

ビルドは [ソースからビルドする](#ソースからビルドする) の手順で行う。テストは次のコマンドで実行する。

```sh
scripts/test.sh
```

- 再ビルドするとアドホック署名が変わり、アクセシビリティと画面収録の許可が無効になる。システム設定の一覧から LaunchpadLite を一度削除して追加し直す。
- `swift run` で動かすと、権限は実行したターミナルに付く。「ログイン時に起動」の切り替えはエラーになる。

## ライセンス

[MIT License](LICENSE)
