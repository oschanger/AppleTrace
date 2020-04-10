#line 1 "/Users/leo/Documents/AppleTrace/loader/AppleTraceLoader/AppleTraceLoader.xm"


#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#include <dlfcn.h>

static __attribute__((constructor)) void _logosLocalCtor_344ae32b(int __unused argc, char __unused **argv, char __unused **envp) {
    @autoreleasepool{
        NSString *libraryPath;
        NSString *targetPath = @"/var/mobile/Library/AppleTraceTargets";
        
        NSString* content = [NSString stringWithContentsOfFile:targetPath encoding:NSUTF8StringEncoding error:NULL];

        NSArray *listItems = [content componentsSeparatedByString:@"\n"];
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        int pid = processInfo.processIdentifier;
        NSString* processName = processInfo.processName;
        NSLog(@"AppleTraceLoader processName %@", processName);

        for (NSString *s in listItems) {
            if ([s isEqualToString:processName]) {
                libraryPath = @"/usr/lib/TweakInject/appletrace.framework/appletrace";
            	if ([[NSFileManager defaultManager] fileExistsAtPath:libraryPath]){
                   
            	    void * ret = dlopen([libraryPath UTF8String], RTLD_NOW);
            	    if(ret == 0){
            	        const char * errinfo = dlerror();
            	        NSLog(@"AppleTraceLoader load failed : %@",[NSString stringWithUTF8String: errinfo]);
            	    }else{
            	        NSLog(@"AppleTraceLoader loaded %@", libraryPath);
            	    }
            	}else{
            	    NSLog(@"appletrace.framework not found");
            	}
                break;
            }
        }
    }
}
