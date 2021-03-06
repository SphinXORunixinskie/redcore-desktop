# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit eutils flag-o-matic multilib-minimal portability toolchain-funcs unpacker

NV_URI="http://http.download.nvidia.com/XFree86/"
AMD64_NV_PACKAGE="NVIDIA-Linux-x86_64-${PV}"

DESCRIPTION="NVIDIA Accelerated Graphics Driver"
HOMEPAGE="http://www.nvidia.com/ http://www.nvidia.com/Download/Find.aspx"
SRC_URI="amd64? ( ${NV_URI}Linux-x86_64/${PV}/${AMD64_NV_PACKAGE}.run )"

LICENSE="GPL-2 NVIDIA-r2"
SLOT="0/${PV}"
KEYWORDS="-* amd64"
RESTRICT="bindist mirror"
EMULTILIB_PKG="true"

IUSE="acpi compat +dkms multilib +tools wayland +X"

COMMON="
	app-eselect/eselect-opencl
	X? (
		>=app-eselect/eselect-opengl-1.0.9
		app-misc/pax-utils
	)"
DEPEND="
	${COMMON}
	virtual/linux-sources"
PDEPEND="
	tools? ( x11-misc/nvidia-settings )"
RDEPEND="
	${COMMON}
	acpi? ( sys-power/acpid )
	dkms? ( ~sys-kernel/${PN}-dkms-${PV} )
	wayland? ( dev-libs/wayland[${MULTILIB_USEDEP}] )
	X? (
		<x11-base/xorg-server-1.19.99:=
		>=x11-libs/libX11-1.6.2[${MULTILIB_USEDEP}]
		>=x11-libs/libXext-1.3.2[${MULTILIB_USEDEP}]
		>=x11-libs/libvdpau-1.0[${MULTILIB_USEDEP}]
		sys-libs/zlib[${MULTILIB_USEDEP}]
	)
"

QA_PREBUILT="opt/* usr/lib*"

S=${WORKDIR}/

pkg_setup() {
	export DISTCC_DISABLE=1
	export CCACHE_DISABLE=1

	NV_DOC="${S}"
	NV_OBJ="${S}"
	NV_SRC="${S}/kernel"
	NV_MAN="${S}"
	NV_X11="${S}"
	NV_SOVER=${PV}
}

src_prepare() {
	default
	local man_file
	for man_file in "${NV_MAN}"/*1.gz; do
		gunzip $man_file || die
	done

	if ! [ -f nvidia_icd.json ]; then
		cp nvidia_icd.json.template nvidia_icd.json || die
		sed -i -e 's:__NV_VK_ICD__:libGLX_nvidia.so.0:g' nvidia_icd.json || die
	fi
}

# Install nvidia library:
# the first parameter is the library to install
# the second parameter is the provided soversion
# the third parameter is the target directory if it is not /usr/lib
donvidia() {
	# Full path to library
	nv_LIB="${1}"

	# SOVER to use
	nv_SOVER="$(scanelf -qF'%S#F' ${nv_LIB})"

	# Where to install
	nv_DEST="${2}"

	# Get just the library name
	nv_LIBNAME=$(basename "${nv_LIB}")

	if [[ "${nv_DEST}" ]]; then
		exeinto ${nv_DEST}
		action="doexe"
	else
		nv_DEST="/usr/$(get_libdir)"
		action="dolib.so"
	fi

	# Install the library
	${action} ${nv_LIB} || die "failed to install ${nv_LIBNAME}"

	# If the library has a SONAME and SONAME does not match the library name,
	# then we need to create a symlink
	if [[ ${nv_SOVER} ]] && ! [[ "${nv_SOVER}" = "${nv_LIBNAME}" ]]; then
		dosym ${nv_LIBNAME} ${nv_DEST}/${nv_SOVER} \
			|| die "failed to create ${nv_DEST}/${nv_SOVER} symlink"
	fi

	dosym ${nv_LIBNAME} ${nv_DEST}/${nv_LIBNAME/.so*/.so} \
		|| die "failed to create ${nv_LIBNAME/.so*/.so} symlink"
}

