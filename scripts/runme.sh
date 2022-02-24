#!/bin/bash

set -xe

: PRODUCT                       "${PRODUCT:=thunderbird}"

# Required env variables
test "$VERSION"
test "$BUILD_NUMBER"
test "$PROJECT"

CANDIDATES_DIR="https://ftp.mozilla.org/pub/${PRODUCT}/candidates"
L10N_LOCALES="https://hg.mozilla.org/releases/${PROJECT}/raw-file/tip/mail/locales/onchange-locales"

WORKSPACE="$(pwd)"
SCRIPT_DIRECTORY="${WORKSPACE}/scripts"
ARTIFACTS_DIR="${WORKSPACE}/artifacts"
APPIMAGETOOL_PATH=${WORKSPACE}/appimagetool/usr/bin
APPIMAGETOOL=${APPIMAGETOOL_PATH}/appimagetool

# appimagetool needs to find desktop-file-validate in $PATH
export PATH=$PATH:$APPIMAGETOOL_PATH

if [[ "${PROJECT}" =~ ^comm-esr ]]; then
  DESKTOP_FILE="net.thunderbird.Thunderbird.desktop"
  ICON_FILE="net.thunderbird.Thunderbird.png"
  APPSTREAM="net.thunderbird.Thunderbird.appdata.xml"
elif [[ "${PROJECT}" = comm-beta ]]; then
  DESKTOP_FILE="net.thunderbird.ThunderbirdBeta.desktop"
  ICON_FILE="net.thunderbird.ThunderbirdBeta.png"
  APPSTREAM="net.thunderbird.ThunderbirdBeta.appdata.xml"
else
  echo "Invalid project ${PROJECT}."
  exit 66
fi

TARGET="Thunderbird-${VERSION}.AppImage"
APPDIR_DEST="${WORKSPACE}/AppDir"

mkdir -p "${ARTIFACTS_DIR}"
rm -rf "${APPDIR_DEST}" && mkdir -p "${APPDIR_DEST}"

CURL="curl --location --retry 10 --retry-delay 10"

# Download and extract en-US linux64 binary
$CURL -o "${WORKSPACE}/${PRODUCT}.tar.bz2" \
    "${CANDIDATES_DIR}/${VERSION}-candidates/build${BUILD_NUMBER}/linux-x86_64/en-US/${PRODUCT}-${VERSION}.tar.bz2"
tar -C "${APPDIR_DEST}" --strip-components=1 -xf "${WORKSPACE}/${PRODUCT}.tar.bz2"

DISTRIBUTION_DIR="${APPDIR_DEST}/distribution"
mkdir -p "${DISTRIBUTION_DIR}"

cp -v "${SCRIPT_DIRECTORY}/${DESKTOP_FILE}" "${APPDIR_DEST}/"
cp -v "${SCRIPT_DIRECTORY}/${ICON_FILE}" "${APPDIR_DEST}/"

# Add a group policy file to disable app updates
cp -v "${SCRIPT_DIRECTORY}/policies.json" "${DISTRIBUTION_DIR}"
# distribution.ini
cp -v "${SCRIPT_DIRECTORY}/distribution.ini" "${DISTRIBUTION_DIR}"

cp -v "${SCRIPT_DIRECTORY}/AppRun" "${APPDIR_DEST}"

# Use list of locales to fetch L10N XPIs
$CURL -o "${WORKSPACE}/l10n_locales" "${L10N_LOCALES}"
sed -i -e '/^ja-JP-mac$/d' "${WORKSPACE}/l10n_locales"
locales=$(cat ${WORKSPACE}/l10n_locales)

mkdir -p "${DISTRIBUTION_DIR}/extensions"
for locale in ${locales}; do
    $CURL -o "${DISTRIBUTION_DIR}/extensions/langpack-${locale}@${PRODUCT}.mozilla.org.xpi" \
        "${CANDIDATES_DIR}/${VERSION}-candidates/build${BUILD_NUMBER}/linux-x86_64/xpi/${locale}.xpi"
done

mkdir -p "${APPDIR_DEST}/usr/share/metainfo"
cp -v "${SCRIPT_DIRECTORY}/${APPSTREAM}" "${APPDIR_DEST}/usr/share/metainfo/"

cd ${WORKSPACE}
${APPIMAGETOOL} -v --comp xz \
	-u "gh-releases-zsync|jfx2006|thunderbird-appimage|${PROJECT}|Thunderbird*.AppImage.zsync" \
	${APPDIR_DEST} ${TARGET}

chmod +x ${TARGET}

mv ${TARGET} ${TARGET}.zsync ${ARTIFACTS_DIR}/
