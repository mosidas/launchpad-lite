# launchpad-lite

Raycast の代わりに使う、最小限の macOS ランチャー。アプリのあいまい検索と起動、ウィンドウ操作、スクリーンショット、スリープをホットキーで行い、外付けマウスとキーボードの割り当ても設定する。

## 動作環境

- macOS 14 以上(Apple Silicon)
- アクセシビリティの許可。ウィンドウ操作と、マウスとキーボードのイベントの書き換えに使う
- 画面収録の許可。範囲を撮って画面に浮かべる機能に使う

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

ホットキーの一覧と変更は、メニューバーのアイコンから「設定…」を開いた「ホットキー」のページで行う。

ウィンドウ操作・スクリーンショット・マウス・キーボードを使うには、[LaunchpadLite の機能と設定](docs/features.md) の説明に従って設定する。

## 開発

道具とビルドは「ソースからビルドする」の手順と同じである。テストは次のコマンドで実行する。

```sh
scripts/test.sh
```

再ビルドの後に権限が無効になったときは、[ビルドとテストの補足](docs/development.md) の手順で許可し直す。

## ライセンス

[MIT License](LICENSE)
