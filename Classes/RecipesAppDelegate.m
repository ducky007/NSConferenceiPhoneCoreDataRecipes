/*
     File: RecipesAppDelegate.m 
 Abstract: Application delegate that sets up a tab bar controller with two view controllers -- a navigation controller that in turn loads a table view controller to manage a list of recipes, and a unit converter view controller.
  
  Version: 1.5
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2011 Apple Inc. All Rights Reserved. 
  
 */

#import "BPXLSentinelDocument.h"
#import "BPXLSentinelMonitor.h"

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RecipesAppDelegate.h"
#import "RecipeListTableViewController.h"
#import "UnitConverterTableViewController.h"
#import "Recipe.h"

#define kStoreTypeLocal 1
#define kStoreTypeSynced 2

NSString *BPXLFirstRunDateKey = @"BPXLFirstRunDateKey";

NSValueTransformer* _imageTransformer;


@implementation RecipesAppDelegate

@synthesize window;
@synthesize tabBarController;
@synthesize recipeListController;
@synthesize isFirstRun;
@synthesize sentinelMonitor;
@synthesize syncedPersistentStore, localPersistentStore;

// the original example failed to correctly register the NSValueTransformer
+ (void)initialize {
    if (_imageTransformer == nil) {
        _imageTransformer = [[ImageToDataTransformer alloc] init];
        [NSValueTransformer setValueTransformer:_imageTransformer forName:@"ImageToDataTransformer"];
    }
    
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:BPXLFirstRunDateKey] == nil) {
		self.isFirstRun = YES;
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:BPXLFirstRunDateKey];
	}
    recipeListController.managedObjectContext = self.managedObjectContext;
    [window addSubview:tabBarController.view];
    [window makeKeyAndVisible];
}

- (void)flushUnsavedChanges {
    NSError *error = nil;
    if (self.managedObjectContext != nil) {
        if ([self.managedObjectContext hasChanges] && ![self.managedObjectContext save:&error]) {
			/*
			 Replace this implementation with code to handle the error appropriately.
			 
			 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
			 */
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
        } 
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self flushUnsavedChanges];
}

- (void)createSentinelMonitor {
    self.sentinelMonitor = nil;
    
    BPXLSentinelMonitor *monitor = [[BPXLSentinelMonitor alloc] init];
    self.sentinelMonitor = monitor;
    [monitor release];
    
    self.sentinelMonitor.startupContainerResetBlock = ^{
        [self.sentinelMonitor writeUbiquitousUUIDFile:^(BOOL success) {
            
            if(success) {
                // Excellent. We created the sentinel file and are ready to go.
                NSLog(@"sentinel file written");
                
                // Mark our monitor state as ready
                self.sentinelMonitor.monitorState = iCloudMonitorStateReady;
            }
            else {
                NSLog(@"Failed to create uuid");
            }
        }];
    };
    [self.sentinelMonitor start];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [self flushUnsavedChanges];
    [self createSentinelMonitor];
}

/**
 applicationWillTerminate: saves changes in the application's managed object context before the application terminates.
 */
- (void)applicationWillTerminate:(UIApplication *)application {
    [self flushUnsavedChanges];
}


#pragma mark -
#pragma mark Core Data stack
/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
	
    if (managedObjectContext__ != nil) {
        return managedObjectContext__;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];

    if (coordinator != nil) {
// Make life easier by adopting the new NSManagedObjectContext concurrency API
// the NSMainQueueConcurrencyType is good for interacting with views and controllers since
// they are all bound to the main thread anyway
        NSManagedObjectContext* moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        
        [moc performBlockAndWait:^{
// even the post initialization needs to be done within the Block
            [moc setPersistentStoreCoordinator: coordinator];
            [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(mergeChangesFrom_iCloud:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:coordinator];
        }];
        managedObjectContext__ = moc;
    }

    return managedObjectContext__;
}

