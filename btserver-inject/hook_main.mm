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

#include <sys/stat.h>

#include "substrate.h"
#include "impHookApi.h"

#include "logging.h"
#include "safe.h"
#include "fuzz.h"
#include "filter.h"

static BOOL g_logIo = NO;
static BOOL g_filterHci = NO;


static ssize_t my_read(int fd, void* buf, size_t size) {
	int result = read(fd, buf, size);
	if (g_logIo)  {
		log_io(fd, "_read", buf, result > 0 ? result : 0, result);
	}
	if (result > 0 && g_filterHci) {
		BOOL dirty = filter_read_h4_inplace(fd, (char*)buf, result);
		if (dirty) {
			log_io(fd, "_read_flt", buf, result > 0 ? result : 0, result);	
		}
	}
	return result;
}

static ssize_t my_write(int fd, const void* buf, size_t size) {
	int result = write(fd, buf, size);
	if (g_logIo) {
		log_io(fd, "_write", buf, size, result);
	}
	return result;
}

void hook_read_write_ops()
{
	const char* moduleName = "BTServer";
	const mach_header* mh = NULL;

	for (int i = 0; i < _dyld_image_count(); ++i) {
		if (NULL != strstr(_dyld_get_image_name(i), moduleName)) {
			mh = _dyld_get_image_header(i);
			log_progress("%s module found at %p", moduleName, mh);
			break;
		}
	}
	if (mh == NULL) {
		log_progress("%s module not found!!!", moduleName);
		return;
	}
	
	uintptr_t* pReadImp = get_import_ptr(mh, "_read");
	uintptr_t* pWriteImp = get_import_ptr(mh, "_write");
	*pReadImp = (uintptr_t)my_read;
	*pWriteImp = (uintptr_t)my_write;
	log_progress("%s IO hooked: r=%p w=%p", moduleName, pReadImp, pWriteImp);
}

void setup_hooks()
{
	safe_reportStart();
	if (!ensure_braille_service()) {
		log_progress("setup_hooks: ensure_braille_service failed!");
		return;
	} else {
		log_progress("setup_hooks: ensure_braille_service OK!");
	}
	struct stat info;
	g_logIo = (0 == stat("/tmp/btserver_log_io", &info));
	g_filterHci = (0 == stat("/tmp/btserver_filter_hci", &info));
	if (g_logIo || g_filterHci) {
		log_progress("setup_hooks: calling hook_read_write_ops()");		
		hook_read_write_ops();
	}
	
	safe_reportStartSuccess();
}