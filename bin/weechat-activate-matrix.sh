#!/usr/bin/env bash

cp /opt/services/weechat-matrix-rs/target/release/libmatrix.so "$HOME"/.weechat/plugins/matrix.so
chmod 644 "$HOME"/.weechat/plugins/matrix.so

exit 0
