

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <pthread.h>
#include <objc/runtime.h>

#include "apt_hooker.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/nlist.h>
#include <mach/task_info.h>

#include <pthread.h>
#include <objc/runtime.h>

#include "fishhook.h"

#include "appletrace.h"

void* log_class_start_addr = 0;
void* log_class_end_addr = 0;

#define DEFAULT_CALLSTACK_DEPTH 128
#define CALLSTACK_DEPTH_INCREMENT 64

// Shared structures.
typedef struct apt_call_record_ {
    id obj;
    SEL _cmd;
    uintptr_t lr;
    char * data;
} apt_call_record;

typedef struct apt_thread_callstack_ {
    apt_call_record *stack;
    int allocatedCount;
    int index;
} apt_thread_callstack;

static pthread_key_t s_apt_thread_key;

static inline apt_thread_callstack * getapt_thread_callstack() {
    apt_thread_callstack *cs = (apt_thread_callstack *)pthread_getspecific(s_apt_thread_key);
    if (cs == NULL) {
        cs = (apt_thread_callstack *)malloc(sizeof(apt_thread_callstack));
        cs->allocatedCount = DEFAULT_CALLSTACK_DEPTH;
        cs->stack = (apt_call_record *)calloc(cs->allocatedCount, sizeof(apt_call_record));
        cs->index = -1;
        pthread_setspecific(s_apt_thread_key, cs);
    }
    return cs;
}
    
static inline void push_call_record(id obj, SEL _cmd ,uintptr_t lr, char * strdata) {
    apt_thread_callstack *cs = getapt_thread_callstack();
    
    int nextIndex = (++cs->index);
    if (nextIndex >= cs->allocatedCount) {
        cs->allocatedCount += CALLSTACK_DEPTH_INCREMENT;
        cs->stack = (apt_call_record *)realloc(cs->stack, cs->allocatedCount * sizeof(apt_call_record));
    }
    
    apt_call_record *newRecord = &cs->stack[nextIndex];
    newRecord->obj = obj;
    newRecord->_cmd = _cmd;
    newRecord->lr = lr;
    newRecord->data = strdata;
}

static inline apt_call_record * pop_call_record() {
    apt_thread_callstack *cs = (apt_thread_callstack *)pthread_getspecific(s_apt_thread_key);
    return &cs->stack[cs->index--];
}

void apt_pre_objc_msgSend(id self, SEL _cmd, uintptr_t lr) {
    
    Class cls = object_getClass(self);
    char *repl_name = 0;
    
    void *class_addr = (void*)cls;
    if((class_addr >= log_class_start_addr && class_addr <= log_class_end_addr)){
        const char *class_name = class_getName(cls);
        const char *sel_name = sel_getName(_cmd);
        unsigned long repl_len = strlen(class_name) + strlen(sel_name) + 10;
        repl_name = malloc(repl_len);
        snprintf(repl_name, repl_len, "[%s]%s",class_name,sel_name);
        
        printf("pre msg send : %s\n",repl_name);
        APTBeginSection(repl_name);
    }

    push_call_record(self, _cmd, lr, repl_name);
}

uintptr_t apt_post_objc_msgSend() {
    apt_call_record *record = pop_call_record();

    if(record->data){
        printf("post msg send : %s\n",record->data);
        APTEndSection(record->data);

        free(record->data);
        record->data = NULL;
    }

    return record->lr;
}

// The original objc_msgSend.
static id (*orig_objc_msgSend)(id, SEL, ...);


