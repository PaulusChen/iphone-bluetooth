/*
 *  hook_main.cpp
 *  bbinj
 *
 *  Created by msftguy on 6/16/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "hook_main.h"

#include <unistd.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

#include "substrate.h"
#include "impHookApi.h"

#include "logging.h"
#include "safe.h"
#include "fuzz.h"
//
//static ssize_t my_read(int fd, void* buf, size_t size) {
//	int result = read(fd, buf, size);
//	log_io(fd, "_read", buf, result > 0 ? result : 0, result);
//	return result;
//}
//
//static ssize_t my_write(int fd, const void* buf, size_t size) {
//	int result = write(fd, buf, size);
//	log_io(fd, "_write", buf, size, result);
//	return result;
//}
//
//void hook_read_write_ops()
//{
//	//FIXME: use correct module handle
//	void* hBS = dlopen("/usr/lib/blacksn0w.dylib", RTLD_GLOBAL);
//	NSLog(@"dlopen(blacksnow) = %p", hBS);
//
//	const mach_header* mh = NULL;
//
//	for (int i = 0; i < _dyld_image_count(); ++i) {
//		if (NULL != strcasestr(_dyld_get_image_name(i), "blacksn0w")) {
//			mh = _dyld_get_image_header(i);
//			NSLog(@"blacksn0w module found at %p", mh);
//			break;
//		}
//	}
//	if (mh == NULL) {
//		NSLog(@"blacksn0w module not found!!!");
//		return;
//	}
//	
//	uintptr_t* pReadImp = get_import_ptr(mh, "_read");
//	uintptr_t* pWriteImp = get_import_ptr(mh, "_write");
//	*pReadImp = (uintptr_t)my_read;
//	*pWriteImp = (uintptr_t)my_write;
//	NSLog(@"Blacksn0w IO hooked: r=%p w=%p", pReadImp, pWriteImp);
//}

void setup_hooks()
{
	safe_reportStart();
	if (!ensure_braille_service()) {
		log_progress("setup_hooks: ensure_braille_service failed!");
		return;
	} else {
		log_progress("setup_hooks: ensure_braille_service OK!");
	}
	safe_reportStartSuccess();
	

//	void* pAtHandler = NULL;
//	if (find_at_handler(&pAtHandler, (void**)&g_pingResponseXref)) {
//		log_progress("find_at_handler: %p; %p", pAtHandler, g_pingResponseXref);
//		at_cmd_handler_call_orig = *(at_cmd_handler_t*)pAtHandler;
//	}
}