# launchpad-lite

Raycast の代わりに使う、最小限の macOS ランチャー。アプリのあいまい検索と起動、ウィンドウ操作、スクリーンショット、スリープをホットキーで行う。Swift(SwiftPM)製で Xcode を必要としない。

## 使い方

[Releases](https://github.com/mosidas/launchpad-lite/releases) から `LaunchpadLite-<バージョン>.zip` をダウンロードして展開し、`LaunchpadLite.app` を `/Applications` へ移して開く。Apple Silicon 向けのビルドである。Dock には出ず、メニューバーにアイコンが出る。

配布物はアドホック署名だけで公証していないため、初回の起動は Gatekeeper に止められる。次のどちらかで起動を許可する。

- ターミナルで `xattr -dr com.apple.quarantine /Applications/LaunchpadLite.app` を実行し、隔離属性を外す。
- 一度開いてブロックされたあと、システム設定 > プライバシーとセキュリティ の下部にある「このまま開く」を押す(macOS 14 では Finder で右クリックして「開く」でもよい)。

ソースからビルドするときは、`scripts/bundle.sh` を実行し、できた `dist/LaunchpadLite.app` を `/Applications` へコピーして開く。

ログイン時に自動で起動するには、メニューバーのアイコンから「ログイン時に起動」を選択する。もう一度選択すると解除する。この切り替えは `.app` から起動したときだけ働き、`swift run` で動かしたときはエラーになる。以前にシステム設定 > 一般 > ログイン項目へ `LaunchpadLite.app` を手で追加していた場合は、二重に起動しないようその項目を削除する。

## ホットキー

定義は `Sources/LaunchpadLite/main.swift` にある。変えるときはここを直す。

OS の標準ショートカットと重なるキーがある。システム設定 > キーボード > キーボードショートカットで、OS 側の同じショートカットを先に無効にしておく。

- ⌘Space: Spotlight のショートカットを無効にする。
- ⌘⇧3・⌘⇧4: スクリーンショットのショートカットを無効にする。

| キー | 動作 |
| :- | :- |
| ⌘Space | ランチャーを開く・閉じる |
| ⌘⇧S | スクリーンショットのツールバーを開く(⌘⇧5 と同じ) |
| ⌘⇧← / ⌘⇧→ | 左半分 / 右半分 |
| ⌘⇧↑ / ⌘⇧↓ | 上半分 / 下半分 |
| ⌘⇧1 / ⌘⇧2 / ⌘⇧3 / ⌘⇧4 | 右上 1/4 / 左上 1/4 / 左下 1/4 / 右下 1/4 |
| ⌘⇧Return | 最大化 |
| ⌘⇧C | 中央 3/4(幅・高さとも画面の 3/4 にして中央へ移す) |
| ⌃⌘← / ⌃⌘→ | 前 / 次のディスプレイへ移す |
| ⌘⌥S | スリープする |

## 権限

ウィンドウ操作のため、システム設定 > プライバシーとセキュリティ > アクセシビリティで LaunchpadLite を許可する。

再ビルドするとアドホック署名が変わり、許可が無効になる。一覧から LaunchpadLite を一度消して追加し直す。`swift run` で動かしたときは、権限は LaunchpadLite ではなく実行したターミナルに付く。

## ビルドとテスト

- ビルド: `scripts/bundle.sh`(release ビルド、`.app` の組み立て、アドホック署名を行う)
- テスト: `scripts/test.sh`(Command Line Tools だけの環境では `swift test` が swift-testing を見つけられないため、検索パスを付けて呼ぶ)
