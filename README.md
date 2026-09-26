# launchpad-lite

Raycast の代わりに使う、最小限の macOS ランチャー。アプリのあいまい検索と起動、ウィンドウ操作、スクリーンショット、スリープ・画面ロックをホットキーで行う。Swift(SwiftPM)製で Xcode を必要としない。

## 使い方

`scripts/bundle.sh` でビルドし、できた `dist/LaunchpadLite.app` を `/Applications` へコピーして開く。Dock とメニューバーには何も出ない。

ログイン時に自動で起動するには、システム設定 > 一般 > ログイン項目に `LaunchpadLite.app` を手で追加する。

## ホットキー

定義は `Sources/LaunchpadLite/main.swift` にある。変えるときはここを直す。

| キー | 動作 |
| :- | :- |
| ⌘Space | ランチャーを開く・閉じる |
| ⌃⌥← / ⌃⌥→ | 左半分 / 右半分 |
| ⌃⌥↑ / ⌃⌥↓ | 上半分 / 下半分 |
| ⌃⌥Return | 最大化 |
| ⌃⌥C | 中央へ置く |
| ⌃⌥⇧← / ⌃⌥⇧→ | 幅を狭める / 広げる(画面の 1/24 ずつ) |
| ⌃⌥⇧↑ / ⌃⌥⇧↓ | 高さを縮める / 伸ばす(画面の 1/24 ずつ) |
| ⌃⌥⌘← / ⌃⌥⌘→ / ⌃⌥⌘↑ / ⌃⌥⌘↓ | 左 / 右 / 上 / 下へ移動(画面の 1/24 ずつ) |
| ⌃⌥S | 範囲を選んでスクリーンショットをクリップボードへ |
| ⌃⌥L | 画面をロックする |
| ⌃⌥⇧L | スリープする |

画面ロックは macOS の非公開 API(`login.framework` の `SACLockScreenImmediate`)を使う。

## 権限

システム設定 > プライバシーとセキュリティで、次の 2 つに LaunchpadLite を許可する。

- アクセシビリティ: ウィンドウ操作に使う。
- 画面収録: スクリーンショット(`screencapture`)に使う。

再ビルドするとアドホック署名が変わり、許可が効かなくなる。一覧から LaunchpadLite を一度消して追加し直す。`swift run` で動かしたときは、権限は LaunchpadLite ではなく実行したターミナルに付く。

## ビルドとテスト

- ビルド: `scripts/bundle.sh`(release ビルド、`.app` の組み立て、アドホック署名を行う)
- テスト: `scripts/test.sh`(Command Line Tools だけの環境では `swift test` が swift-testing を見つけられないため、検索パスを付けて呼ぶ)
