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
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

typedef void *zz_ptr_t;
typedef unsigned long zz_addr_t;

#if defined(__LP64__)
#define ZREG(n) general.regs.x##n
#else
#define ZREG(n) general.regs.r##n
#endif

//#define KDISABLE

zz_ptr_t MachoKitGetSectionByName(mach_header_t *header, char *sect_name) {
    struct load_command *load_cmd;
    segment_command_t *seg_cmd;
    section_t *sect;
    uintptr_t slide=0, linkEditBase=0;
    
    load_cmd = (struct load_command *)((zz_addr_t)header + sizeof(mach_header_t));
    for (uint i = 0; i < header->ncmds;
         i++, load_cmd = (struct load_command *)((zz_addr_t)load_cmd + load_cmd->cmdsize)) {
        if (load_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            seg_cmd = (segment_command_t *)load_cmd;
            if (seg_cmd->fileoff == 0 && seg_cmd->filesize != 0 && strcmp(seg_cmd->segname, "__TEXT") == 0) {
                slide = (uintptr_t)header - seg_cmd->vmaddr;
            }
            if (strcmp(seg_cmd->segname, "__LINKEDIT") == 0) {
                linkEditBase = seg_cmd->vmaddr - seg_cmd->fileoff + slide;
            }
            sect = (section_t *)((zz_addr_t)seg_cmd + sizeof(segment_command_t));
            for (uint j = 0; j < seg_cmd->nsects;
                 j++, sect = (section_t *)((zz_addr_t)sect + sizeof(section_t))) {
                if (!strcmp(sect->sectname, sect_name)) {
                    return (zz_ptr_t)(sect->addr + slide);
                }
            }
        }
    }
    return NULL;
}

segment_command_t *MachoKitGetSegmentByName(mach_header_t *header, char *segment_name) {
    struct load_command *load_cmd;
    segment_command_t *seg_cmd;
    
    load_cmd = (struct load_command *)((zz_addr_t)header + sizeof(mach_header_t));
    for (uint i = 0; i < header->ncmds;
         i++, load_cmd = (struct load_command *)((zz_addr_t)load_cmd + load_cmd->cmdsize)) {
        if (load_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            seg_cmd = (segment_command_t *)load_cmd;
            if (!strcmp(seg_cmd->segname, segment_name)) {
                return seg_cmd;
            }
        }
    }
    return NULL;
}

int filter_max                  = 0;
char *class_address_filters[20] = {0};

void * log_sel_start_addr = 0;
void * log_sel_end_addr = 0;
void * log_class_start_addr = 0;
void * log_class_end_addr = 0;
char decollators[128] = {0};

int LOG_ALL_CLASS = 0;

@interface AppleTraceHookZz : NSObject

@end

@implementation AppleTraceHookZz

+ (void)load {
#ifdef KDISABLE
    return;
#endif
    
    char *class_name_filters[20] = {
//        "UIApplication", "AppDelegate",
    };
    
    filter_max = sizeof(class_name_filters) / sizeof(char *);
    int i;
    for (i = 0; i < filter_max; i++) {
        class_address_filters[i] = (char*)objc_getClass(class_name_filters[i]);
    }
    
    [self hook_objc_msgSend];
    NSLog(@"appletrace loaded");
}

void objc_msgSend_pre_call(RegState *rs, ThreadStackPublic *threadstack, CallStackPublic *callstack, const HookEntryInfo *info) {
    char *sel_name = (char *)rs->ZREG(1);
    
    // bad code! correct-ref: https://github.com/DavidGoldman/InspectiveC/blob/299cef1c40e8a165c697f97bcd317c5cfa55c4ba/logging.mm#L27
    void *object_addr = (void *)rs->ZREG(0);
    void *class_addr  = object_getClass((id)object_addr);
    if (!class_addr)
        return;

    int i = 0;
    for (; class_address_filters[i] != 0; i++) {
        if ((zz_addr_t)class_address_filters[i] == (zz_addr_t)class_addr)
            break;
    }
    if (class_address_filters[i]){
        STACK_SET(callstack, "is_ignored", class_addr, void*);
        return;
    }

    memset(decollators, 45, 128);
    if(threadstack->size * 3 >= 128)
        return;
    decollators[threadstack->size * 3] = '\0';
    const char *class_name = object_getClassName(object_addr);
    
    unsigned long repl_len = strlen(class_name) + strlen(sel_name) + 10;
    char *repl_name = malloc(repl_len);
    snprintf(repl_name, repl_len, "[%s]%s",class_name,sel_name);
    STACK_SET(callstack, "repl_name", repl_name, char*);
    
//    NSLog(@"pre %s",repl_name);
    APTBeginSection(repl_name);
}

void objc_msgSend_post_call(RegState *rs, ThreadStackPublic *threadstack, CallStackPublic *callstack, const HookEntryInfo *info) {
    if(STACK_CHECK_KEY(callstack, "is_ignored"))
        return;

    if(STACK_CHECK_KEY(callstack, "repl_name")){
        char *repl_name = STACK_GET(callstack, "repl_name", char*);
//        NSLog(@"post %s",repl_name);
        APTEndSection(repl_name);
        
        free(repl_name);
    }
}

+ (void)hook_objc_msgSend {
    DebugLogControlerEnableLog();
    
#if 1
    const struct mach_header *header = _dyld_get_image_header(0);
    ZzHookGOT((void*)header, "objc_msgSend", NULL, NULL, objc_msgSend_pre_call, objc_msgSend_post_call);
#else
    ZzHook((void *)objc_msgSend, NULL, NULL, objc_msgSend_pre_call, objc_msgSend_post_call, false);
#endif
}
@end


