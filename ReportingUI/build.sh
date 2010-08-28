#!/bin/bash

function err {
	echo $1
	exit 
}  

Flavor=Debug

rm -rf build/$Flavor build/CurrentFlavor || err "Cannot clean the work dir"

mkdir -p build/CurrentFlavor build/$Flavor/deb build/$Flavor/ftp

xcodebuild -target ReportingUI -configuration $Flavor clean || err "Clean failed!"

xcodebuild -target ReportingUI -configuration $Flavor || err "Build failed!"

cp -R build/$Flavor-iphoneos/ReportingUI.app build/CurrentFlavor || err "copy failed"

Debdir=`pwd`/build/$Flavor/deb

cp -LR deb/ $Debdir/ || err "Failed to collect deb contents"

find $Debdir  \( -name '.svn' -or -name '.DS_Store' \)  -print0 | xargs -0 rm -rf || err "Failed to clean up deb dir"

sudo chown -R root:wheel $Debdir || err "Failed to chown the deb dir"
sudo chmod -R 755 $Debdir || err "Failed to chmod the deb dir"
dpkg-deb -b $Debdir build/$Flavor/ftp/ReportingUI.deb  || err "Deb creation failed"
sudo chown -R $USER $Debdir || err "Failed to restore deb dir owner"

pushd build/$Flavor/ftp

dpkg-scanpackages . /dev/null > Packages || err "Failed to create package index"

bzip2 Packages || err "Failed to compress package index"

popd

test -d /Volumes/upload && { 
	rm -rf /Volumes/upload/ftp
	cp -R build/$Flavor/ftp /Volumes/upload
}

echo BUILD SCRIPT FINISHED OK
