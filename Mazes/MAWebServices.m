//
//  MAWebServices.m
//  Mazes
//
//  Created by Andre Muis on 12/26/13.
//  Copyright (c) 2013 Andre Muis. All rights reserved.
//

#import "MAWebServices.h"

#import "MACloud.h"
#import "MAConstants.h"
#import "MALatestVersion.h"
#import "MAMaze.h"
#import "MAUserCounter.h"
#import "MAUtilities.h"

@interface MAWebServices ()

@property (readonly, strong, nonatomic) Reachability *reachability;
@property (readonly, strong, nonatomic) FatFractal *fatFractal;
@property (readonly, strong, nonatomic) MACloud *cloud;

@property (readwrite, assign, nonatomic) BOOL versionChecked;
@property (readwrite, assign, nonatomic) BOOL hasAttemptedFirstLogin;

@end

@implementation MAWebServices

- (id)initWithReachability: (Reachability *)reachability
{
    self = [super init];
    
    if (self)
    {
        _reachability = reachability;
        
        NSString *baseSSLURLString = nil;
        
        #if TARGET_IPHONE_SIMULATOR
            baseSSLURLString = MALocalBaseSSLURLString;
        #else
            baseSSLURLString = MARemoteBaseSSLURLString;
        #endif
        
        _fatFractal = [[FatFractal alloc] initWithBaseUrl: baseSSLURLString];
        
        _cloud = [[MACloud alloc] init];
        
        _versionChecked = NO;
        _hasAttemptedFirstLogin = NO;
        
        _isDownloadingHighestRatedMazeSummaries = NO;
        _isDownloadingNewestMazeSummaries = NO;
        _isDownloadingYoursMazeSummaries = NO;
    }
    
    return self;
}

- (FFUser *)loggedInUser
{
    return self.fatFractal.loggedInUser;
}

- (BOOL)loggedIn
{
    return self.fatFractal.loggedIn;
}

- (void)autologinWithCompletionHandler: (AutoLoginCompletionHandler)handler
{
    self.cloud.userName = @"TestUser1";
    self.cloud.password = @"Password1";
    
    if (self.cloud.userName == nil)
    {
        [self getUserCounterWithCompletionHandler: ^(MAUserCounter *userCounter, NSError *error)
         {
             if (error == nil)
             {
                 NSString *userName = [NSString stringWithFormat: @"User%d", userCounter.count];
                 NSString *password = [MAUtilities randomStringWithLength: MARandomPasswordLength];
                 
                 [self loginWithUserName: userName
                                password: password
                       completionHandler: ^(NSError *error)
                  {
                      if (error == nil)
                      {
                          self.cloud.userName = userName;
                          self.cloud.password = password;
                          
                          handler(nil);
                      }
                      else
                      {
                          handler(error);
                      }
                  }];
             }
             else
             {
                 handler(error);
             }
         }];
    }
    else
    {
        [self loginWithUserName: self.cloud.userName
                       password: self.cloud.password
              completionHandler: ^(NSError *error)
         {
             if (error == nil)
             {
                 handler(nil);
             }
             else
             {
                 handler(error);
             }
         }];
    }
}

- (void)getUserCounterWithCompletionHandler: (GetUserCounterCompletionHandler)handler
{
    [self.fatFractal getObjFromUri: @"/MAUserCounter"
                        onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
    {
        if (theErr == nil && theResponse.statusCode == 200)
        {
            MAUserCounter *userCounter = (MAUserCounter *)theObj;
         
            handler(userCounter, nil);
        }
        else
        {
            NSError *error = [self errorWithFatFractalError: theErr
                                                description: @"Unable to get user counter from server."
                                                 statusCode: theResponse.statusCode];

            [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
         
            handler(nil, error);
        }
    }];
}

- (void)loginWithUserName: (NSString *)userName password: (NSString *)password completionHandler: (LoginCompletionHandler)handler
{
    [self.fatFractal loginWithUserName: userName
                           andPassword: password
                            onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             handler(nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to login to server."
                                                  statusCode: theResponse.statusCode];

             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(error);
         }

         self.hasAttemptedFirstLogin = YES;
     }];
}


