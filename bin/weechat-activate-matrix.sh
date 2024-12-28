#!/usr/bin/env sh

test -f "$HOME"/.weechat/plugins/matrix.so && rm "$HOME"/.weechat/plugins/matrix.so
test -h "$HOME"/.weechat/plugins/matrix.so && unlink "$HOME"/.weechat/plugins/matrix.so
ln -s /opt/services/weechat-matrix-rs/target/release/libmatrix.so "$HOME"/.weechat/plugins/matrix.so

exit 0