// NSNotifications are posted synchronously on the caller's thread
// make sure to vector this back to the thread we want, in this case
// the main thread for our views & controller
- (void)mergeChangesFrom_iCloud:(NSNotification *)notification {
	NSManagedObjectContext* moc = [self managedObjectContext];

// this only works if you used NSMainQueueConcurrencyType
// otherwise use a dispatch_async back to the main thread yourself
   [moc performBlock:^{
       
       // this takes the NSPersistentStoreDidImportUbiquitousContentChangesNotification
       // and transforms the userInfo dictionary into something that
       // -[NSManagedObjectContext mergeChangesFromContextDidSaveNotification:] can consume
       // then it posts a custom notification to let detail views know they might want to refresh.
       // The main list view doesn't need that custom notification because the NSFetchedResultsController is
       // already listening directly to the NSManagedObjectContext
       [moc mergeChangesFromContextDidSaveNotification:notification]; 
       
       NSNotification* refreshNotification = [NSNotification notificationWithName:@"RefreshAllViews" object:self  userInfo:[notification userInfo]];
       
       [[NSNotificationCenter defaultCenter] postNotification:refreshNotification];
    }];
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel__ != nil) {
        return managedObjectModel__;
    }
    managedObjectModel__ = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel__;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	
    if (persistentStoreCoordinator__ != nil) {
        return persistentStoreCoordinator__;
    }
    
    persistentStoreCoordinator__ = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
// prep the store path and bundle stuff here since NSBundle isn't totally thread safe
    NSPersistentStoreCoordinator* psc = persistentStoreCoordinator__;
	NSString *storePath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"Recipes.sqlite"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
// this needs to match the entitlements and provisioning profile
        NSURL *cloudURL = [fileManager URLForUbiquityContainerIdentifier:nil];
        NSString* coreDataCloudContent = [[cloudURL path] stringByAppendingPathComponent:@"recipes_v3"];
        cloudURL = [NSURL fileURLWithPath:coreDataCloudContent];

//  The API to turn on Core Data iCloud support here.
        NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:@"com.apple.coredata.examples.recipes.3", NSPersistentStoreUbiquitousContentNameKey, cloudURL, NSPersistentStoreUbiquitousContentURLKey, [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,nil];

        NSError *error = nil;

        [psc lock];
        if (![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error]) {

            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }    
        [psc unlock];
        [self createSentinelMonitor];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"asynchronously added persistent store!");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RefetchAllDatabaseData" object:self userInfo:nil];
        });
    });
    
    return persistentStoreCoordinator__;
}


#pragma mark -
#pragma mark Application's documents directory

/**
 Returns the path to the application's documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc {
    [managedObjectContext__ release];
    [managedObjectContext__ release];
    [managedObjectContext__ release];
    
    [recipeListController release];
    [tabBarController release];
    [window release];
    [super dealloc];
}

//
//    - (Recipe*)insertRecipeOfType:(BOOL)isSynced withMOC:(NSManagedObjectContext *)moc{
//        NSString *entityName = isSynced ? @"SyncedRecipe" : @"LocalRecipe";
//        Recipe *recipe = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
//        
//        if(isSynced) {
//            [moc assignObject:recipe toPersistentStore:self.syncedPersistentStore];
//        }
//        else {
//            [moc assignObject:recipe toPersistentStore:self.localPersistentStore];
//        }
//        
//        return recipe;
//    }
//
//
//
//
//    //#define kStoreTypeLocal 1
//    //#define kStoreTypeSynced 2
//    - (NSArray *)recipesFromStore:(NSInteger)storeType 
//                   sortDescriptor:(NSSortDescriptor *)aSortDescriptor 
//                              moc:(NSManagedObjectContext *)moc{
//        
//        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
//        [request setEntity:[NSEntityDescription entityForName:@"Recipe" inManagedObjectContext:moc]];
//        if(storeType == kStoreTypeSynced) {
//            [request setAffectedStores:[NSArray arrayWithObject:self.syncedPersistentStore]];
//        }
//        else if(storeType == kStoreTypeLocal) {
//            [request setAffectedStores:[NSArray arrayWithObject:self.localPersistentStore]];
//        }
//        
//        if (aSortDescriptor != nil)
//            [request setSortDescriptors:[NSArray arrayWithObject:aSortDescriptor]];
//        NSError *error = nil;
//        NSArray *recipes = [moc executeFetchRequest:request error:&error];	
//        if(error != nil) {
//            NSLog(@"Error %@ while fetching recipes", error);
//        }
//        return recipes;
//    }



@end
