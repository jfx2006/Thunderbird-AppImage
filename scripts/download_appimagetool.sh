#!/bin/bash

set -xe

URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

CURL="curl --location --retry 10 --retry-delay 10"

${CURL} -o appimagetool.AppImage "${URL}"
chmod +x appimagetool.AppImage

./appimagetool.AppImage --appimage-extract
mv squashfs-root appimagetool
