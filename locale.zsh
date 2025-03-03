#!/bin/zsh

export LANG=C.UTF-8
export LC_CTYPE=C.UTF-8
export LC_ALL=C.UTF-8

function setlocale() {
	export LANG=C.UTF-8
	export LC_CTYPE=C.UTF-8
	export LC_ALL=C.UTF-8

	locale-gen C.UTF-8
	dpkg-reconfigure locales
}

if [ "$(locale -a | grep C.UTF-8)" = "" ]; then
	[ $EUID -eq 0 ] && setlocale || sudo setlocale
fi
