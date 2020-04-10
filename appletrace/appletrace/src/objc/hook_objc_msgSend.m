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
#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc-exception.h>
#import <pthread.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "appletrace.h"

//#define KDISABLE

struct section_64 *zz_macho_get_section_64_via_name(struct mach_header_64 *header, char *sect_name);
zpointer zz_macho_get_section_64_address_via_name(struct mach_header_64 *header, char *sect_name);
struct segment_command_64 *zz_macho_get_segment_64_via_name(struct mach_header_64 *header, char *segment_name);

Class zz_macho_object_get_class(id object_addr);

zpointer log_sel_start_addr = 0;
zpointer log_sel_end_addr = 0;
zpointer log_class_start_addr = 0;
zpointer log_class_end_addr = 0;

char decollators[128] = {0};
void sprintfArg(char *fd, RegState *rs, int index, char *type_name);

int LOG_ALL_SEL = 1;
int LOG_ALL_CLASS = 1;
int LOG_PRINT = 0;
int LOG_ARGS = 1;

@interface HookZz : NSObject

@end

@implementation HookZz

void HandleException(NSException *exception) {
    NSLog(@"[AppleTrace] handle exception");
    NSArray* stack = [exception callStackSymbols];
    NSString* reason = [exception reason];
    NSString* info = [NSString stringWithFormat:@"[AppleTrace] reason %@, name %@, stack %@",reason,[exception name],stack];
    NSLog(@"%@", info);
}
void handleSignal(int signo) {
    NSLog(@"[AppleTrace] handle signal %d", signo);
    //pthread_kill(pthread_self(), SIGSEGV);
}
void RegisterSignalHandler(void) {
    NSSetUncaughtExceptionHandler(&HandleException);
    //注册程序由于abort()函数调用发生的程序中止信号
    signal(SIGABRT, handleSignal);
    //注册程序由于非法指令产生的程序中止信号
    signal(SIGILL, handleSignal);
    //注册程序由于无效内存的引用导致的程序中止信号
    signal(SIGSEGV, handleSignal);
    //注册程序由于浮点数异常导致的程序中止信号
    signal(SIGFPE, handleSignal);
    //注册程序由于内存地址未对齐导致的程序中止信号
    signal(SIGBUS, handleSignal);
    //程序通过端口发送消息失败导致的程序中止信号
    signal(SIGPIPE, handleSignal);
}

void setEnv(){
    setenv("DYLD_PRINT_LIBRARIES", "1", 1);
    setenv("DYLD_PRINT_INITIALIZERS", "1", 1);

}

+ (void)load {
    RegisterSignalHandler();
    setEnv();
    const struct mach_header *header = _dyld_get_image_header(0);
    struct segment_command_64 *seg_cmd_64_text = zz_macho_get_segment_64_via_name((struct mach_header_64 *)header, (char *)"__TEXT");
    zsize slide = (zaddr)header - (zaddr)seg_cmd_64_text->vmaddr;
    struct section_64 *sect_64_1 = zz_macho_get_section_64_via_name((struct mach_header_64 *)header, (char *)"__objc_methname");
    if (sect_64_1) {
        log_sel_start_addr = slide + (zaddr)sect_64_1->addr;
        log_sel_end_addr = log_sel_start_addr + sect_64_1->size;
    } else {
        NSLog(@"[AppleTrace] no __objc_methname return");
        return;
    }
 
    struct section_64 *sect_64_2 = zz_macho_get_section_64_via_name((struct mach_header_64 *)header, (char *)"__objc_data");
    if (sect_64_2) { //there's no "__objc_data" sometime
        log_class_start_addr = slide + (zaddr)sect_64_2->addr;
        log_class_end_addr = log_class_start_addr + sect_64_2->size;
    } else {
        NSLog(@"[AppleTrace] no __objc_data return");
        return;
    }
    [self hook_objc_msgSend];
}


/*
 if (
 strncmp(alpha, "CA", 2) == 0 ||
 strncmp(alpha, "CF", 2) == 0 ||
 strncmp(alpha, "NS", 2) == 0 ||
 strncmp(alpha, "UI", 2) == 0 ||
 false)
 return;
 */
//should skip methods' hook in the trace rutine of out project,or it will go into dead loop
bool isClassInWhiteList(const char *class_name){
    if (strstr(class_name, "Render") > 0){
        return true;
    }
    if (strstr(class_name, "ViewController") > 0){
        return true;
    }
    if (strstr(class_name, "Layout") > 0){
        return true;
    }
    if (strstr(class_name, "NS") || strstr(class_name, "CF") || strstr(class_name, "CUI")){
        return false;
    }
    return true;
}

