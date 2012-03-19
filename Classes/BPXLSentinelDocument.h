//
//  BPXLSentinelDocument.h
//  Recipes
//
//  Created by Daniel Pasco on 1/21/12.
//  Copyright (c) 2012 Black Pixel. All rights reserved.
//

#ifdef TARGET_IOS
#import <UIKit/UIKit.h>
#define BPXL_DOCUMENT_FILE_PRESENTER UIDocument
#else
#import <Foundation/Foundation.h>
#define BPXL_DOCUMENT_FILE_PRESENTER NSDocument
#endif

#ifdef TARGET_IOS
#define BPXL_DOCUMENT_CHANGE_DONE UIDocumentChangeDone
#else
#define BPXL_DOCUMENT_CHANGE_DONE NSChangeDone
#endif

@class BPXLSentinelMonitor;

@interface BPXLSentinelDocument : BPXL_DOCUMENT_FILE_PRESENTER

@property (nonatomic, assign) BPXLSentinelMonitor *delegate;
@property (nonatomic, retain) NSString *contents;
@end
