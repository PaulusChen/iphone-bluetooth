#!/bin/sh

# ReportingUI.sh
# ReportingUI
#
# Created by svp on 8/24/10.
# Copyright 2010 __MyCompanyName__. All rights reserved.

scriptName=$0

# everything before last '.'
appName=${scriptName%.*}

exec "$appName" "$@"