- (void)getTexturesWithCompletionHandler: (GetTexturesCompletionHandler)handler
{
    [self.fatFractal getArrayFromUri: @"/MATexture"
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
    {
        if (theErr == nil && theResponse.statusCode == 200)
        {
            NSArray *textures = (NSArray *)theObj;
            handler(textures, nil);
        }
        else
        {
            NSError *error = [self errorWithFatFractalError: theErr
                                                description: @"Unable to get textures from server."
                                                 statusCode: theResponse.statusCode];

            [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
         
            handler(nil, error);
        }
    }];
}

- (void)getSoundsWithCompletionHandler: (GetSoundsCompletionHandler)handler
{
    [self.fatFractal getArrayFromUri: @"/MASound"
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             NSArray *sounds = (NSArray *)theObj;
             handler(sounds, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get sounds from server."
                                                  statusCode: theResponse.statusCode];

             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
         
             handler(nil, error);
         }
     }];
}


- (void)getUserMazesWithCompletionHandler: (GetUserMazesCompletionHandler)handler
{
    [self.fatFractal getArrayFromUri: [NSString stringWithFormat: @"/FFUser/(userName eq '%@')/BackReferences.MAMaze.user/()", self.fatFractal.loggedInUser.userName]
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             NSArray *userMazes = (NSArray *)theObj;
             
             for (MAMaze *maze in userMazes)
             {
                 [maze decompressLocationsDataAndWallsData];
             }
             
             handler(userMazes, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get user mazes from server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(nil, error);
         }
     }];
}

- (void)getMazeWithMazeId: (NSString *)mazeId completionHandler: (GetMazeCompletionHandler)handler
{
    [self.fatFractal getArrayFromUri: [NSString stringWithFormat: @"/MAMaze/(mazeId eq '%@')", mazeId]
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             NSArray *mazes = (NSArray *)theObj;
             
             MAMaze *maze = mazes[0];
             [maze decompressLocationsDataAndWallsData];
             
             if (mazes.count >= 2)
             {
                 [MAUtilities logWithClass: [self class]
                                    format: @"Invalid number of mazes: %d returned for mazeId: %@", mazes.count, mazeId];
             }
             
             handler(maze, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get maze from server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(nil, error);
         }
     }];
}


- (void)saveMaze: (MAMaze *)maze completionHandler: (SaveMazeCompletionHandler)handler
{
    if ([self.fatFractal metaDataForObj: maze] == nil)
    {
        [maze compressLocationsAndWallsData];
        
        [self.fatFractal createObj: maze
                             atUri: @"/MAMaze"
                        onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
         {
             if (theErr == nil && theResponse.statusCode == 201)
             {
                 handler(nil);
             }
             else
             {
                 NSError *error = [self errorWithFatFractalError: theErr
                                                     description: @"Unable to save maze to server."
                                                      statusCode: theResponse.statusCode];
                 
                 [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
                 
                 handler(error);
             }
         }];
    }
    else
    {
        [self.fatFractal updateObj: maze
                        onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
         {
             if (theErr == nil && theResponse.statusCode == 200)
             {
                 [maze compressLocationsAndWallsData];
                 
                 [self.fatFractal updateBlob: maze.locationsData
                                withMimeType: @"application/octet-stream"
                                      forObj: maze
                                  memberName: @"locationsData"
                                  onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
                  {
                      if (theErr == nil && theResponse.statusCode == 200)
                      {
                          [maze compressLocationsAndWallsData];
                          
                          [self.fatFractal updateBlob: maze.wallsData
                                         withMimeType: @"application/octet-stream"
                                               forObj: maze
                                           memberName: @"wallsData"
                                           onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
                           {
                               if (theErr == nil && theResponse.statusCode == 200)
                               {
                                   handler(nil);
                               }
                               else
                               {
                                   NSError *error = [self errorWithFatFractalError: theErr
                                                                       description: @"Unable to save maze walls data to server."
                                                                        statusCode: theResponse.statusCode];
                                   
                                   [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
                                   
                                   handler(error);
                               }
                           }];
                      }
                      else
                      {
                          NSError *error = [self errorWithFatFractalError: theErr
                                                              description: @"Unable to save maze location data to server."
                                                               statusCode: theResponse.statusCode];
                          
                          [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
                          
                          handler(error);
                      }

                  }];
             }
             else
             {
                 NSError *error = [self errorWithFatFractalError: theErr
                                                     description: @"Unable to save maze to server."
                                                      statusCode: theResponse.statusCode];
                 
                 [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
                 
                 handler(error);
             }
         }];
    }
}


- (void)getHighestRatedMazeSummariesWithCompletionHandler: (GetTopMazeSummariesCompletionHandler)handler
{
    _isDownloadingHighestRatedMazeSummaries = YES;
    
    NSString *uri = [NSString stringWithFormat: @"/ff/ext/getHighestRatedMazeSummaries?userName=%@", self.fatFractal.loggedInUser.userName];
    
    [self.fatFractal getArrayFromUri: uri
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             NSArray *highestRatedTopMazeItems = (NSArray *)theObj;
             
             handler(highestRatedTopMazeItems, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get highest rated top maze items from server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(nil, error);
         }

         _isDownloadingHighestRatedMazeSummaries = NO;
     }];
}

- (void)getNewestMazeSummariesWithCompletionHandler: (GetTopMazeSummariesCompletionHandler)handler
{
    _isDownloadingNewestMazeSummaries = YES;
    
    NSString *uri = [NSString stringWithFormat: @"/ff/ext/getNewestMazeSummaries?userName=%@", self.fatFractal.loggedInUser.userName];
    
    [self.fatFractal getArrayFromUri: uri
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             NSArray *newestTopMazeItems = (NSArray *)theObj;
             
             handler(newestTopMazeItems, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get newest top maze items from server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(nil, error);
         }

         _isDownloadingNewestMazeSummaries = NO;
     }];
}

- (void)getYoursMazeSummariesWithCompletionHandler: (GetTopMazeSummariesCompletionHandler)handler
{
    _isDownloadingYoursMazeSummaries = YES;
    
    NSString *uri = [NSString stringWithFormat: @"/ff/ext/getYoursMazeSummaries?userName=%@", self.fatFractal.loggedInUser.userName];
    
    [self.fatFractal getArrayFromUri: uri
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             NSArray *yoursTopMazeItems = (NSArray *)theObj;
             
             handler(yoursTopMazeItems, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get yours top maze items from server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(nil, error);
         }

         _isDownloadingYoursMazeSummaries = NO;
     }];
}


- (void)saveStartedWithUserName: (NSString *)userName mazeId: (NSString *)mazeId completionHandler: (SaveProgressCompletionHandler)handler
{
    NSString *uri = [NSString stringWithFormat: @"/ff/ext/saveMazeStarted?userName=%@&mazeId=%@", userName, mazeId];
    
    [self.fatFractal getArrayFromUri: uri
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             handler(nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to save started maze progress to server"
                                                  statusCode: theResponse.statusCode];
         
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
         
             handler(error);
         }
     }];
}

