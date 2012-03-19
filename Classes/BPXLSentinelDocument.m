//
//  BPXLSentinelDocument.m
//  Recipes
//
//  Created by Daniel Pasco on 1/21/12.
//  Copyright (c) 2012 Black Pixel. All rights reserved.
//

#import "BPXLSentinelDocument.h"
#import "BPXLSentinelMonitor.h"
@implementation BPXLSentinelDocument
@synthesize delegate;
@synthesize contents;

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError {
    return [self.contents dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    return [self.contents dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError {
    return YES;
}

#pragma mark -
#pragma mark NSFilePresenter
#pragma mark -
- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError *errorOrNil))completionHandler {
    NSLog(@"Our uuid file has been deleted");
    self.delegate.monitorState = iCloudMonitorStateDataReset;
//    [self resetiCloudData];
//    [self preflightiCloudContainer:self.iCloudBaseURL];
    completionHandler(nil);
}

+ (BOOL)autosavesInPlace {
    return YES;
}

@end
