#!/bin/sh

# toggle_logging.sh
# ReportingUI
#
# Created by svp on 8/13/10.
# Copyright 2010 __MyCompanyName__. All rights reserved.


logging_marker="`dirname $0`/logging_enabled"

function restart_service {
	Plist=$1
	Process=$2
	launchctl unload $Plist &>/dev/null
	killall -s $Process &>/dev/null && { 
		killall $Process &>/dev/null
		sleep 1
		killall -9 $Process &>/dev/null
	}
	launchctl load $Plist &>/dev/null
}

function restart_btserver {
	restart_service /System/Library/LaunchDaemons/com.apple.BTServer.plist BTServer
}

function restart_roqybt4 {
	killall roqyBT4 &>/dev/null
	restart_service /System/Library/LaunchDaemons/com.roqyBT.roqyBluetooth4d.plist roqyBluetooth4d
}

function restart_roqybt {
	restart_service /Library/LaunchDaemons/com.iphone.roqyBT.plist roqyBluetooth
}

function enable_btserver_logging {
	Plist=/var/mobile/Library/Preferences/com.apple.MobileBluetooth.debug.plist
	
	plutil -create $Plist &>/dev/null
	plutil -key DiagnosticMode -value true -type bool $Plist &>/dev/null
	plutil -key DefaultLevel -value Debug -type string $Plist &>/dev/null
}

function disable_btserver_logging {
	Plist=/var/mobile/Library/Preferences/com.apple.MobileBluetooth.debug.plist

	plutil -create $Plist &>/dev/null
	plutil -rmkey DiagnosticMode $Plist &>/dev/null
	plutil -rmkey DefaultLevel $Plist &>/dev/null
}

function enable_roqybt_nmea_logging {
	if [ ! -f /var/mobile/Documents/roqyBT/Config.orig ]; then 
		touch /var/mobile/Documents/roqyBT/Config
		cp /var/mobile/Documents/roqyBT/Config /User/Documents/roqyBT/Config.orig
		printf "%s\nNMEA_log=1\n" `grep -v NMEA_log < /User/Documents/roqyBT/Config` > /User/Documents/roqyBT/Config
	fi
}

function restore_roqybt_nmea_logging {
	if [ -f /User/Documents/roqyBT/Config.orig ]; then 
		mv /User/Documents/roqyBT/Config.orig /User/Documents/roqyBT/Config
	fi
}

function enable_btserver_injection {
	Plist=/System/Library/LaunchDaemons/com.apple.BTServer.plist
	if [ -f $Plist.bak ]; then
		exit
	fi
	cp $Plist $Plist.bak
	plutil -rmkey EnvironmentVariables $Plist &>/dev/null
	plutil -key EnvironmentVariables -dict $Plist
	plutil -key EnvironmentVariables -key DYLD_INSERT_LIBRARIES -string /usr/lib/btserver-inject-logging.dylib $Plist
}

function restore_btserver_injection {
	Plist=/System/Library/LaunchDaemons/com.apple.BTServer.plist
	mv $Plist.bak $Plist &>/dev/null
	rm /tmp/btserver_filter_hci &>/dev/null
	rm /tmp/btserver_log_io &>/dev/null
}

function enable_logging {
	enable_roqybt_nmea_logging
	enable_btserver_logging

	restart_roqybt4
	restart_btserver
	restart_roqybt
	
	touch $logging_marker
}

function disable_logging {
	restore_btserver_injection
	restore_roqybt_nmea_logging
	disable_btserver_logging

	restart_roqybt4
	restart_btserver
	restart_roqybt
	
	rm $logging_marker &>/dev/null
}

test -z "$1" && { echo Need an argument: 0 to disable, 1 to enable; exit; }

fDisable=0
fEnable=0
fHci=0
fFilter=0

for ARG in "$@"
do
	if [ $ARG = 0 ] ; then 
		fDisable=1
	elif [ $ARG = 1 ] ; then 
		fEnable=1
	elif [ $ARG = hci ] ; then 
		fHci=1
	elif [ $ARG = filter ] ; then 
		fFilter=1
	fi
done

if [ $fDisable -ne 0 ]; then
	disable_logging
elif [ $fEnable -ne 0 ]; then
	if [ $fFilter -ne 0 ]; then
		touch /tmp/btserver_filter_hci
	fi
	if [ $fHci -ne 0 ]; then
		touch /tmp/btserver_log_io
	fi
	
	if [ $fHci -ne 0 -o $fFilter -ne 0 ]; then 
		enable_btserver_injection
	fi
	enable_logging
fi


