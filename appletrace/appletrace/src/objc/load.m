#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "appletrace.h"
#include "apt_hooker.h"


@interface AppleTraceMsgHooker : NSObject
@end
@implementation AppleTraceMsgHooker
+ (void)load {
    apt_start_hook();
}
@end
