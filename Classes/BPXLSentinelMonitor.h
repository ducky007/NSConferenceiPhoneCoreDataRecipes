//
//  BPXLSentinelMonitor.h
//  Recipes
//
//  Created by Daniel Pasco on 1/21/12.
//  Copyright (c) 2012 Black Pixel. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef enum {
    iCloudMonitorStateUninitialized,
    iCloudMonitorStateReady,
    iCloudMonitorStateDataReset
} iCloudMonitorState;

@interface BPXLSentinelMonitor : NSObject
- (BOOL)preflightiCloudContainer:(NSURL*)cloudURL;
- (void)start;

- (void)writeUbiquitousUUIDFile:(void (^)(BOOL success))block;
        
@property (nonatomic, retain) NSURL *iCloudBaseURL;
@property iCloudMonitorState monitorState;
@property (nonatomic, retain) void (^startupSuccessBlock)(void);
@property (nonatomic, retain) void (^startupContainerResetBlock)(void);
@end
