
#ifdef SAFE_MODE_SUPPORT 

/*
 *  safe.cpp
 *  bbinj
 *
 *  Created by msftguy on 6/17/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "safe.h"

#include <unistd.h>
#include <pthread.h>

#include "logging.h"

static bool safe_checkOsVer()
{
	//TODO
	return true;
}

static bool safe_checkBbVer()
{
	//TODO
	return true;
}

static bool safe_sanityChecksPass() 
{
	return safe_checkOsVer() && safe_checkBbVer();
}

static bool safe_firstRun();

static bool safe_lastRunOk();

bool safe_canRun()
{
	if (!safe_sanityChecksPass())
		return false;
	return safe_firstRun() || safe_lastRunOk();
}

static bool safe_pathToConfig(char* buf, size_t size)
{
	const char filename[] ="/Library/Preferences/com.msftguy.btsrvinject_watchdog.plist";
	const char* homedir = getenv("HOME");
	return snprintf(buf, size, "%s%s", homedir, filename) > 0;
}

static const NSString* keyLastBoot = @"lastBootTime";
static const NSString* keyLastStart = @"lastStartTime";
static const NSString* keyLastGoodStart = @"lastGoodStartTime";

static NSString* g_configFile = NULL;

static bool safe_ensureConfigPath()
{
	if (g_configFile != NULL) {
		return true;
	}
	{
		static char configFile[BUFSIZ] = "";
		if (!safe_pathToConfig(configFile, sizeof(configFile))) {
			return false;
		}
		g_configFile = [[NSString alloc] initWithBytes:configFile length:strlen(configFile) encoding:NSASCIIStringEncoding];
	}
	return true;
}

static void safe_ensureParseConfig(NSMutableDictionary* configDict = NULL);

static NSMutableDictionary* safe_loadConfig()
{
	if(!safe_ensureConfigPath())
		return NULL;
	NSMutableDictionary* configDict = [[NSMutableDictionary alloc] initWithContentsOfFile:g_configFile];
	if (configDict == nil) {
		configDict = [[NSMutableDictionary alloc] init];
	}
	if (configDict != nil) {
		safe_ensureParseConfig(configDict);
	}
	return configDict;
}

static bool safe_setValue(NSString* key, id value)
{
	bool result = false;
	NSMutableDictionary* configDict = safe_loadConfig();
	if (configDict != nil) {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		[configDict setValue:value forKey:key];
		result = [configDict writeToFile:g_configFile atomically:YES];
		[configDict release];
		[pool drain];
	}
	return result;
}

static bool safe_setTimeValue(NSString* key)
{
	NSDate* now = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
	return safe_setValue(key, now);
	[now release];
}


static bool g_firstRun = false;

static bool g_lastRunOk = false;

static void safe_ensureParseConfig(NSMutableDictionary* configDict)
{
	static bool s_fParsed = false;
	if (!s_fParsed) {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		if (configDict == nil) {
			NSMutableDictionary* dic = safe_loadConfig();
			if (dic) {
				[dic release];
			}
		} else {
			s_fParsed = true;
			NSDate* lastBoot = [configDict valueForKey:keyLastBoot];
			NSDate* lastGoodStart = [configDict valueForKey:keyLastGoodStart];
			g_lastRunOk = 
				lastBoot != nil &&
				lastGoodStart != nil &&
				[lastGoodStart compare:lastBoot] != NSOrderedAscending; 
			g_firstRun = lastBoot == nil;
		}
		[pool drain];
	}	
}

static bool safe_firstRun()
{
	safe_ensureParseConfig();
	return g_firstRun;
}

static bool safe_lastRunOk()
{
	safe_ensureParseConfig();
	return g_lastRunOk;
}

static void* safe_delayedSuccessThreadProc(void* threadArg)
{
	const int SUCCESS_REPORTING_DELAY = 5 * 60; // 5 minutes
	const int SUCCESS_REPORTING_PING_INTERVAL = 5;
	for (int i = 0; i < SUCCESS_REPORTING_DELAY; i += SUCCESS_REPORTING_PING_INTERVAL) {
		log_progress("safe_delayedSuccessThreadProc/waiting: %i", i); 
		
		sleep(SUCCESS_REPORTING_PING_INTERVAL);
	}
	
	log_progress("safe_delayedSuccessThreadProc/saving SUCCESS tv"); 
	safe_setTimeValue(keyLastGoodStart);
	return NULL;
}

static void safe_startDelayedSuccessThreadProc()
{
	pthread_t delayedSuccessThread = NULL; 
	pthread_create(&delayedSuccessThread, NULL, safe_delayedSuccessThreadProc, NULL);
}

//call as soon as dylib loads into CommCenter
bool safe_reportBoot()
{
	log_progress("safe_reportBoot"); 
	return safe_setTimeValue(keyLastBoot);
}

//call as soon as bb injection starts
bool safe_reportStart()
{
	log_progress("safe_reportStart"); 
	return safe_setTimeValue(keyLastStart);
}

//call after bb injection succeeds
bool safe_reportStartSuccess()
{
	log_progress("safe_reportStartSuccess"); 
	pthread_once_t once_control = PTHREAD_ONCE_INIT;
	return 0 == pthread_once(&once_control, safe_startDelayedSuccessThreadProc);
}


#endif // SAFE_MODE_SUPPORT 
