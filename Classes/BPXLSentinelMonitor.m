//
//  BPXLSentinelMonitor.m
//  Recipes
//
//  Created by Daniel Pasco on 1/21/12.
//  Copyright (c) 2012 Black Pixel. All rights reserved.
//

#import "BPXLSentinelMonitor.h"
#import "BPXLSentinelDocument.h"
#import "RecipesAppDelegate.h"

NSString *BPXLiCloudContainerLocalUUID = @"BPXLiCloudContainerLocalUUID";
NSString *BPXLiCloudContainerFilePrefix = @"file://localhost/private/var/mobile/Library/Mobile%20Documents/";

@interface BPXLSentinelMonitor()
@property (nonatomic, retain) BPXLSentinelDocument *sentinelDocument;
@property (nonatomic, retain) NSMetadataQuery *metadataQuery;
@property (nonatomic, retain) NSMutableDictionary *documentsURLs;
@property (nonatomic, retain) NSURL *sentinelFileURL;
@property (nonatomic) BOOL creatingSentinelFile;
@property (nonatomic) BOOL sentinelFileReady;
@end

@implementation BPXLSentinelMonitor
@synthesize iCloudBaseURL = _iCloudBaseURL;
@synthesize sentinelDocument;
@synthesize metadataQuery;
@synthesize documentsURLs;
@synthesize sentinelFileURL;
@synthesize monitorState;
@synthesize startupSuccessBlock = _startupSuccessBlock;
@synthesize startupContainerResetBlock = _startupContainerResetBlock;
@synthesize creatingSentinelFile = _creatingSentinelFile;
@synthesize sentinelFileReady = _sentinelFileReady;

- (void)dealloc {
    self.sentinelDocument = nil;
    Block_release(_startupContainerResetBlock);
    _startupContainerResetBlock = nil;
    Block_release(_startupSuccessBlock);
    _startupSuccessBlock = nil;

    [super dealloc];
}
-(void)setStartupSuccessBlock:(void (^)(void))startupSuccessBlock {
    _startupSuccessBlock = Block_copy(startupSuccessBlock);
}

-(void)setStartupContainerResetBlock:(void (^)(void))startupContainerResetBlock {
    _startupContainerResetBlock = Block_copy(startupContainerResetBlock);
}

- (NSString *)containerIDForTeamID:(NSString *)teamID container:(NSString *)container {
    return [NSString stringWithFormat:@"%@.%@", teamID, container];
}

- (NSString*)createNewiCloudUUID {
    CFUUIDRef	uuidObj = CFUUIDCreate(nil);//create a new UUID
    //get the string representation of the UUID
    NSString	*uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    NSLog(@"new UUID generated: %@", uuidString);
    [[NSUserDefaults standardUserDefaults] setValue:uuidString forKey:BPXLiCloudContainerLocalUUID];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return [uuidString autorelease];
}

- (NSString*)iCloudUUID {
    [[NSUserDefaults standardUserDefaults] synchronize];
    RecipesAppDelegate *delegate = (RecipesAppDelegate*) [UIApplication sharedApplication].delegate;
    if(delegate.isFirstRun && ([[NSUserDefaults standardUserDefaults] objectForKey:BPXLiCloudContainerLocalUUID] == nil)) {
        return [self createNewiCloudUUID];
    }
    else {
        // Otherwise, pull our UUID file from NSUserDefaults
        NSString *uuidString = [[NSUserDefaults standardUserDefaults] valueForKey:BPXLiCloudContainerLocalUUID];
        if(uuidString == nil) {
            return [self createNewiCloudUUID];
        }
        else {
            NSLog(@"pulling UUID from defaults: %@", uuidString);
            return uuidString;
        }
    }
}

- (NSString *)createDocumentsDirectoryIfNeeded {
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    if (![[NSFileManager defaultManager] fileExistsAtPath:docDir]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:docDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            docDir = nil;
            NSLog(@"Could not find or create a Documents directory: %@",error);
        }
    }
    return docDir;
}

