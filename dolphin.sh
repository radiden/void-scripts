#!/bin/bash
here=`realpath $0`
here=`dirname $here`
threads=$(nproc --all)
progurl="https://github.com/dolphin-emu/dolphin"
deps=(base-devel qt5-devel qt5 cmake libevdev libevdev-devel)
unresolveddeps=""

elevatepriv() {
	sudo bash -c "$1"
}

resolvedeps() {
	if [[ ! $(xbps-query "$1") ]]; then
		unresolveddeps="$unresolveddeps$1 "	
	fi
}

for i in "${deps[@]}"; do
	resolvedeps "$i"
done

elevatepriv "xbps-install $unresolveddeps"

[[ ! -d dolphin ]] && git clone $progurl 
cd $here && cd dolphin
git pull

if [[ ! -d build ]]; then
	mkdir build
else
	rm -rf build && mkdir build
fi

cd build
cmake ..
make -j$threads
elevatepriv "make install"
