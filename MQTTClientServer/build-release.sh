#!/bin/bash
# Release 构建：对完整依赖图传入 -Osize。
#  swift build -c release，会报错
# Swift 6.2 + Xcode 16 下，默认的 release（-O）在编译 fluent-kit 的 EnumBuilder.generateDatatype
# 时可能触发 CopyPropagation/ownership 校验崩溃（见 swift build -c release 的 internal compiler error）。
# -Osize 会走不同的 SIL 优化路径，可稳定通过。
set -euo pipefail
cd "$(dirname "$0")"
exec swift build -c release -Xswiftc -Osize "$@"
