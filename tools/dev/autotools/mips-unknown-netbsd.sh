#/bin/bash

set -e

if [ -z "${DAKINI_HOME}" ]; then
	DAKINI_HOME="$(realpath "$(dirname "${0}")")/../../../../.."
fi

set -u

CROSS_COMPILE_SYSTEM='netbsd'
CROSS_COMPILE_ARCHITECTURE='mips'
CROSS_COMPILE_TRIPLET="${CROSS_COMPILE_ARCHITECTURE}-unknown-${CROSS_COMPILE_SYSTEM}"
CROSS_COMPILE_SYSROOT="${DAKINI_HOME}/${CROSS_COMPILE_TRIPLET}"

CC="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-gcc"
CXX="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-g++"
AR="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-ar"
AS="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-as"
LD="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-ld"
NM="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-nm"
RANLIB="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-ranlib"
STRIP="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-strip"
OBJCOPY="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-objcopy"
READELF="${DAKINI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-readelf"

export \
	CROSS_COMPILE_TRIPLET \
	CROSS_COMPILE_SYSTEM \
	CROSS_COMPILE_ARCHITECTURE \
	CROSS_COMPILE_SYSROOT \
	CC \
	CXX \
	AR \
	AS \
	LD \
	NM \
	RANLIB \
	STRIP \
	OBJCOPY \
	READELF

set +eu
