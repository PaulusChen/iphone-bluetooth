#!/bin/bash

function err {
	echo $1
	exit 
}  

Flavor=Debug

rm -rf build/$Flavor build/CurrentFlavor || err "Cannot clean the work dir"

Bins=`pwd`/build/$Flavor/bin

mkdir -p $Bins || err "Cannot create work dirs"

mkdir -p build/CurrentFlavor/bin || err "Cannot create work dirs-2"

xcodebuild -target Aggregate1 -configuration $Flavor clean || err "Clean failed!"

xcodebuild -target Aggregate1 -configuration $Flavor || err "Build failed!"

cp ../btGpsClient/build/$Flavor-iphoneos/btGpsClient.app/btGpsClient $Bins/ || err "cp1 fail"
cp ../btGpsServer/build/$Flavor-iphoneos/btGpsServer.app/btGpsServer $Bins/ || err "cp2 fail"
cp ../btGpsServer/build/$Flavor-iphoneos/btGpsServer.app/com.msftguy.btgpsserver.plist $Bins/ || err "cp3 fail" 
cp ../btserver-inject/build/$Flavor-iphoneos/btserver-inject.app/btserver-inject $Bins/btserver-inject.dylib || err "cp4 fail"
cp ../locationd-inject/build/$Flavor-iphoneos/locationd-inject.app/locationd-inject $Bins/locationd-inject.dylib || err "cp5 fail"

ln -s $Bins/* build/CurrentFlavor/bin || err "Failed to create CurrentFlavor symlinks"

Debdir=`pwd`/build/$Flavor/deb

cp -LR deb $Debdir || err "Failed to collect deb contents"

find . -name '.svn' -or -name '.DS_Store' -print0 | xargs -0 rm -rf || err "Failed to clean up deb dir"


sudo chown -R root:wheel $Debdir || err "Failed to chown the deb dir"
sudo chmod -R 755 $Debdir || err "Failed to chmod the deb dir"
dpkg-deb -b $Debdir build/$Flavor/out.deb  || err "Deb creation failed"
sudo chown -R $USER $Debdir || err "Failed to restore deb dir owner"

echo BUILD SCRIPT FINISHED OK