void objc_msgSend_pre_call(RegState *rs, ThreadStack *threadstack, CallStack *callstack) {
    char *sel_name = (char *)rs->general.regs.x1;
    // The first filter algo
    if(LOG_ALL_SEL || (sel_name > log_sel_start_addr && sel_name < log_sel_end_addr)) {
    
        // bad code! correct-ref: https://github.com/DavidGoldman/InspectiveC/blob/299cef1c40e8a165c697f97bcd317c5cfa55c4ba/logging.mm#L27
        void *object_addr = (void *)rs->general.regs.x0;
        void *class_addr = zz_macho_object_get_class((id)object_addr);
        if(!class_addr)
            return;

        void *super_class_addr = class_getSuperclass(class_addr);

        // The second filter algo
        if(LOG_ALL_CLASS || ((class_addr > log_class_start_addr && class_addr < log_class_end_addr) || (super_class_addr > log_class_start_addr && super_class_addr < log_class_end_addr))) {
            memset(decollators, 45, 128);
            if(threadstack->size * 3 >= 128)
                return;
            decollators[threadstack->size * 3] = '\0';
            const char *class_name = object_getClassName(object_addr);
            unsigned long class_name_length = strlen(class_name);
            if( isClassInWhiteList(class_name) ) {
                Method method = class_getInstanceMethod(class_addr, (SEL _Nonnull)sel_name);
                int num_args = method_getNumberOfArguments(method);
                char method_name[512] = {0};
                char sel_name_tmp[512] = {0};
                char *x;
                char *y;
                x = sel_name_tmp;
                strcpy(sel_name_tmp, sel_name);
                if(!strchr(x, ':')) {
                    //if(LOG_PRINT) printf("thread-id: %ld | %s [%s %s]\n", threadstack->thread_id, decollators, class_name, sel_name_tmp);
                    return;
                }
                for (int i=2; strchr(x, ':') && i < num_args; i++) {
                    y = strchr(x, ':');
                    *y = '\0';
                    char *type_name = method_copyArgumentType(method, i);
                    sprintf(method_name + strlen(method_name), "%s:", x);
                    //if (strstr(method_name, "init") <= 0){
                        if(LOG_ARGS) sprintfArg(method_name + strlen(method_name), rs, i, type_name);
                    //}
                    x = y + 1;
                }
                // if(LOG_PRINT) printf("thread-id: %ld | %s [%s %s]\n", threadstack->thread_id, decollators, class_name, method_name);
                unsigned long repl_len = strlen(class_name) + strlen(method_name) + 10;
                char *repl_name = malloc(repl_len);
                snprintf(repl_name, repl_len, "[%s %s]",class_name,method_name);
                //if(LOG_PRINT) NSLog(@"[AppleTrace] thread-id: %ld | %s \n", threadstack->thread_id, repl_name);
                STACK_SET(callstack, "repl_name", repl_name, char*);
                if(LOG_PRINT) printf("thread-id: %ld | %s \n", threadstack->thread_id, repl_name);
                APTBeginSection(repl_name);
            }
        }
    }
}

static inline BOOL isKindOfClass(Class selfClass, Class clazz) {
    for (Class candidate = selfClass; candidate; candidate = class_getSuperclass(candidate)) {
        if (candidate == clazz) {
            return YES;
        }
    }
    return NO;
}

enum {
    BLOCK_HAS_COPY_DISPOSE = (1 << 25),
    BLOCK_HAS_CTOR = (1 << 26), // Helpers have C++ code.
    BLOCK_IS_GLOBAL = (1 << 28),
    BLOCK_HAS_STRET = (1 << 29), // IFF BLOCK_HAS_SIGNATURE.
    BLOCK_HAS_SIGNATURE = (1 << 30),
};

struct BlockLiteral_ {
    void *isa; // Should be initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock.
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct BlockDescriptor_ {
        unsigned long int reserved; // NULL.
        unsigned long int size; // sizeof(struct BlockLiteral_).
        // Optional helper functions.
        void (*copy_helper)(void *dst, void *src); // IFF (1 << 25).
        void (*dispose_helper)(void *src); // IFF (1 << 25).
        const char *signature; // IFF (1 << 30).
    } *descriptor;
};

