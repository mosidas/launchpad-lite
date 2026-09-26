#!/bin/sh
set -eu
# ponytail: CLT だけの環境で swift-testing を見つけるためのパス。Xcode を入れたら素の swift test で足りる。
D=/Library/Developer/CommandLineTools/Library/Developer
exec swift test \
  -Xswiftc -F -Xswiftc "$D/Frameworks" \
  -Xlinker -rpath -Xlinker "$D/Frameworks" \
  -Xlinker -rpath -Xlinker "$D/usr/lib" "$@"
