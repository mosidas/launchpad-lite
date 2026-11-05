# ビルドとテストの補足

`scripts/bundle.sh` と `scripts/test.sh` の動作のうち、開発で知っておくことを説明する。道具とビルドの手順は [README](../README.md) の「ソースからビルドする」に従う。

## ビルド

- `scripts/bundle.sh` は release ビルド、`.app` の組み立て、アドホック署名を行う。
- `scripts/bundle.sh v1.2.3` のようにバージョンを渡すと、Info.plist の `CFBundleShortVersionString` と `CFBundleVersion` に書く。省略時は 0.0.0 になる。リリースのワークフローはタグ名を渡す。
- `scripts/bundle.sh` は、ビルドのたびに `Resources/AppIcon.png` から `AppIcon.icns` を作る。
- 再ビルドするとアドホック署名が変わり、アクセシビリティと画面収録の許可が無効になる。システム設定の一覧から LaunchpadLite を一度削除して追加し直す。

## テスト

`scripts/test.sh` は `swift test` を呼ぶ。Command Line Tools だけの環境では `swift test` が swift-testing を見つけられないため、検索パスを付けて呼ぶ。

## swift run で動かすとき

- 権限は LaunchpadLite ではなく、実行したターミナルに付く。
- 「ログイン時に起動」の切り替えはエラーになる。`.app` から起動したときだけ働く。
