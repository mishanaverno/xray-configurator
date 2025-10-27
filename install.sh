#!/bin/sh

PLATFORM=$1
if [ -z "$PLATFORM" ]; then
    ARCH="64"
else
    case "$PLATFORM" in
        linux/amd64)
            ARCH="64"
            ;;
        linux/arm64|linux/arm64/v8)
            ARCH="arm64-v8a"
            ;;
        linux/ppc64le)
            ARCH="ppc64le"
            ;;
        linux/s390x)
            ARCH="s390x"
            ;;
        *)
            ARCH=""
            ;;
    esac
fi
[ -z "${ARCH}" ] && echo "Error: Not supported OS Architecture" && exit 1
# Get Xray-core latest version
tmp_file="$(mktemp)"
if ! curl -L -H "Accept: application/vnd.github.v3+json" -o "$tmp_file" 'https://api.github.com/repos/XTLS/Xray-core/releases/latest'; then
    "rm" "$tmp_file"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
fi
RELEASE_LATEST="$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')"
if [[ -z "$RELEASE_LATEST" ]]; then
    if grep -q "API rate limit exceeded" "$tmp_file"; then
        echo "error: github API rate limit exceeded"
    else
        echo "error: Failed to get the latest release version."
        echo "Welcome bug report:https://github.com/XTLS/Xray-install/issues"
    fi
    "rm" "$tmp_file"
    exit 1
fi
"rm" "$tmp_file"
RELEASE_LATEST="v${RELEASE_LATEST#v}"

echo "Latest version of Xray-core is ${RELEASE_LATEST}"
# Download binary file
XRAY_FILE="Xray-linux-${ARCH}.zip"
ZIP_FILE="./xray.zip"
DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/${RELEASE_LATEST}/${XRAY_FILE}"
echo "Downloading Xray archive: ${XRAY_FILE}"
if curl -f -LR -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
    echo "ok."
else
    echo 'error: Download failed! Please check your network or try again.'
    exit 1
fi
echo "Downloading verification file for Xray archive: ${DOWNLOAD_LINK}.dgst"
if curl -f -LsSR -H 'Cache-Control: no-cache' -o "${ZIP_FILE}.dgst" "${DOWNLOAD_LINK}.dgst"; then
    echo "ok."
else
    echo 'error: Download failed! Please check your network or try again.'
    exit 1
fi
if grep 'Not Found' "${ZIP_FILE}.dgst"; then
    echo 'error: This version does not support verification. Please replace with another version.'
    exit 1
fi

# Verification of Xray archive
CHECKSUM=$(awk -F '= ' '/256=/ {print $2}' "${ZIP_FILE}.dgst")
LOCALSUM=$(sha256sum "$ZIP_FILE" | awk '{printf $1}')
if [[ "$CHECKSUM" != "$LOCALSUM" ]]; then
    echo 'error: SHA256 check failed! Please check your network or try again.'
exit 1
fi

mkdir un && unzip "${ZIP_FILE}" -d un
cp un/xray /usr/bin/xray
rm -rf un
rm -f "${ZIP_FILE}.dgst"
rm -f "${ZIP_FILE}"
chmod +x /usr/bin/xray

