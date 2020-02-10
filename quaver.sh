#!/bin/bash

here=$(pwd)
opensslurl="https://www.openssl.org/source/openssl-1.1.1d.tar.gz"
opensslchecksum=$(curl -s https://www.openssl.org/source/openssl-1.1.1d.tar.gz.sha256)
openssl=${opensslurl##*\/}
opensslconfigopts="--prefix=$here/openssl --openssldir=$here/openssl no-ssl2"
dotneturl="https://download.visualstudio.microsoft.com/download/pr/701502b0-f9a2-464f-9832-4e6ca3126a2a/62655f151db917025e9be8cc4b7c1ed9/dotnet-sdk-2.1.803-linux-x64.tar.gz"
dotnetchecksum="fcb46a4a0c99bf82b591bca2cd276e2d73b65e199f0d14c9cc48dcdf5fb2ffb0"
dotnet=${dotneturl##*\/}
makecmd="make -j$(nproc --all)"
quaverurl="https://github.com/Quaver/Quaver"
deps=(base-devel git libgdiplus alsa-plugins-pulseaudio)
unresolveddeps=""
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_ROOT=$here/dotnet
export PATH=$PATH:$here/dotnet
export PATH=$here/openssl/bin:$PATH
export LD_LIBRARY_PATH=$here/openssl/lib
export LC_ALL="en_US.UTF-8"
export LDFLAGS="-L$here/openssl/lib -Wl,-rpath,$here/openssl/lib"
export DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=0
export SSL_CERT_DI=/dev/null

echo "are you sure you want to start the install into the current directory? y/n "
read answer
if [[ $answer != y ]]; then exit; fi

broke() {
	echo "something broke: $1"
	exit 1
}

if [[ $(which wget 2>/dev/null) ]]; then
	getcmd="wget -q"
elif [[ $(which curl 2>/dev/null) ]]; then
	getcmd="curl -s -O"
else
	broke "no program found to download the required files, please install either curl or wget."
fi

[[ $(which sha256sum 2>/dev/null) ]] || broke "sha256sum not found"

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

echo "installing dependencies..."
elevatepriv "xbps-install $unresolveddeps"

buildopenssl() {
	echo "downloading openssl..."
	$getcmd $opensslurl
	echo "done"
	echo "verifying openssl checksum..."
	[[ $opensslchecksum = $(sha256sum $openssl 2>/dev/null | awk '{print $1}') ]] || broke "the checksum doesn't match, please remove the openssl archive and re-run the script." 
	echo "extracting openssl..."
	tar -xf $openssl
	rm $openssl
	cd ${openssl%%\.tar\.gz}
	./config $opensslconfigopts || broke "openssl configuration failed."
	$makecmd || broke "building openssl failed."
	make tests || broke "openssl tests failed."
	make install || broke "openssl installation failed."
	cd ..
	rm -r ${openssl%%\.tar\.gz}
}

downloaddotnet() {
	echo "downloading dotnet..."
	$getcmd $dotneturl
	echo "done"
	echo "verifying dotnet checksum..."
	[[ $dotnetchecksum = $(sha256sum $dotnet 2>/dev/null | awk '{print $1}') ]] || broke "the checksum doesn't match, please remove the openssl archive and re-run the script." 
	echo "extracting dotnet..."
	mkdir dotnet
	tar -C dotnet/ -xf $dotnet
	rm $dotnet
}

clonequaver() {	
	echo "cloning quaver..."
	git clone --recursive $quaverurl
	cd Quaver
	dotnet build || broke "building quaver failed."
	echo "quaver was successfully built! removing builddeps..."
	mv Quaver/bin/Debug/netcoreapp2.1 ../quaver
	cd ..
	rm -rf Quaver
}

makelaunchfile() {
	echo "creating launch script..."
	echo -e "#!/bin/bash\ncd \$(dirname \$(readlink -f \$0))\nhere=\$(pwd)\nexport DOTNET_CLI_TELEMETRY_OPTOUT=1\nexport DOTNET_ROOT=\$here/dotnet\nexport PATH=\$PATH:\$here/dotnet\nexport PATH=\$here/openssl/bin:\$PATH\nexport LD_LIBRARY_PATH=\$here/openssl/lib\nexport LC_ALL="en_US.UTF-8"\nexport LDFLAGS="-L\$here/openssl/lib -rpath,\$here/openssl/lib"\nexport DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=0\nexport SSL_CERT_DI=/dev/null\nsh quaver/quaver.sh" > launchquaver.sh
	chmod +x launchquaver.sh
	echo "launch script created!"
}

symlinklauncher() {
	echo "would you like to symlink launchquaver.sh to /usr/bin/quaver? y/n"
	read answer2
	if [[ $answer2 != y ]]; then
		exit
	fi
	elevatepriv "ln -s $(pwd)/launchquaver.sh /usr/bin/quaver"
}

buildopenssl
downloaddotnet
clonequaver
makelaunchfile
symlinklauncher
