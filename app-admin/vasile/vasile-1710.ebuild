# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

inherit eutils git-r3

DESCRIPTION="Versatile Advanced Script for ISO and Latest Enchantments"
HOMEPAGE="http://redcorelinux.org"

EGIT_BRANCH="master"
EGIT_REPO_URI="https://gitlab.com/redcore/vasile.git"
EGIT_COMMIT="c79f7cb3dd4159357e923906c75d0a0c86f17534"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64"
IUSE=""

DEPEND="sys-apps/gentoo-functions"
RDEPEND="${DEPEND}
	dev-libs/libisoburn
	sys-boot/grub:2
	sys-kernel/dkms
	sys-fs/mtools
	sys-fs/squashfs-tools"

src_install() {
	dodir /usr/bin
	exeinto /usr/bin
	doexe ${S}/${PN}
	dodir /usr/$(get_libdir)/${PN}
	insinto /usr/$(get_libdir)/${PN}
	doins ${S}/libvasile
}

pkg_postinst() {
	sisyphus update
	mkdir -p /usr/ports/gentoo/packages
	mkdir -p /usr/ports/gentoo/distfiles
	chown portage:portage /usr/ports/gentoo/distfiles
}