// Thanks to CTObjectiveCRuntimeAdditions (https://github.com/ebf/CTObjectiveCRuntimeAdditions).
// See http://clang.llvm.org/docs/Block-ABI-Apple.html.
void logBlock(char *fd, id block) {
    struct BlockLiteral_ *blockRef = (__bridge struct BlockLiteral_ *)block;
    int flags = blockRef->flags;
    
    const char *signature = NULL;
    
    if (flags & BLOCK_HAS_SIGNATURE) {
        unsigned char *signatureLocation = (unsigned char *)blockRef->descriptor;
        signatureLocation += sizeof(unsigned long int);
        signatureLocation += sizeof(unsigned long int);

        if (flags & BLOCK_HAS_COPY_DISPOSE) {
            signatureLocation += sizeof(void (*)(void *, void *));
            signatureLocation += sizeof(void (*)(void *));
        }

        signature = (*(const char **)signatureLocation);
    }
    
    if (signature) {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:signature];
        Class kind = object_getClass(block);
        sprintf(fd, "<%s@%p signature=\"%s ; retType=%s", class_getName(kind), (__bridge void *)block, signature, methodSignature.methodReturnType);

        // Skip the first argument (self).
        NSUInteger numOfArgs = methodSignature.numberOfArguments;
        for (NSUInteger i = 1; i < numOfArgs; ++i) {
            sprintf(fd,"%s %u=%s",fd, (unsigned)i, [methodSignature getArgumentTypeAtIndex:i]);
        }
        sprintf(fd,"%s \">",fd);
    } else {
        Class kind = object_getClass(block);
        sprintf(fd, "<%s@%p>", class_getName(kind), (__bridge void *)block);
    }
}

void logObject(char *fd, id obj) {
    if (obj == nil) {
        sprintf(fd, "<nil>");
        return;
    }
    //TODO: this if should be removed. Normal int should not be here
    if ((int)obj < 1000 && (int)obj > 0 ) {
        sprintf(fd, "<%d>",(int)obj);
        return;
    }

    Class kind = object_getClass(obj);
    //Class kind = [obj class];
    if (kind) {
        if (class_isMetaClass(kind)) {
            sprintf(fd, "[%s class]", class_getName(obj));
            return;
        }
        if (isKindOfClass(kind, objc_getClass("NSString"))) {
            sprintf(fd, "@\'%s\'" , [(NSString*)obj UTF8String]);
            return;
        }
        if (isKindOfClass(kind, objc_getClass("NSMutableString"))) {
            sprintf(fd, "@\'%s\'" , [(NSString*)obj UTF8String]);
            return;
        }
        if (isKindOfClass(kind, objc_getClass("NSBlock"))) {
            logBlock(fd, obj);
            return;
        }
        sprintf(fd, "<%s@%p>", object_getClassName(obj), (void *)(obj));
    }
}

