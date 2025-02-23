#!/bin/bash

set -eu

declare -r revision="$(git rev-parse --short HEAD)"

declare -r workdir="${PWD}"

declare -r toolchain_directory='/tmp/dakini'
declare -r share_directory="${toolchain_directory}/usr/local/share/dakini"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.3.0'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.1'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare binutils_directory=''

declare -r gcc_tarball='/tmp/gcc.tar.gz'
declare -r gcc_directory='/tmp/gcc-master'

declare -r optflags='-w -Os'
declare -r linkflags='-Wl,-s'

declare -r max_jobs="$(($(nproc) * 17))"

declare -ra triplets=(
	'shle-unknown-netbsdelf'
	'vax-unknown-netbsdelf'
	'i386-unknown-netbsdelf'
	'armv6-unknown-netbsdelf-eabihf'
	'armv7-unknown-netbsdelf-eabihf'
	'aarch64-unknown-netbsd'
	'x86_64-unknown-netbsd'
	'mips-unknown-netbsd'
	'alpha-unknown-netbsd'
	'hppa-unknown-netbsd'
	'sparc-unknown-netbsdelf'
	'sparc64-unknown-netbsd'
	'powerpc-unknown-netbsd'
)

function setup_binutils() {
	
	local binutils_version=''
	local binutils_url=''
	local binutils_tarball=''
	local tgt="${1}"
	
	declare -r tgt
	
	if [ "${tgt}" = 'aarch64-unknown-netbsd' ] || [ "${tgt}" = 'armv7-unknown-netbsdelf-eabihf' ] || [ "${tgt}" = 'armv6-unknown-netbsdelf-eabihf' ]; then
		binutils_version='2.41'
		binutils_directory="/tmp/binutils-${binutils_version}"
		binutils_url="https://ftp.gnu.org/gnu/binutils/binutils-${binutils_version}.tar.xz"
	else
		binutils_version='2.44'
		binutils_directory="/tmp/binutils-with-gold-${binutils_version}"
		binutils_url="https://ftp.gnu.org/gnu/binutils/binutils-with-gold-${binutils_version}.tar.xz"
	fi
	
	binutils_tarball="/tmp/binutils-${binutils_version}.tar.xz"
	
	declare -r binutils_version
	declare -r binutils_url
	declare -r binutils_tarball
	
	if ! [ -f "${binutils_tarball}" ]; then
		curl \
			--url "${binutils_url}" \
			--retry '30' \
			--retry-all-errors \
			--retry-delay '0' \
			--retry-max-time '0' \
			--location \
			--silent \
			--output "${binutils_tarball}"
		
		tar \
			--directory="$(dirname "${binutils_directory}")" \
			--extract \
			--file="${binutils_tarball}"
	fi
	
	[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"
	
	if ! [ -f "${binutils_directory}/patched" ]; then
		if [ "${binutils_version}" = '2.41' ]; then
			for name in "${workdir}/submodules/netbsd-ports/devel/binutils/patches/patch-"*; do
				patch --directory="${binutils_directory}" --strip='0' --input="${name}"
			done
			
			patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/patches/0001-Make-arm--netbsdelf-eabihf-a-distinct-target.patch"
		elif [ "${binutils_version}" = '2.44' ]; then
			patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-gold-Use-char16_t-char32_t-instead-of-uint16_.patch"
			patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Disable-annoying-linker-warnings.patch"
		fi
		
		touch "${binutils_directory}/patched"
	fi
	
}

declare build_type="${1}"

if [ -z "${build_type}" ]; then
	build_type='native'
fi

declare is_native='0'

if [ "${build_type}" == 'native' ]; then
	is_native='1'
fi

declare CROSS_COMPILE_TRIPLET=''

if ! (( is_native )); then
	source "./submodules/obggcc/toolchains/${build_type}.sh"
fi

declare -r \
	build_type \
	is_native

if ! [ -f "${gmp_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${gmp_tarball}"
	
	tar \
		--directory="$(dirname "${gmp_directory}")" \
		--extract \
		--file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${mpfr_tarball}"
	
	tar \
		--directory="$(dirname "${mpfr_directory}")" \
		--extract \
		--file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${mpc_tarball}"
	
	tar \
		--directory="$(dirname "${mpc_directory}")" \
		--extract \
		--file="${mpc_tarball}"
fi

if ! [ -f "${gcc_tarball}" ]; then
	curl \
		--url 'https://github.com/gcc-mirror/gcc/archive/refs/heads/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${gcc_tarball}"
	
	tar \
		--directory="$(dirname "${gcc_directory}")" \
		--extract \
		--file="${gcc_tarball}"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Disable-libfunc-support-for-hppa-unknown-netbsd.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Disable-fenv.h-support.patch"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Fix-libgcc-build-on-arm.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Change-the-default-language-version-for-C-compilatio.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wimplicit-int-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wint-conversion-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-GCC-change-about-turning-Wimplicit-function-d.patch"
fi

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"
rm --force --recursive ./*

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"
rm --force --recursive ./*

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"
rm --force --recursive ./*

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

for triplet in "${triplets[@]}"; do
	
	setup_binutils "${triplet}"
	
	[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"
	
	cd "${binutils_directory}/build"
	rm --force --recursive ./*
	
	../configure \
		--host="${CROSS_COMPILE_TRIPLET}" \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld \
		--enable-lto \
		--disable-gprofng \
		--with-static-standard-libraries \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		LDFLAGS="${linkflags}"
	
	make all --jobs
	make install
	
	cd "$(mktemp --directory)"
	
	declare sysroot_url="https://github.com/AmanoTeam/netbsd-sysroot/releases/latest/download/${triplet}.tar.xz"
	declare sysroot_file="${PWD}/${triplet}.tar.xz"
	declare sysroot_directory="${PWD}/${triplet}"
	
	curl \
		--url "${sysroot_url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${sysroot_file}"
	
	tar \
		--extract \
		--file="${sysroot_file}"
	
	cp --recursive "${sysroot_directory}" "${toolchain_directory}"
	
	rm --force --recursive ./*
	
	[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"
	
	cd "${gcc_directory}/build"
	rm --force --recursive ./*
	
	declare extra_configure_flags=''
	
	if [ "${triplet}" != 'hppa-unknown-netbsd' ]; then
		extra_configure_flags+='--enable-gnu-unique-object '
	fi
	
	if [ "${triplet}" = 'mips-unknown-netbsd' ]; then
		extra_configure_flags+='--with-float=soft '
	fi
	
	declare CFLAGS_FOR_TARGET="${optflags} ${linkflags}"
	declare CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}"
	
	if [ "${triplet}" = 'shle-unknown-netbsdelf' ]; then
		CXXFLAGS_FOR_TARGET+=' -include sh3/fenv.h'
	fi
	
	../configure \
		--host="${CROSS_COMPILE_TRIPLET}" \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style='sysv' \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-bugurl='https://github.com/AmanoTeam/Dakini/issues' \
		--with-gcc-major-version-only \
		--with-pkgversion="Dakini v0.7-${revision}" \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-native-system-header-dir='/include' \
		--enable-__cxa_atexit \
		--enable-cet='auto' \
		--enable-checking='release' \
		--enable-clocale='gnu' \
		--enable-default-ssp \
		--enable-gnu-indirect-function \
		--enable-libstdcxx-backtrace \
		--enable-link-serialization='1' \
		--enable-linker-build-id \
		--enable-lto \
		--enable-shared \
		--enable-threads='posix' \
		--enable-languages='c,c++' \
		--enable-libssp \
		--enable-ld \
		--enable-gold \
		--disable-plugin \
		--disable-libsanitizer \
		--disable-fixincludes \
		--disable-multilib \
		--disable-libstdcxx-pch \
		--disable-werror \
		--disable-bootstrap \
		--disable-nls \
		--without-headers \
		${extra_configure_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		LDFLAGS="${linkflags}"
	
	LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make \
		CFLAGS_FOR_TARGET="${CFLAGS_FOR_TARGET}" \
		CXXFLAGS_FOR_TARGET="${CXXFLAGS_FOR_TARGET}" \
		all --jobs="${max_jobs}"
	make install
	
	rm --recursive "${toolchain_directory}/share"
	
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
	
	# Strip debug symbols from shared libraries
	while read name; do
		name="$(realpath "${name}")"
		
		if [[ "$(file --brief --mime-type "${name}")" != 'application/x-sharedlib' ]]; then
			continue
		fi
		
		if (( is_native )); then
			"${toolchain_directory}/bin/${triplet}-strip" "${name}"
		else
			"${DAKINI_HOME}/bin/${triplet}-strip" "${name}"
		fi
	done <<< "$(find "${toolchain_directory}/${triplet}/lib" -wholename '*.so')"
	
	# Fix some libraries not being found during linkage
	if [ "${triplet}" = 'shle-unknown-netbsdelf' ]; then
		cd "${toolchain_directory}/${triplet}/lib"
		
		for name in $(ls '!m3'); do
			if ! [ -f "./${name}" ]; then
				ln --symbolic './!m3/'"${name}" "./${name}"
			fi
		done
	fi
done

mkdir --parent "${share_directory}"

cp --recursive "${workdir}/tools/dev/"* "${share_directory}"