- (BOOL)createUUIDsDirectoryIfNecessary {
    BOOL ret = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    self.iCloudBaseURL = [fileManager URLForUbiquityContainerIdentifier:nil];
    NSString* uuidsDirectory = [[self.iCloudBaseURL path] stringByAppendingPathComponent:@"uuids"];

    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:uuidsDirectory isDirectory:&isDirectory];
    if (exists && !isDirectory) {
        NSError *removeError = nil;
        BOOL removed = [fileManager removeItemAtPath:uuidsDirectory error:&removeError];
        if (removed) {
            exists = NO;
        } else {
            NSLog(@"Encountered error %@ while cleaning up uuids directory inside iCloud container", removeError);
        }
    }
    
    if(exists == NO) {
        NSString *docDir = [self createDocumentsDirectoryIfNeeded];
        if(docDir != nil) {
            NSString *sourcePath = [docDir stringByAppendingPathComponent:@"uuids"];
            NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
            NSURL *destURL = [NSURL fileURLWithPath:uuidsDirectory];
            
            NSError *fileSystemError = nil;
            [fileManager createDirectoryAtPath:sourcePath withIntermediateDirectories:YES attributes:nil error:&fileSystemError];
            
            NSError *makeUbiquitousError = nil;
            [fileManager setUbiquitous:YES itemAtURL:sourceURL destinationURL:destURL error:&makeUbiquitousError];
            if(makeUbiquitousError != nil) {
                NSLog(@"Encountered error %@ while setting up uuids directory iCloud container", makeUbiquitousError);
            }
            else {
                ret = YES;
            }
        }
    }
    else {
        ret = YES;
    }
    return ret;
}

- (id)init {
    self = [super init];
    if(self != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUbiquitousDocumentList:) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUbiquitousDocumentList:) name:NSMetadataQueryDidUpdateNotification object:nil];   
        self.documentsURLs = [NSMutableDictionary dictionary];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        self.iCloudBaseURL = [fileManager URLForUbiquityContainerIdentifier:nil];
        
//        // If this is first run, create a UUID file and store UUID in NSUserDefaults
        NSString* uuidsDirectory = [[self.iCloudBaseURL path] stringByAppendingPathComponent:@"uuids"];
        [self createUUIDsDirectoryIfNecessary];
        
        NSString *uuid = [self iCloudUUID];
        NSString *filePath = [uuidsDirectory stringByAppendingPathComponent:uuid];
        self.sentinelFileURL = [NSURL fileURLWithPath:filePath];
#if TARGET_IOS        
            self.sentinelDocument = [[BPXLSentinelDocument alloc] initWithFileURL:self.sentinelFileURL];
#else
            self.sentinelDocument = [[BPXLSentinelDocument alloc] init];
            [self.sentinelDocument setFileURL:self.sentinelFileURL];
#endif        
    }
    return self;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.sentinelDocument.delegate = self;
        
        self.metadataQuery = [[[NSMetadataQuery alloc] init] autorelease];
        self.metadataQuery.predicate = [NSPredicate predicateWithFormat:@"%K like '*'", NSMetadataItemFSNameKey];
        self.metadataQuery.searchScopes = [NSArray arrayWithObject:NSMetadataQueryUbiquitousDataScope];
        [self.metadataQuery startQuery];
    });
}


