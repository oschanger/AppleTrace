// See http://iphonedevwiki.net/index.php/Logos

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif


#include <dlfcn.h>
%ctor {
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
