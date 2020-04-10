//
//  main.c
//  trace
//
//  Created by leo on 2020/2/4.
//  Copyright (c) 2020 ___ORGANIZATIONNAME___. All rights reserved.
//

#include <stdlib.h>
#include <stdio.h>
#include <notify.h>
#include <string.h>
#include <mach/mach_time.h>

int main (int argc, const char * argv[])
{
    // insert code here...
    if (argc == 0){

    }

    char* start_lock = "/var/mobile/Library/AppleTrace/start.lock";
    if (argc > 1){
        if (strcmp(argv[1], "start") == 0){
            int fd;
            if((fd = creat(start_lock, 0755))<0){
                perror("trace create");
            }
            
            //write start time
            mach_timebase_info_data_t timeinfo_;
            mach_timebase_info(&timeinfo_);
            uint64_t start_time_ns = mach_absolute_time() * timeinfo_.numer / timeinfo_.denom;
            char string[1024];
            sprintf(string,"%llu\n",start_time_ns);
            write(fd, &string, strlen(string));
            //write(fd, &start_time_ns, sizeof(start_time_ns));
            close(fd);

            notify_post("com.appletrace.start");
        }
        if (strcmp(argv[1], "stop") == 0){
            notify_post("com.appletrace.stop");
            unlink(start_lock);
        }
    }
	return 0;
}

