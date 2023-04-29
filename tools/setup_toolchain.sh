#!/bin/bash

set -eu

declare -r DAKINI_HOME='/tmp/dakini-toolchain'

if [ -d "${DAKINI_HOME}" ]; then
	PATH+=":${DAKINI_HOME}/bin"
	export DAKINI_HOME \
		PATH
	return 0
fi

declare -r DAKINI_CROSS_TAG="$(jq --raw-output '.tag_name' <<< "$(curl --retry 10 --retry-delay 3 --silent --url 'https://api.github.com/repos/AmanoTeam/Dakini/releases/latest')")"
declare -r DAKINI_CROSS_TARBALL='/tmp/daiki.tar.xz'
declare -r DAKINI_CROSS_URL="https://github.com/AmanoTeam/Dakini/releases/download/${DAKINI_CROSS_TAG}/x86_64-unknown-linux-gnu.tar.xz"

curl --retry 10 --retry-delay 3 --silent --location --url "${DAKINI_CROSS_URL}" --output "${DAKINI_CROSS_TARBALL}"
tar --directory="$(dirname "${DAKINI_CROSS_TARBALL}")" --extract --file="${DAKINI_CROSS_TARBALL}"

rm "${DAKINI_CROSS_TARBALL}"

mv '/tmp/dakini' "${DAKINI_HOME}"

PATH+=":${DAKINI_HOME}/bin"

export DAKINI_HOME \
	PATH