- (void)writeUbiquitousUUIDFile:(void (^)(BOOL success))block {
    self.creatingSentinelFile = YES;
    BOOL uuidsDirectoryExists = [self createUUIDsDirectoryIfNecessary];
    NSString *docDir = [self createDocumentsDirectoryIfNeeded];
    if(docDir != nil) {
        NSString *uuid = [self iCloudUUID];
        NSString *sourcePath = [docDir stringByAppendingPathComponent:uuid];
        NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
        NSError *sourceFileCreationError = nil;
        [[[NSDate date] description] writeToURL:sourceURL atomically:YES encoding:NSUTF8StringEncoding error:&sourceFileCreationError];
        if(sourceFileCreationError != nil) {
            NSLog(@"error creating uuid scratch file in app sandbox");
            block(NO);
        }
        else {
            BOOL ret = YES;
            if(!uuidsDirectoryExists) {
                NSLog(@"Panic - couldn't create uuids directory");
                ret = NO;
            }
            else {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSError *makeUbiquitousError = nil;
                [fileManager setUbiquitous:YES itemAtURL:sourceURL destinationURL:self.sentinelFileURL error:&makeUbiquitousError];
                if(makeUbiquitousError != nil) {
                    NSLog(@"Encountered error %@ while moving uuid file to iCloud container", makeUbiquitousError);
                    ret = NO;
                }
                else {
#if TARGET_IOS        
                    self.sentinelDocument = [[BPXLSentinelDocument alloc] initWithFileURL:self.sentinelFileURL];
#else
                    self.sentinelDocument = [[BPXLSentinelDocument alloc] init];
                    [self.sentinelDocument setFileURL:self.sentinelFileURL];
#endif        
                }
            }
            self.creatingSentinelFile = NO;
            block(ret);
        }
    }
}

- (void)updateUbiquitousDocumentList:(NSNotification*)note {
    NSMutableDictionary *incomingURLs = [NSMutableDictionary dictionary];
    for(NSMetadataItem *item in self.metadataQuery.results) {
        NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
        NSString *urlString = [url absoluteString];
        [incomingURLs setValue:url forKey:urlString];
        if([self.documentsURLs valueForKey:urlString] == nil) {
            NSRange iCloudContainerPrefixRange = [urlString rangeOfString:BPXLiCloudContainerFilePrefix];
            if(iCloudContainerPrefixRange.location != NSNotFound) {
                NSLog(@"found %@", [urlString substringFromIndex:iCloudContainerPrefixRange.length]);
            }
            else {
                NSLog(@"found %@", urlString);
            }
            [self.documentsURLs setValue:url forKey:urlString];
        }
    }
  
    NSArray *keys = [self.documentsURLs allKeys];
    for(NSString *urlString in keys) {
        if([incomingURLs valueForKey:urlString] == nil) {
            NSRange iCloudContainerPrefixRange = [urlString rangeOfString:BPXLiCloudContainerFilePrefix];
            if(iCloudContainerPrefixRange.location != NSNotFound) {
                NSLog(@"%@ was removed", [urlString substringFromIndex:iCloudContainerPrefixRange.length]);
            }
            else {
                NSLog(@"%@ was removed", urlString);
            }

            [self.documentsURLs removeObjectForKey:urlString];
        }
    }
    NSLog(@"total file count is %i", [self.documentsURLs count]);
    if([self.documentsURLs count] == 0) {
        NSLog(@"Container is empty");
    }
    else if([self.documentsURLs count] == 1) {
        NSLog(@"One file remaining");
        // check to see that it's our database
        for(NSString *urlString in [self.documentsURLs allKeys]) {
            NSRange iCloudContainerPrefixRange = [urlString rangeOfString:BPXLiCloudContainerFilePrefix];
            if(iCloudContainerPrefixRange.location != NSNotFound) {
                NSLog(@"file is %@", [urlString substringFromIndex:iCloudContainerPrefixRange.length]);
            }
            else {
                NSLog(@"file is %@", urlString);
            }
        }
    }
    
    if(!self.creatingSentinelFile) {
        if((self.sentinelFileURL != nil) && ([self.documentsURLs valueForKey:[self.sentinelFileURL absoluteString]] == nil)) {
            NSLog(@"Our sentinel file is missing");
            self.monitorState = iCloudMonitorStateDataReset;
            if(self.startupContainerResetBlock != nil) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), self.startupContainerResetBlock);
            }
        }
        else {
            NSLog(@"Our sentinel file is present");
            
            self.monitorState = iCloudMonitorStateReady;
            if(self.startupSuccessBlock != nil) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), self.startupSuccessBlock);
            }
        }
    }
}

- (BOOL)preflightiCloudContainer:(NSURL*)cloudURL {
    return ([self.documentsURLs valueForKey:[self.sentinelFileURL absoluteString]] != nil);
}

@end
