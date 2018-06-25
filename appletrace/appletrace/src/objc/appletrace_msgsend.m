//
//  appletrace_msgsend.m
//  appletrace
//
//  Created by everettjf on 28/09/2017.
//  Copyright © 2017 everettjf. All rights reserved.
//

#import "appletrace_msgsend.h"

static BOOL apt_s_enabled = YES; // default to enable

void APTEnable(BOOL enable){
    apt_s_enabled = enable;
}
BOOL APTIsEnable(){
    return apt_s_enabled;
}

