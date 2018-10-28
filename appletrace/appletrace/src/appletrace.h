//
//  appletrace.h
//  appletrace
//
//  Created by everettjf on 2017/9/12.
//  Copyright © 2017年 everettjf. All rights reserved.
//


#if defined(__cplusplus)
extern "C" {
#else
#endif

void APTBeginSection(const char* name);
void APTEndSection(const char* name);
void APTSyncWait();

#if defined(__cplusplus)
}
#else
#endif

// Objective C class method
#define APTBegin APTBeginSection([NSString stringWithFormat:@"[%@]%@",self,NSStringFromSelector(_cmd)].UTF8String)
#define APTEnd APTEndSection([NSString stringWithFormat:@"[%@]%@",self,NSStringFromSelector(_cmd)].UTF8String)
