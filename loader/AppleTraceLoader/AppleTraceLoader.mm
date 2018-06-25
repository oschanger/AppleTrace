#line 1 "/Users/qiwei/github/AppleTrace/tweak/AppleTraceLoader/AppleTraceLoader/AppleTraceLoader.xm"


#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif


#include <dlfcn.h>
static __attribute__((constructor)) void _logosLocalCtor_344ae32b(int __unused argc, char __unused **argv, char __unused **envp) {
    @autoreleasepool{
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.everettjf.AppleTraceLoader.plist"];
        NSString *libraryPath = @"/Library/Frameworks/appletrace.framework/appletrace";

        if([[prefs objectForKey:[NSString stringWithFormat:@"AppleTraceEnabled-%@", [[NSBundle mainBundle] bundleIdentifier]]] boolValue]) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:libraryPath]){
                dlopen([libraryPath UTF8String], RTLD_NOW);

                [[NSNotificationCenter defaultCenter] postNotificationName:@"AppleTraceServerDidLoadNotification" object:nil];
                NSLog(@"AppleTraceLoader loaded %@", libraryPath);
            }else{
                NSLog(@"AppleTraceServer not found");
            }
        }
    }
}
