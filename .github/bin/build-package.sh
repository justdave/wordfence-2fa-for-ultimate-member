#!/bin/bash

set -euo pipefail

PLUGIN_SLUG="wordfence-2fa-for-ultimate-member"
PLUGIN_FILE="${PLUGIN_SLUG}.php"

if [ ! -e "${PLUGIN_FILE}" ]; then
    echo "Not running in correct directory. pwd=${PWD}" >&2
    exit 1
fi

TAG="${1:-}"
if [ -z "${TAG}" ]; then
    TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi
if [ -z "${TAG}" ]; then
    TAG="$(grep -E '^ \* Version:' "${PLUGIN_FILE}" | sed -e 's/.*Version: //' | head -1)"
fi
if [ -z "${TAG}" ]; then
    echo "Unable to determine package version/tag" >&2
    exit 1
fi

ZIP_BASENAME="${PLUGIN_SLUG}-${TAG}.zip"
ZIP_PATH="../${ZIP_BASENAME}"
DISTIGNORE_FILE=".distignore"

# Mirror the release job's generated readme/assets before packaging.
/bin/bash "${PWD}/.github/bin/make-readmetxt.sh"

if [ ! -f "${DISTIGNORE_FILE}" ]; then
    echo "Missing ${DISTIGNORE_FILE}" >&2
    exit 1
fi

rm -f "${ZIP_PATH}"

EXCLUDES=()
while IFS= read -r line || [ -n "${line}" ]; do
    # Trim leading/trailing whitespace.
    line="${line#${line%%[![:space:]]*}}"
    line="${line%${line##*[![:space:]]}}"

    if [ -z "${line}" ] || [[ "${line}" == \#* ]]; then
        continue
    fi

    if [[ "${line}" == /* ]]; then
        # Root-anchored .distignore entries map to paths beneath the plugin slug.
        pattern="${line#/}"
        EXCLUDES+=("${PLUGIN_SLUG}/${pattern}")
        EXCLUDES+=("${PLUGIN_SLUG}/${pattern}/*")
    else
        EXCLUDES+=("*${line}")
    fi
done < "${DISTIGNORE_FILE}"

pushd .. >/dev/null
zip -r "${ZIP_BASENAME}" "${PLUGIN_SLUG}" -x "${EXCLUDES[@]}"
popd >/dev/null

echo "Created ${ZIP_PATH}"