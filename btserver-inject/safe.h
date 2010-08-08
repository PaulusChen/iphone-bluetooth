/*
 *  safe.h
 *  bbinj
 *
 *  Created by msftguy on 6/17/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifdef SAFE_MODE_SUPPORT 

bool safe_canRun();

bool safe_reportBoot();

bool safe_reportStart();

bool safe_reportStartSuccess();

#else

inline bool safe_nothing() {return true;}

#define safe_canRun safe_nothing

#define safe_reportBoot safe_nothing

#define safe_reportStart safe_nothing

#define safe_reportStartSuccess safe_nothing

#endif