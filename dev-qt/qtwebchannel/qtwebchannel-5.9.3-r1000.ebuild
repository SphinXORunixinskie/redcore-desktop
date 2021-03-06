# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit qt5-build-r10000

DESCRIPTION="Qt5 module for integrating C++ and QML applications with HTML/JavaScript clients"

if [[ ${QT5_BUILD_TYPE} == release ]]; then
	KEYWORDS="amd64"
fi

IUSE="qml"

DEPEND="
	~dev-qt/qtcore-${PV}
	qml? ( ~dev-qt/qtdeclarative-${PV} )
"
RDEPEND="${DEPEND}"

src_prepare() {
	qt_use_disable_mod qml quick src/src.pro
	qt_use_disable_mod qml qml src/webchannel/webchannel.pro

	qt5-build-r10000_src_prepare
}