- (void)saveFoundExitWithUserName: (NSString *)userName mazeId: (NSString *)mazeId completionHandler: (SaveProgressCompletionHandler)handler
{
    NSString *uri = [NSString stringWithFormat: @"/ff/ext/saveMazeFoundExit?userName=%@&mazeId=%@", userName, mazeId];
    
    [self.fatFractal getArrayFromUri: uri
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             handler(nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to save found maze exit progress to server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(error);
         }
     }];
}

- (void)saveMazeRatingWithUserName: (NSString *)userName mazeId: (NSString *)mazeId rating: (float)rating completionHandler: (SaveRatingCompletionHandler)handler
{
    NSString *uri = [NSString stringWithFormat: @"/ff/ext/saveMazeRating?userName=%@&mazeId=%@&rating=%f", userName, mazeId, rating];
    
    [self.fatFractal getArrayFromUri: uri
                          onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             handler(nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to save maze rating to server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(error);
         }
     }];
}


- (void)getLatestVersionWithCompletionHandler: (GetLatestVersionCompletionHandler)handler
{
    [self.fatFractal getObjFromUri: @"/MALatestVersion"
                        onComplete: ^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse)
     {
         if (theErr == nil && theResponse.statusCode == 200)
         {
             MALatestVersion *latestVersion = (MALatestVersion *)theObj;
             
             handler(latestVersion, nil);
         }
         else
         {
             NSError *error = [self errorWithFatFractalError: theErr
                                                 description: @"Unable to get latest version from server."
                                                  statusCode: theResponse.statusCode];
             
             [MAUtilities logWithClass: [self class] format: [error localizedDescription]];
             
             handler(nil, error);
         }
         
         self.versionChecked = YES;
     }];
}


- (NSError *)errorWithFatFractalError: (NSError *)fatFractalError description: (NSString *)description statusCode: (NSInteger)statusCode
{
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description,
                               MAStatusCodeKey : [NSNumber numberWithInteger: statusCode],
                               NSUnderlyingErrorKey : fatFractalError};
    
    NSError *error = [NSError errorWithDomain: @"com.andremuis.mazes" code: 0 userInfo: userInfo];
    
    return error;
}

@end






















