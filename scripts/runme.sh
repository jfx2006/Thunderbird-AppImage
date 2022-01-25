#!/bin/bash

set -xe

: PRODUCT                       "${PRODUCT:=thunderbird}"
: VERSION			"${VERSION:=91.5.1}"
: BUILD_NUMBER			"${BUILD_NUMBER:=1}"
: CANDIDATES_DIR		"${CANDIDATES_DIR:=https://ftp.mozilla.org/pub/thunderbird/candidates/}"
: L10N_LOCALES			"${L10N_LOCALES:=https://hg.mozilla.org/releases/comm-esr91/raw-file/tip/mail/locales/onchange-locales}"

# Required env variables
test "$VERSION"
test "$BUILD_NUMBER"
test "$CANDIDATES_DIR"
test "$L10N_LOCALES"

SCRIPT_DIRECTORY="/scripts"
WORKSPACE="/workspace"
ARTIFACTS_DIR="/artifacts"
APPIMAGETOOL_PATH=${SCRIPT_DIRECTORY}/appimagetool/usr/bin
APPIMAGETOOL=${APPIMAGETOOL_PATH}/appimagetool

# appimagetool needs to find desktop-file-validate in $PATH
export PATH=$PATH:$APPIMAGETOOL_PATH

TARGET="Thunderbird-${VERSION}.AppImage"
TARGET_FULL_PATH="$ARTIFACTS_DIR/$TARGET"
APPDIR_DEST="${WORKSPACE}/AppDir"
PRODUCT_DEST="${APPDIR_DEST}/thunderbird"
DESKTOP_FILE="net.thunderbird.Thunderbird.desktop"

mkdir -p "${ARTIFACTS_DIR}"
rm -rf "${APPDIR_DEST}" && mkdir -p "${APPDIR_DEST}"

CURL="curl --location --retry 10 --retry-delay 10"

# Download and extract en-US linux64 binary
$CURL -o "${WORKSPACE}/${PRODUCT}.tar.bz2" \
    "${CANDIDATES_DIR}/${VERSION}-candidates/build${BUILD_NUMBER}/linux-x86_64/en-US/${PRODUCT}-${VERSION}.tar.bz2"
tar -C "${APPDIR_DEST}" -xf "${WORKSPACE}/${PRODUCT}.tar.bz2"

# Symlink used for launching
mkdir -p "${APPDIR_DEST}/usr/bin"
ln -s ../../${PRODUCT}/${PRODUCT} "${APPDIR_DEST}/usr/bin/"

DISTRIBUTION_DIR="${PRODUCT_DEST}/distribution"
mkdir -p "${DISTRIBUTION_DIR}"

cp -v "${SCRIPT_DIRECTORY}/${DESKTOP_FILE}" "${APPDIR_DEST}"
cp -v "${PRODUCT_DEST}/chrome/icons/default/default256.png" "${APPDIR_DEST}/net.thunderbird.thunderbird.png"

# Add a group policy file to disable app updates, as those are handled by snapd
cp -v "${SCRIPT_DIRECTORY}/policies.json" "${DISTRIBUTION_DIR}"

cp -v "${SCRIPT_DIRECTORY}/AppRun" "${APPDIR_DEST}"

# Use list of locales to fetch L10N XPIs
$CURL -o "${WORKSPACE}/l10n_locales" "${L10N_LOCALES}"
sed -i -e '/^ja-JP-mac$/d' "${WORKSPACE}/l10n_locales"
locales=$(cat ${WORKSPACE}/l10n_locales)

mkdir -p "${DISTRIBUTION_DIR}/extensions"
for locale in ${locales}; do
    $CURL -o "${PRODUCT_DEST}/distribution/extensions/langpack-${locale}@${PRODUCT}.mozilla.org.xpi" \
        "${CANDIDATES_DIR}/${VERSION}-candidates/build${BUILD_NUMBER}/linux-x86_64/xpi/${locale}.xpi"
done

cd ${WORKSPACE}
${APPIMAGETOOL} -n --comp xz ${APPDIR_DEST} ${TARGET}

chmod +x ${TARGET}

mv ${TARGET} ${TARGET_FULL_PATH}
