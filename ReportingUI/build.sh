#!/bin/bash

function err {
	echo $1
	exit 
}  

Flavor=Debug

if [ -n "$1" ]; then
	Version=$1
	agvtool new-version -all $Version
else
	Version=`agvtool what-version -terse`
fi

rm -rf build/$Flavor build/CurrentFlavor || err "Cannot clean the work dir"

mkdir -p build/CurrentFlavor build/$Flavor/deb build/$Flavor/ftp

xcodebuild -target ReportingUI -configuration $Flavor clean || err "ReportingUI clean failed!"

xcodebuild -target ReportingUI -configuration $Flavor || err "ReportingUI build failed!"

pushd ../btserver-inject

xcodebuild -target btserver-inject -configuration $Flavor-logging clean || err "BTServer-inject clean failed!"

xcodebuild -target btserver-inject -configuration $Flavor-logging || err "BTServer-inject build failed!"

popd

cp -R build/$Flavor-iphoneos/ReportingUI.app build/CurrentFlavor || err "ReportingUI copy failed"
cp ../btserver-inject/build/$Flavor-logging-iphoneos/btserver-inject.app/btserver-inject build/CurrentFlavor/btserver-inject-logging.dylib || err "ReportingUI copy failed"

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

ArchivePath=Archive/$Version
svn info $ArchivePath &>/dev/null && err "Bump the version from $Version first"
mkdir -p $ArchivePath
cp -R build/$Flavor/ftp/ $ArchivePath/
cp -R build/Debug-iphoneos/ReportingUI.app.dSYM $ArchivePath


test -d /Volumes/upload && { 
	cp -R build/$Flavor/ftp /Volumes/upload/ftp
}

echo BUILD SCRIPT FINISHED OK