src_install() {
	# Xorg DDX && GLX, GLVND, Vulkan ICD
	if use X; then
		insinto /usr/$(get_libdir)/xorg/modules/drivers
		doins ${NV_X11}/nvidia_drv.so

		donvidia ${NV_X11}/libglx.so.${NV_SOVER} \
			/usr/$(get_libdir)/opengl/nvidia/extensions

		if has_version '>=x11-base/xorg-server-1.16'; then
			insinto /usr/share/X11/xorg.conf.d
			newins {,50-}nvidia-drm-outputclass.conf
		fi

		insinto /usr/share/glvnd/egl_vendor.d
		doins ${NV_X11}/10_nvidia.json

		insinto /etc/vulkan/icd.d
		doins ${NV_X11}/nvidia_icd.json
	fi

	# Wayland
	if use wayland; then
		insinto /usr/share/egl/egl_external_platform.d
		doins ${NV_X11}/10_nvidia_wayland.json
	fi

	# NVIDIA kernel <-> userspace driver config lib
	donvidia ${NV_OBJ}/libnvidia-cfg.so.${NV_SOVER}

	# NVIDIA framebuffer capture library
	donvidia ${NV_OBJ}/libnvidia-fbc.so.${NV_SOVER}

	# NVIDIA video encode/decode <-> CUDA
	donvidia ${NV_OBJ}/libnvcuvid.so.${NV_SOVER}
	donvidia ${NV_OBJ}/libnvidia-encode.so.${NV_SOVER}

	# OpenCL ICD for NVIDIA
	insinto /etc/OpenCL/vendors
	doins ${NV_OBJ}/nvidia.icd

	# Helper Apps
	exeinto /opt/bin/

	if use X; then
		doexe ${NV_OBJ}/nvidia-xconfig
	fi

	doexe ${NV_OBJ}/nvidia-cuda-mps-control
	doexe ${NV_OBJ}/nvidia-cuda-mps-server
	doexe ${NV_OBJ}/nvidia-debugdump
	doexe ${NV_OBJ}/nvidia-persistenced
	doexe ${NV_OBJ}/nvidia-smi
	dobin ${NV_OBJ}/nvidia-bug-report.sh

	# install nvidia-modprobe setuid and symlink in /usr/bin (bug #505092)
	doexe ${NV_OBJ}/nvidia-modprobe
	fowners root:video /opt/bin/nvidia-modprobe
	fperms 4710 /opt/bin/nvidia-modprobe
	dosym /{opt,usr}/bin/nvidia-modprobe

	# init
	newinitd "${FILESDIR}/nvidia-smi.init" nvidia-smi
	newconfd "${FILESDIR}/nvidia-persistenced.conf" nvidia-persistenced
	newinitd "${FILESDIR}/nvidia-persistenced.init" nvidia-persistenced

	# manpages
	if use X ; then
		doman "${NV_MAN}"/nvidia-xconfig.1
	fi

	doman "${NV_MAN}"/nvidia-smi.1
	doman "${NV_MAN}"/nvidia-cuda-mps-control.1
	doman "${NV_MAN}"/nvidia-modprobe.1
	doman "${NV_MAN}"/nvidia-persistenced.1

	# docs
	newdoc "${NV_DOC}/README.txt" README
	dodoc "${NV_DOC}/NVIDIA_Changelog"
	docinto html
	dodoc -r ${NV_DOC}/html/*

	if has_multilib_profile && use multilib; then
		local OABI=${ABI}
		for ABI in $(get_install_abis); do
			src_install-libs
		done
		ABI=${OABI}
		unset OABI
	else
		src_install-libs
	fi

	is_final_abi || die "failed to iterate through all ABIs"
}

src_install-libs() {
	local inslibdir=$(get_libdir)
	local GL_ROOT="/usr/$(get_libdir)/opengl/nvidia/lib"
	local CL_ROOT="/usr/$(get_libdir)/OpenCL/vendors/nvidia"
	local nv_libdir="${NV_OBJ}"

	if  has_multilib_profile && [[ ${ABI} == "x86" ]]; then
		nv_libdir="${NV_OBJ}"/32
	fi

	if use X; then
		NV_GLX_LIBRARIES=(
			"libEGL.so.$(usex compat ${NV_SOVER} 1) ${GL_ROOT}"
			"libEGL_nvidia.so.${NV_SOVER} ${GL_ROOT}"
			"libGL.so.$(usex compat ${NV_SOVER} 1.0.0) ${GL_ROOT}"
			"libGLESv1_CM.so.1 ${GL_ROOT}"
			"libGLESv1_CM_nvidia.so.${NV_SOVER} ${GL_ROOT}"
			"libGLESv2.so.2 ${GL_ROOT}"
			"libGLESv2_nvidia.so.${NV_SOVER} ${GL_ROOT}"
			"libGLX.so.0 ${GL_ROOT}"
			"libGLX_nvidia.so.${NV_SOVER} ${GL_ROOT}"
			"libGLdispatch.so.0 ${GL_ROOT}"
			"libOpenCL.so.1.0.0 ${CL_ROOT}"
			"libOpenGL.so.0 ${GL_ROOT}"
			"libcuda.so.${NV_SOVER}"
			"libnvcuvid.so.${NV_SOVER}"
			"libnvidia-compiler.so.${NV_SOVER}"
			"libnvidia-eglcore.so.${NV_SOVER}"
			"libnvidia-encode.so.${NV_SOVER}"
			"libnvidia-fatbinaryloader.so.${NV_SOVER}"
			"libnvidia-fbc.so.${NV_SOVER}"
			"libnvidia-glcore.so.${NV_SOVER}"
			"libnvidia-glsi.so.${NV_SOVER}"
			"libnvidia-ifr.so.${NV_SOVER}"
			"libnvidia-opencl.so.${NV_SOVER}"
			"libnvidia-ptxjitcompiler.so.${NV_SOVER}"
			"libvdpau_nvidia.so.${NV_SOVER}"
		)

		if use wayland && has_multilib_profile && [[ ${ABI} == "amd64" ]];
		then
			NV_GLX_LIBRARIES+=(
				"libnvidia-egl-wayland.so.1.0.1"
			)
		fi

		if has_multilib_profile && [[ ${ABI} == "amd64" ]];
		then
			NV_GLX_LIBRARIES+=(
				"libnvidia-wfb.so.${NV_SOVER}"
			)
		fi

		NV_GLX_LIBRARIES+=(
			"libnvidia-ml.so.${NV_SOVER}"
			"tls/libnvidia-tls.so.${NV_SOVER}"
		)

		for NV_LIB in "${NV_GLX_LIBRARIES[@]}"; do
			donvidia "${nv_libdir}"/${NV_LIB}
		done
	fi
}

pkg_preinst() {
	if [ -d "${ROOT}"/usr/lib/opengl/nvidia ]; then
		rm -rf "${ROOT}"/usr/lib/opengl/nvidia/*
	fi

	if [ -e "${ROOT}"/etc/env.d/09nvidia ]; then
		rm -f "${ROOT}"/etc/env.d/09nvidia
	fi
}

pkg_postinst() {
	if use X; then
		"${ROOT}"/usr/bin/eselect opengl set --use-old nvidia
	else
		elog "You have selected to not install the X.org driver. Along with"
		elog "this the OpenGL libraries and VDPAU libraries were not"
		elog "installed. Additionally, once the driver is loaded your card"
		elog "and fan will run at max speed which may not be desirable."
		elog "Use the 'nvidia-smi' init script to have your card and fan"
		elog "speed scale appropriately."
		elog
	fi

	"${ROOT}"/usr/bin/eselect opencl set --use-old nvidia
}

pkg_prerm() {
	if use X; then
		"${ROOT}"/usr/bin/eselect opengl set --use-old xorg-x11
	fi
}

pkg_postrm() {
	if use X; then
		"${ROOT}"/usr/bin/eselect opengl set --use-old xorg-x11
	fi
}
