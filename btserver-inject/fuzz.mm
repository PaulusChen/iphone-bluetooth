/*
 *  fuzz.mm
 *  bbinj
 *
 *  Created by msftguy on 6/20/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "fuzz.h"

#include "logging.h"

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>

void round_to_pages(void* addr, size_t size, vm_address_t* pVmaddr, vm_size_t* pVmsize)
{
	*pVmaddr = (vm_address_t)addr & ~PAGE_MASK;
	*pVmsize = (size + (vm_address_t)addr & PAGE_MASK + PAGE_SIZE - 1) & ~PAGE_MASK;
}

bool get_mem_prot(void* addr, size_t size, vm_prot_t* outProt)
{
	vm_address_t vmaddr, outVmaddr;
	vm_size_t vmsize, outVmsize;
	round_to_pages(addr, size, &vmaddr, &vmsize);	

	vm_region_basic_info info;
	mach_msg_type_number_t infoCount = sizeof(info);
	mach_port_t	object_name;

	outVmaddr = vmaddr;
	outVmsize = vmsize;
	kern_return_t result = vm_region(mach_task_self(), &outVmaddr, &outVmsize, VM_REGION_BASIC_INFO, (int*)&info, &infoCount, &object_name);
	if (result != KERN_SUCCESS) {
		log_progress("get_page_prot: error getting page protection at %p (size %u); err=0x%X", addr, size, result);
		return false;
	}
	
#ifdef DEBUG
	log_progress("get_page_prot DEBUG: prot at %p (size 0x%x) is 0x%X, offset: 0x%X, max_protection: 0x%X", 
				 outVmaddr, outVmsize, info.protection, info.offset, info.max_protection);
#endif

	*outProt = info.protection;
	return true;
}

bool set_mem_prot(void* addr, size_t size, vm_prot_t newProt)
{
	vm_address_t vmaddr;
	vm_size_t vmsize;
	round_to_pages(addr, size, &vmaddr, &vmsize);	
	
	kern_return_t result;
	result = vm_protect(mach_task_self(), vmaddr, vmsize, false, newProt | VM_PROT_COPY);
	if (result != KERN_SUCCESS) {
		log_progress("set_mem_prot: error setting page protection at %p (size %u); err=0x%X", vmaddr, vmsize, result);
		return false;
	}
#ifdef DEBUG
	log_progress("set_mem_prot DEBUG: prot at %p (size 0x%x) is 0x%X", 
				 vmaddr, vmsize, newProt);
#endif
	
	return true;
}

char* findBytesInSect(const mach_header* mh, size_t slide, const char* segname, const char* sectname, const char* pattern, 
					  size_t patternSize = 0, int align = 0);

char* findBytesInSect(const mach_header* mh, size_t slide, const char* segname, const char* sectname, const char* pattern, 
					  size_t patternSize, int align)
{
	if (patternSize == 0) {
		patternSize = strlen(pattern) + 1;
	}
	if (align == 0) {
		align = 1;
	}
	uint32_t sectSize = 0;
	char* sectData = getsectdatafromheader(mh, segname, sectname, &sectSize);
	if (sectData == NULL) {
		log_progress("findBytesInSect: section %s:%s not found", segname, sectname);	
	}
	sectData += slide;

	char* foundLoc = NULL;
	for (char* p = sectData; p < sectData + sectSize - patternSize; p += align) 
	{
		if (memcmp(p, pattern, patternSize) == 0) {
			if (foundLoc == NULL) {
				foundLoc = p;
			} else {
				log_progress("findBytesInSect: multiple matches: %p and %p", foundLoc, p);
				return NULL;
			}
		}
	}
	return foundLoc;
}

static int enabledServicesArray[] = 
{
	0x0003,	// 0 - iPhone Orig
	0x0000,	// 1 - iPod Touch 1G
	0x099B,	// 2 - iPhone 3G
	0x08D8,	// 3 - iPod Touch 2G
	0x29FB, // 4 - iPhone 3GS
	0x28B8,	// 5 - ???
	0x08D8,	// 6 - ???
	0x29FB, // 7 - iPhone 4
	0x28F8, // 8 - ???
	0x29FB, // 9 - ???
	0x28F8, // 10 -???
	0x08B8, // 11 -???
};

//unsigned char codeBytes[] = 
//{
//	0x7B, 0x44,
//	0x53, 0xF8, 0x22, 0x30,
//	0x1E, 0x42,
//	0x0C, 0xBF,
//	0x00, 0x24,
//	0x01, 0x24,
//}; 

bool ensure_braille_service()
{
	const mach_header* mh = _dyld_get_image_header(0);
	size_t slide = _dyld_get_image_vmaddr_slide(0);

//  /* code patch */
//	char* pBytesToPatch = findBytesInSect(mh, slide, "__TEXT", "__text", (const char*)codeBytes, 
//					sizeof(codeBytes), sizeof(short));
//	if (pBytesToPatch == NULL) {
//		log_progress("ensure_braille_service: could not locate codeBytes; check for updates!");
//		return false;
//	}
//#ifdef DEBUG
//	log_progress("ensure_braille_service DEBUG: codeBytes at %p", pBytesToPatch);
//#endif
//	const size_t PATCH_OFFSET = 0x0A;
//	int patchedWord = *(int*)(pBytesToPatch + PATCH_OFFSET);
//	*(char*)&patchedWord = 1; 
//	patch_word(pBytesToPatch + PATCH_OFFSET, (void*)patchedWord);
//	log_progress("ensure_braille_service: patched profile check");	
//
	
	/* data patch */
	int* pEnabledServicesArray = (int*)findBytesInSect(mh, slide, "__TEXT", "__const", (const char*)enabledServicesArray, 
					sizeof(enabledServicesArray), sizeof(int));
	if (pEnabledServicesArray == NULL) {
		log_progress("ensure_braille_service: could not locate enabledServicesArray; check for updates!");
		return false;
	}

	vm_prot_t oldProt;
	if (!get_mem_prot(pEnabledServicesArray, sizeof(enabledServicesArray), &oldProt)) {
		log_progress("ensure_braille_service: get_mem_prot() failed!");
		return false;
	}
	if (!set_mem_prot(pEnabledServicesArray, sizeof(enabledServicesArray), VM_PROT_READ | VM_PROT_WRITE)) {
		log_progress("ensure_braille_service: set_mem_prot() failed!");
		return false;		
	}

	const int BRAILLE_SERVICE = 0x2000;
	
	for (int i = 0; i < sizeof(enabledServicesArray) / sizeof(int); ++i) {
		pEnabledServicesArray[i] |= BRAILLE_SERVICE;
	}
	
	if (!set_mem_prot(pEnabledServicesArray, sizeof(enabledServicesArray), oldProt)) {
		log_progress("ensure_braille_service: set_mem_prot(RESTORE) failed!");
		return false;
	}
	
	log_progress("ensure_braille_service: OK!");	
	return true;
}