void sprintfArg(char *fd, RegState *rs, int index, char *type_name) {
    if(index >= 8) {
        sprintf(fd, "%s", "<stack>"); //TODO:print stack args
        return;
    }
    loop:
    switch(*type_name) {
        case '#': // a class object
        case '@':{// an object
            //FIXME: fix crash
            //sprintf(fd, "<class:%s>", object_getClassName((void *)rs->general.x[index]));
            //logObject(fd, (void *)rs->general.x[index]);
        } break;
        case '*':{// a char string
            //FIXME: need encoding for chrome
            //sprintf(fd, "<chars'\%s'>", (char *)(rs->general.x[index]));
        } break;
        case ':':{// method selector
            SEL value = (SEL)(rs->general.x[index]);
            if (value == NULL) {
                sprintf(fd, "NULL");
            } else {
                sprintf(fd, "sel(%s)", sel_getName(value));
            }
        } break;
        case '^': { // A pointer to type (^type).
            void *value = (void *)rs->general.x[index];
            if (value == NULL) {
                sprintf(fd, "NULL");
            } else {
                sprintf(fd, "<%p>", value);
            }
        } break;
        case 'B':{ // bool
            sprintf(fd, "<%s>",  (BOOL)(rs->general.x[index])?"Y":"N");
        } break;
        case 'c':{ // char
            sprintf(fd, "<%c>", (char)(rs->general.x[index]));
        } break;
        case 'C':
        case 's':
        case 'S':
        case 'i':{ //int
            sprintf(fd, "<%d>", (int)(rs->general.x[index]));
        } break;
        case 'I':{ //unsigned int
            sprintf(fd, "<%u>", (unsigned int)rs->general.x[index]);
        } break;
        case 'l':{ //long
            sprintf(fd, "<%ld>", (long)rs->general.x[index]);
        } break;
        case 'q':{ //long long
            sprintf(fd, "<%lld>", (long long)rs->general.x[index]);
        } break;
        case 'L':{ //unsigned long
            sprintf(fd, "<%lu>", (unsigned long)rs->general.x[index]);
        } break;
        case 'Q':{ //unsigned long long
            sprintf(fd, "<%llu>", (unsigned long long)rs->general.x[index]);
        } break;
        case 'f':{ //float
            sprintf(fd, "<%g>", (float)rs->general.x[index]);
        } break;
        case 'd':{ //double
            sprintf(fd, "<%g>", (double)rs->general.x[index]);
        } break;
        case 'r':{ //resource
            sprintf(fd, "<r>");
        } break;
        case 'V':{ //oneway.
            ++type_name;
            goto loop;
        } break;
        //TODO:not verified below
        case '{': { // A struct. We check for some common structs.
            if (strncmp(type_name, "{CGPoint=", 9) == 0) {
                double a = (double)rs->floating.q[index].d.d1;
                double b = (double)rs->floating.q[index+1].d.d1;
                //CGPoint point = (CGPoint){a,b};
                //sprintf(fd, "<CGPoint %s>",[NSStringFromCGPoint(point) UTF8String]);
            } else if (strncmp(type_name, "{CGRect=", 8) == 0) {
                double a = (double)rs->floating.q[index].d.d1;
                double b = (double)rs->floating.q[index+1].d.d1;
                double c = (double)rs->floating.q[index+2].d.d1;
                double d = (double)rs->floating.q[index+3].d.d1;
                //CGRect size = (CGRect){a,b,c,d};
                //sprintf(fd, "<CGRect %s>",[NSStringFromCGRect(size) UTF8String]);
            } else if (strncmp(type_name, "{CGSize=", 8) == 0) {
                double a = (double)rs->floating.q[index].d.d1;
                double b = (double)rs->floating.q[index+1].d.d1;
                //CGSize point = (CGSize){a,b};
                //sprintf(fd, "<CGSize %s>",[NSStringFromCGSize(point) UTF8String]);
            } else if (strncmp(type_name, "{UIOffset=", 10) == 0) {
                sprintf(fd, "<UIOffset>");
            } else if (strncmp(type_name, "{_NSRange=", 10) == 0) {
                sprintf(fd, "<_NSRange>");
            } else if (strncmp(type_name, "{UIEdgeInsets=", 14) == 0) {
                sprintf(fd, "<UIEdgeInsets>");
            } else if (strncmp(type_name, "{CGAffineTransform=", 19) == 0) {
                sprintf(fd, "<CGAffineTransform>");
            } else { // unknown.
                sprintf(fd, "<%c>", *type_name);
                return;
            }
        } break;
        default:{
            sprintf(fd, "<%c>", *type_name);
        };
    }
}

void objc_msgSend_post_call(RegState *rs, ThreadStack *threadstack, CallStack *callstack) {
    if(STACK_CHECK_KEY(callstack, "is_ignored"))
        return;

    if(STACK_CHECK_KEY(callstack, "repl_name")){
        char *repl_name = STACK_GET(callstack, "repl_name", char*);
//        NSLog(@"post %s",repl_name);
        APTEndSection(repl_name);
        
        free(repl_name);
    }
}


void objc_exception_throw_hook(RegState *rs, ThreadStack *threadstack, CallStack *callstack) {
    NSLog(@"[AppleTrace] objc_exception_throw_hook");
    return;
}

void _objc_exception_destructor_hook(RegState *rs, ThreadStack *threadstack, CallStack *callstack) {
    NSLog(@"[AppleTrace] _objc_exception_destructor_hook");
    return;
}
//ZzBuildHook(zpointer target_ptr, zpointer replace_call_ptr, zpointer *origin_ptr, PRECALL pre_call_ptr,POSTCALL post_call_ptr, zbool try_near_jump) {
+ (void)hook_objc_msgSend {
    NSLog(@"[AppleTrace] apple trace loaded");

    ZzBuildHook((void *)objc_msgSend, NULL, NULL, objc_msgSend_pre_call, objc_msgSend_post_call,true);
    ZzEnableHook((void *)objc_msgSend);
    zpointer objc_exception_throw_ptr = (void *)objc_exception_throw;
//    ZzBuildHook((void *)objc_exception_throw_ptr, (void*)objc_exception_throw_hook, NULL, NULL, NULL ,true);
//    ZzEnableHook((void *)objc_exception_throw_ptr);

//    ZzBuildHook((void *)_objc_exception_destructor, (void*)_objc_exception_destructor_hook, NULL, NULL, NULL ,true);
 //   ZzEnableHook((void *)pthread_kill);
}
@end

Class zz_macho_object_get_class(id object_addr) {
    if(!object_addr)
        return NULL;
#if 0
    if(object_isClass(object_addr)) {
        return object_addr;
    } else {
        return object_getClass(object_addr);
    }
#elif 1
    return object_getClass(object_addr);
#elif 0
    Class kind = object_getClass(object_addr);
    
    if (class_isMetaClass(kind))
        return object_addr;
    return kind;
#endif
}
