#ifndef OBJSUBSTRATE_H_
#define OBJSUBSTRATE_H_

#include <objc/runtime.h>
#include <objc/message.h>

inline void MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix) {
    if (_class == nil) {
        fprintf(stderr, "MS:Warning: nil class argument\n");
        return;
    } else if (sel == nil) {
        fprintf(stderr, "MS:Warning: nil sel argument\n");
        return;
    } else if (imp == nil) {
        fprintf(stderr, "MS:Warning: nil imp argument\n");
        return;
    }
	
    const char *name(sel_getName(sel));
	
    Method method(class_getInstanceMethod(_class, sel));
    if (method == nil) {
        fprintf(stderr, "MS:Warning: message not found [%s %s]\n", class_getName(_class), name);
        return;
    }
	
    const char *type(method_getTypeEncoding(method));
    IMP old(method_getImplementation(method));
	
    if (prefix != NULL) {
        size_t namelen(strlen(name));
        size_t fixlen(strlen(prefix));
		
        char *newname(reinterpret_cast<char *>(alloca(fixlen + namelen + 1)));
        memcpy(newname, prefix, fixlen);
        memcpy(newname + fixlen, name, namelen + 1);
		
        if (!class_addMethod(_class, sel_registerName(newname), old, type))
            fprintf(stderr, "MS:Error: failed to rename [%s %s]\n", class_getName(_class), name);
    }
	
    if (!class_addMethod(_class, sel, imp, type))
        method_setImplementation(method, imp);
}

#endif//OBJSUBSTRATE_H_
