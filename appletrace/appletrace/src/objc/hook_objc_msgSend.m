/**
 *    Copyright 2017 jmpews
 *    Modified by everettjf for AppleTrace
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

#include "hookzz/hookzz.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "appletrace.h"
#import <mach-o/dyld.h>

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <mach-o/fat.h>


#if defined(__LP64__)
#define ZREG(n) general.regs.x##n
#else
#define ZREG(n) general.regs.r##n
#endif


@interface AppleTraceHookZz : NSObject

@end

@implementation AppleTraceHookZz

+ (void)load {
    printf("appletrace loaded\n");
    [self hook_objc_msgSend];
}

void objc_msgSend_pre_call(RegisterContext *rs, const HookEntryInfo *info)
{
    char *sel_name = (char *)rs->ZREG(1);
    void *object_addr = (void *)rs->ZREG(0);
    const char *class_name = object_getClassName(object_addr);
//    unsigned long repl_len = strlen(class_name) + strlen(sel_name) + 10;
//    char *repl_name = malloc(repl_len);
//    snprintf(repl_name, repl_len, "[%s]%s",class_name,sel_name);
//    printf("pre %s",repl_name);
////    APTBeginSection(repl_name);
//    free(repl_name);
    
    printf("pre %s , %s\n",class_name,sel_name);

}
void objc_msgSend_post_call(RegisterContext *rs, const HookEntryInfo *info)
{
//    char *sel_name = (char *)rs->ZREG(1);
//    void *object_addr = (void *)rs->ZREG(0);
//    const char *class_name = object_getClassName(object_addr);
//    unsigned long repl_len = strlen(class_name) + strlen(sel_name) + 10;
//    char *repl_name = malloc(repl_len);
//    snprintf(repl_name, repl_len, "[%s]%s",class_name,sel_name);
//    APTEndSection(repl_name);
//    free(repl_name);
}


+ (void)hook_objc_msgSend {
    ZzWrap(objc_msgSend, objc_msgSend_pre_call, objc_msgSend_post_call);
}
@end


