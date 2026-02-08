#!/bin/bash -e

# SPDX-FileCopyrightText: 2009 Robert Nelson <robertcnelson@gmail.com>
#
# SPDX-License-Identifier: MIT

# Split out, so build_kernel.sh and build_deb.sh can share..

shopt -s nullglob

. ${DIR}/version.sh
if [ -f ${DIR}/system.sh ] ; then
	. ${DIR}/system.sh
fi
git_bin=$(which git)
#git hard requirements:
#git: --no-edit

git="${git_bin} am"
#git_patchset=""
#git_opts

if [ "${RUN_BISECT}" ] ; then
	git="${git_bin} apply"
fi

echo "Starting patch.sh"

git_add () {
	${git_bin} add .
	${git_bin} commit -a -m 'testing patchset'
}

start_cleanup () {
	git="${git_bin} am --whitespace=fix"
}

cleanup () {
	if [ "${number}" ] ; then
		if [ "x${wdir}" = "x" ] ; then
			${git_bin} format-patch -${number} -o ${DIR}/patches/
		else
			if [ ! -d ${DIR}/patches/${wdir}/ ] ; then
				mkdir -p ${DIR}/patches/${wdir}/
			fi
			${git_bin} format-patch -${number} -o ${DIR}/patches/${wdir}/
			unset wdir
		fi
	fi
	exit 2
}

dir () {
	wdir="$1"
	if [ -d "${DIR}/patches/$wdir" ]; then
		echo "dir: $wdir"

		if [ "x${regenerate}" = "xenable" ] ; then
			start_cleanup
		fi

		number=
		for p in "${DIR}/patches/$wdir/"*.patch; do
			${git} "$p"
			number=$(( $number + 1 ))
		done

		if [ "x${regenerate}" = "xenable" ] ; then
			cleanup
		fi
	fi
	unset wdir
}

cherrypick () {
	if [ ! -d ../patches/${cherrypick_dir} ] ; then
		mkdir -p ../patches/${cherrypick_dir}
	fi
	${git_bin} format-patch -1 ${SHA} --start-number ${num} -o ../patches/${cherrypick_dir}
	num=$(($num+1))
}

external_git () {
	git_tag=""
	echo "pulling: ${git_tag}"
	${git_bin} pull --no-edit ${git_patchset} ${git_tag}
	${git_bin} describe
}

rt_cleanup () {
	echo "rt: needs fixup"
	exit 2
}

rt () {
	#rt_enable="enable"
	if [ "x${rt_enable}" = "xenable" ] ; then
		rt_patch="${KERNEL_REL}${kernel_rt}"

		#${git_bin} revert --no-edit xyz

		#regenerate="enable"
		if [ "x${regenerate}" = "xenable" ] ; then
			wget -c https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_REL}/older/patch-${rt_patch}.patch.xz
			xzcat patch-${rt_patch}.patch.xz | patch -p1 || rt_cleanup
			rm -f patch-${rt_patch}.patch.xz
			rm -f localversion-rt
			${git_bin} add .
			${git_bin} commit -a -m 'merge: CONFIG_PREEMPT_RT Patch Set' -m "patch-${rt_patch}.patch.xz" -s
			${git_bin} format-patch -1 -o ../patches/external/rt/
			#echo "RT: patch-${rt_patch}.patch.xz" > ../patches/external/git/RT

			exit 2
		fi
		dir 'external/rt'
	fi
}

local_patch () {
	echo "dir: dir"
	${git} "${DIR}/patches/dir/0001-patch.patch"
}

#external_git
rt
#local_patch

pre_backports () {
	echo "dir: backports/${subsystem}"

	cd ~/linux-src/
	${git_bin} pull --no-edit https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux.git master
	${git_bin} pull --no-edit https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux.git master --tags
	${git_bin} pull --no-edit https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux.git master --tags
	if [ ! "x${backport_tag}" = "x" ] ; then
		echo "${git_bin} checkout ${backport_tag} -f"
		${git_bin} checkout ${backport_tag} -f
	fi
	cd -
}

post_backports () {
	if [ ! "x${backport_tag}" = "x" ] ; then
		cd ~/linux-src/
		${git_bin} checkout master -f
		cd -
	fi

	${git_bin} add .
	${git_bin} commit -a -m "backports: ${subsystem}: from: linux.git" -m "Reference: ${backport_tag}" -s
	if [ ! -d ../patches/backports/${subsystem}/ ] ; then
		mkdir -p ../patches/backports/${subsystem}/
	fi
	${git_bin} format-patch -1 -o ../patches/backports/${subsystem}/
	exit 2
}

patch_backports () {
	echo "dir: backports/${subsystem}"
	${git} "${DIR}/patches/backports/${subsystem}/0001-backports-${subsystem}-from-linux.git.patch"
}

pre_rpibackports () {
	echo "dir: backports/${subsystem}"

	cd ~/linux-rpi/
	${git_bin} fetch --tags
	if [ ! "x${backport_tag}" = "x" ] ; then
		echo "${git_bin} checkout ${backport_tag} -f"
		${git_bin} checkout ${backport_tag} -f
	fi
	cd -
}

post_rpibackports () {
	if [ ! "x${backport_tag}" = "x" ] ; then
		cd ~/linux-rpi/
		${git_bin} checkout master -f
		cd -
	fi

	${git_bin} add .
	${git_bin} commit -a -m "backports: ${subsystem}: from: linux.git" -m "Reference: ${backport_tag}" -s
	if [ ! -d ../patches/backports/${subsystem}/ ] ; then
		mkdir -p ../patches/backports/${subsystem}/
	fi
	${git_bin} format-patch -1 -o ../patches/backports/${subsystem}/
	exit 2
}

backports () {
	backport_tag="v4.x-y"

	subsystem="xyz"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		pre_backports

		mkdir -p ./x/
		cp -v ~/linux-src/x/* ./x/

		post_backports
	else
		patch_backports
	fi
}

###
#backports

packaging () {
	${git} "${DIR}/patches/backports/bindeb-pkg/0002-builddeb-Install-our-dtbs-under-boot-dtbs-version.patch"
}

packaging
echo "patch.sh ran successfully"
#