// Our replacement objc_msgSend (arm64).
//
// See:
// https://blog.nelhage.com/2010/10/amd64-and-va_arg/
// http://infocenter.arm.com/help/topic/com.arm.doc.ihi0055b/IHI0055B_aapcs64.pdf
// https://developer.apple.com/library/ios/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARM64FunctionCallingConventions.html
#define call(b, value) \
__asm volatile ("stp x8, x9, [sp, #-16]!\n"); \
__asm volatile ("mov x12, %0\n" :: "r"(value)); \
__asm volatile ("ldp x8, x9, [sp], #16\n"); \
__asm volatile (#b " x12\n");

#define save() \
__asm volatile ( \
"stp x8, x9, [sp, #-16]!\n" \
"stp x6, x7, [sp, #-16]!\n" \
"stp x4, x5, [sp, #-16]!\n" \
"stp x2, x3, [sp, #-16]!\n" \
"stp x0, x1, [sp, #-16]!\n");

#define load() \
__asm volatile ( \
"ldp x0, x1, [sp], #16\n" \
"ldp x2, x3, [sp], #16\n" \
"ldp x4, x5, [sp], #16\n" \
"ldp x6, x7, [sp], #16\n" \
"ldp x8, x9, [sp], #16\n" );

#define link(b, value) \
__asm volatile ("stp x8, lr, [sp, #-16]!\n"); \
__asm volatile ("sub sp, sp, #16\n"); \
call(b, value); \
__asm volatile ("add sp, sp, #16\n"); \
__asm volatile ("ldp x8, lr, [sp], #16\n");

#define ret() __asm volatile ("ret\n");

__attribute__((__naked__))
static void hook_Objc_msgSend() {
    // Save parameters.
    save()
    
    __asm volatile ("mov x2, lr\n");
    __asm volatile ("mov x3, x4\n");
    
    // Call our before_objc_msgSend.
    call(blr, &apt_pre_objc_msgSend)
    
    // Load parameters.
    load()
    
    // Call through to the original objc_msgSend.
    call(blr, orig_objc_msgSend)
    
    // Save original objc_msgSend return value.
    save()
    
    // Call our after_objc_msgSend.
    call(blr, &apt_post_objc_msgSend)
    
    // restore lr
    __asm volatile ("mov lr, x0\n");
    
    // Load original objc_msgSend return value.
    load()
    
    // return
    ret()
}

static void destroyapt_thread_callstack(void *ptr) {
    apt_thread_callstack *cs = (apt_thread_callstack *)ptr;
    free(cs->stack);
    free(cs);
}



struct segment_command_64 *zz_macho_get_segment_64_via_name(struct mach_header_64 *header, char *segment_name);
struct section_64 *zz_macho_get_section_64_via_name(struct mach_header_64 *header, char *sect_name);


void apt_start_hook(){
    // Find class range
    const struct mach_header *header = _dyld_get_image_header(0);
    struct segment_command_64 *seg_cmd_64_text = zz_macho_get_segment_64_via_name((struct mach_header_64 *)header, (char *)"__TEXT");
    unsigned long slide = (unsigned long)header - (unsigned long)seg_cmd_64_text->vmaddr;
    struct section_64 *sect_64_2 = zz_macho_get_section_64_via_name((struct mach_header_64 *)header, (char *)"__objc_data");
    log_class_start_addr = (void*)slide + (unsigned long)sect_64_2->addr;
    log_class_end_addr = log_class_start_addr + sect_64_2->size;

    pthread_key_create(&s_apt_thread_key, &destroyapt_thread_callstack);

    rebind_symbols((struct rebinding[1]){
        {"objc_msgSend",
            (void*)hook_Objc_msgSend,
            (void**)&orig_objc_msgSend},
    }, 1);
}
    



struct section_64 *zz_macho_get_section_64_via_name(struct mach_header_64 *header, char *sect_name) {
    struct load_command *load_cmd;
    struct segment_command_64 *seg_cmd_64;
    struct section_64 *sect_64;
    
    load_cmd = (void*)header + sizeof(struct mach_header_64);
    unsigned long i;
    unsigned long j;
    for (i = 0; i < header->ncmds; i++, load_cmd = (void*)load_cmd + load_cmd->cmdsize) {
        if (load_cmd->cmd == LC_SEGMENT_64) {
            seg_cmd_64 = (struct segment_command_64 *)load_cmd;
            sect_64    = (struct section_64 *)((void*)seg_cmd_64 + sizeof(struct segment_command_64));
            for (j = 0; j < seg_cmd_64->nsects; j++, sect_64 = (void*)sect_64 + sizeof(struct section_64)) {
                if (!strcmp(sect_64->sectname, sect_name)) {
                    return sect_64;
                }
            }
        }
    }
    return NULL;
}

struct segment_command_64 *zz_macho_get_segment_64_via_name(struct mach_header_64 *header, char *segment_name) {
    struct load_command *load_cmd;
    struct segment_command_64 *seg_cmd_64;
    
    load_cmd = (void*)header + sizeof(struct mach_header_64);
    unsigned long i;
    for (i = 0; i < header->ncmds; i++, load_cmd = (void*)load_cmd + load_cmd->cmdsize) {
        if (load_cmd->cmd == LC_SEGMENT_64) {
            seg_cmd_64 = (struct segment_command_64 *)load_cmd;
            if (!strcmp(seg_cmd_64->segname, segment_name)) {
                return seg_cmd_64;
            }
        }
    }
    return NULL;
}
    
