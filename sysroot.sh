#!/usr/bin/env bash

set -eu

declare -r workdir="${PWD}"
declare -r temporary_directory='/tmp/netbsd-sysroot'

declare -ra targets=(
	# 'hpcsh'
	# 'vax'
	# 'emips'
	# 'evbppc'
	# 'hppa'
	'amd64'
	'i386'
	# 'alpha'
	# 'sparc'
	# 'sparc64'
	'evbarm-aarch64'
	# 'evbarm-earmv7hf'
	# 'evbarm-earmv6hf'
)

[ -d "${temporary_directory}" ] || mkdir "${temporary_directory}"

cd "${temporary_directory}"

for target in "${targets[@]}"; do
	case "${target}" in
		amd64)
			declare triplet='x86_64-unknown-netbsd';;
		i386)
			declare triplet='i386-unknown-netbsdelf';;
		emips)
			declare triplet='mips-unknown-netbsd';;
		alpha)
			declare triplet='alpha-unknown-netbsd';;
		hppa)
			declare triplet='hppa-unknown-netbsd';;
		sparc)
			declare triplet='sparc-unknown-netbsdelf';;
		sparc64)
			declare triplet='sparc64-unknown-netbsd';;
		vax)
			declare triplet='vax-unknown-netbsdelf';;
		hpcsh)
			declare triplet='shle-unknown-netbsdelf';;
		evbppc)
			declare triplet='powerpc-unknown-netbsd';;
		evbarm-aarch64)
			declare triplet='aarch64-unknown-netbsd';;
		evbarm-earmv7hf)
			declare triplet='armv7-unknown-netbsdelf-eabihf';;
		evbarm-earmv6hf)
			declare triplet='armv6-unknown-netbsdelf-eabihf';;
	esac
	
	declare netbsd_version='10.1'
	
	declare url="https://ftp.netbsd.org/pub/NetBSD/NetBSD-${netbsd_version}/${target}/binary/sets"
	
	declare extension='.tar.xz'
	
	if [ "${target}" = 'i386' ]; then
		extension='.tgz'
	fi
	
	declare base_url="${url}/base${extension}"
	declare comp_url="${url}/comp${extension}"
	
	declare base_output="${temporary_directory}/$(basename "${base_url}")"
	declare comp_output="${temporary_directory}/$(basename "${comp_url}")"
	
	declare sysroot_directory="${workdir}/${triplet}"
	declare tarball_filename="${sysroot_directory}.tar.xz"
	
	[ -d "${sysroot_directory}" ] || mkdir "${sysroot_directory}"
	
	echo "- Generating sysroot for ${triplet}"
	
	if [ -f "${tarball_filename}" ]; then
		echo "+ Already exists. Skip"
		continue
	fi
	
	echo "- Fetching data from ${base_url}"
	
	curl \
		--url "${base_url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${base_output}"
	
	echo "- Unpacking ${base_output}"
	
	tar \
		--directory="${sysroot_directory}" \
		--strip=2 \
		--extract \
		--file="${base_output}" \
		'./usr/lib' \
		'./usr/include'
	
	tar \
		--directory="${sysroot_directory}" \
		--extract \
		--file="${base_output}" \
		'./lib'
	
	echo "- Fetching data from ${base_url}"
	
	curl \
		--url "${comp_url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${comp_output}"
	
	echo "- Unpacking ${comp_output}"
	
	tar \
		--directory="${sysroot_directory}" \
		--strip=2 \
		--extract \
		--file="${comp_output}" \
		'./usr/lib' \
		'./usr/include'
	
	# Update permissions
	while read name; do
		if [ -f "${name}" ]; then
			chmod 644 "${name}"
		elif [ -d "${name}" ]; then
			chmod 755 "${name}"
		fi
	done <<< "$(find "${sysroot_directory}/include" "${sysroot_directory}/lib")"
	
	echo "- Creating tarball at ${tarball_filename}"
	
	tar --directory="$(dirname "${sysroot_directory}")" --create --file=- "$(basename "${sysroot_directory}")" | xz --threads='0' --extreme --compress -9 --memlimit-compress='100%' > "${tarball_filename}"
	sha256sum "${tarball_filename}" | sed "s|$(dirname "${sysroot_directory}")/||" > "${tarball_filename}.sha256"
	
	rm --force --recursive "${sysroot_directory}"
	rm --force --recursive "${temporary_directory}/"*
done
