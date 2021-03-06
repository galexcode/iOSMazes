//
//  MAMaze.m
//  Mazes
//
//  Created by Andre Muis on 4/18/10.
//  Copyright 2010 Andre Muis. All rights reserved.
//

#import <BZipCompression/BZipCompression.h>

#import "MAMaze.h"

#import "MACanvasStyle.h"
#import "MACoordinate.h"
#import "MASize.h"
#import "MASound.h"
#import "MATexture.h"
#import "MAUtilities.h"
#import "MAWall.h"

@interface MAMaze ()

@property (readonly, strong, nonatomic) NSMutableArray *locations;
@property (readonly, strong, nonatomic) NSMutableArray *walls;

@end

@implementation MAMaze

- (id)init
{
	self = [super init];
	
    if (self)
	{
        _mazeId = nil;
        _user = nil;
        _name = nil;
        _size = nil;
        _public = NO;
        _backgroundSound = nil;
        _wallTexture = nil;
        _floorTexture = nil;
        _ceilingTexture = nil;
        _averageRating = 0.0;
        _ratingCount = 0;
        _modifiedAt = nil;
        
        _locations = [[NSMutableArray alloc] init];
        _locationsData = nil;
        _previousSelectedLocation = nil;
        _currentSelectedLocation = nil;
        
        _walls = [[NSMutableArray alloc] init];
        _wallsData = nil;
        _previousSelectedWall = nil;
        _currentSelectedWall = nil;
	}
	
	return self;
}

- (BOOL)shouldSerialize: (NSString *)propertyName
{
    if ([propertyName isEqualToString: @"rows"] ||
        [propertyName isEqualToString: @"columns"] ||
        [propertyName isEqualToString: @"locations"] ||
        [propertyName isEqualToString: @"startLocation"] ||
        [propertyName isEqualToString: @"endLocation"] ||
        [propertyName isEqualToString: @"previousSelectedLocation"] ||
        [propertyName isEqualToString: @"currentSelectedLocation"] ||
        [propertyName isEqualToString: @"walls"] ||
        [propertyName isEqualToString: @"previousSelectedWall"] ||
        [propertyName isEqualToString: @"currentSelectedWall"])
    {
        return NO;
    }
    else
    {        
        return YES;
    }
}

- (NSUInteger)rows
{
    return self.size.rows;
}

- (void)setRows: (NSUInteger)rows
{
    self.size.rows = rows;
}

- (NSUInteger)columns
{
    return self.size.columns;
}

- (void)setColumns: (NSUInteger)columns
{
    self.size.columns = columns;
}

- (MALocation *)startLocation
{
    return [self locationWithAction: MALocationActionStart];
}

- (MALocation *)endLocation
{
    return [self locationWithAction: MALocationActionEnd];
}

+ (MAMaze *)mazeWithLoggedInUser: (FFUser *)loggedInUser
                            rows: (NSUInteger)rows
                         columns: (NSUInteger)columns
                 backgroundSound: (MASound *)backgroundSound
                     wallTexture: (MATexture *)wallTexture
                    floorTexture: (MATexture *)floorTexture
                  ceilingTexture: (MATexture *)ceilingTexture
{
    MAMaze *maze = [[MAMaze alloc] init];
    
    maze.mazeId = [MAUtilities uuid];
    maze.user = loggedInUser;
    maze.name = @"";
    
    maze.size = [[MASize alloc] init];
    maze.rows = rows;
    maze.columns = columns;
    
    maze.public = NO;
    maze.backgroundSound = backgroundSound;
    maze.wallTexture = wallTexture;
    maze.floorTexture = floorTexture;
    maze.ceilingTexture = ceilingTexture;
    maze.averageRating = -1;
    maze.ratingCount = 0;
    maze.modifiedAt = [NSDate date];
    
    maze.locationsData = nil;
    maze.previousSelectedLocation = nil;
    maze.currentSelectedLocation = nil;

    maze.wallsData = nil;
    maze.previousSelectedWall = nil;
    maze.currentSelectedWall = nil;
    
    [maze populateLocationsAndWalls];
    
    return maze;
}

- (void)resetWithRows: (NSUInteger)rows
              columns: (NSUInteger)columns
      backgroundSound: (MASound *)backgroundSound
          wallTexture: (MATexture *)wallTexture
         floorTexture: (MATexture *)floorTexture
       ceilingTexture: (MATexture *)ceilingTexture
{
    self.name = @"";
    
    self.rows = rows;
    self.columns = columns;
    
    self.public = NO;
    self.backgroundSound = backgroundSound;
    self.wallTexture = wallTexture;
    self.floorTexture = floorTexture;
    self.ceilingTexture = ceilingTexture;
    
    self.locationsData = nil;
    self.previousSelectedLocation = nil;
    self.currentSelectedLocation = nil;
    
    self.wallsData = nil;
    self.previousSelectedWall = nil;
    self.currentSelectedWall = nil;
    
    [self populateLocationsAndWalls];
}

- (void)populateLocationsAndWalls
{
    [self.locations removeAllObjects];
    [self.walls removeAllObjects];
    
	for (int row = 1; row <= self.rows + 1; row = row + 1)
	{
		for (int column = 1; column <= self.columns + 1; column = column + 1)
		{
            MACoordinate *coordinate = [[MACoordinate alloc] init];
            coordinate.row = row;
            coordinate.column = column;
            
			MALocation *location = [[MALocation alloc] init];
            location.locationId = [MAUtilities uuid];
			location.coordinate = coordinate;
            location.action = MALocationActionDoNothing;
            location.message = @"";
            
			[self.locations addObject: location];
            
            if (column <= self.columns)
            {
                MAWall *northWall = [[MAWall alloc] init];
                northWall.coordinate = coordinate;
                northWall.direction = MADirectionNorth;
                
                if (row == 1 || row == self.rows + 1)
                {
                    northWall.type = MAWallBorder;
                }
                else
                {
                    northWall.type = MAWallSolid;
                }
                
                [self.walls addObject: northWall];
            }
            
            if (row <= self.rows)
            {
                MAWall *westWall = [[MAWall alloc] init];
                westWall.coordinate = coordinate;
                westWall.direction = MADirectionWest;
                
                if (column == 1 || column == self.columns + 1)
                {
                    westWall.type = MAWallBorder;
                }
                else
                {
                    westWall.type = MAWallSolid;
                }

                [self.walls addObject: westWall];
            }
		}
	}
}

- (MALocation *)locationWithLocationId: (NSString *)locationId
{
    MALocation *location = nil;
    
    NSUInteger index = [self.locations indexOfObjectPassingTest: ^BOOL(id obj, NSUInteger idx, BOOL *stop)
                        {
                            return [((MALocation *)obj).locationId isEqualToString: locationId];
                        }];
    
    if (index != NSNotFound)
    {
        location = [self.locations objectAtIndex: index];
    }
    else
    {
        [MAUtilities logWithClass: [self class] format: @"Unable to find location with locationId: %d", locationId];
    }
    
    return location;
}

- (MALocation *)locationWithRow: (NSUInteger)row column: (NSUInteger)column
{
	MALocation *locationRet = nil;
	
	for (MALocation *location in self.locations)
	{
		if (location.row == row && location.column == column)
        {
			locationRet = location;
        }
	}
	
	return locationRet;
}

- (MALocation *)locationWithAction: (MALocationActionType)action
{
	MALocation *locationRet = nil;
	
	for (MALocation *location in self.locations)
	{
		if (location.action == action)
        {
			locationRet = location;
        }
	}
    
	return locationRet;
}

- (BOOL)isValidLocationWithRow: (NSUInteger)row
                        column: (NSUInteger)column
{
    if (row >= 1 && row <= self.rows && column >= 1 && column <= self.columns)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isValidCornerLocationWithRow: (NSUInteger)row
                              column: (NSUInteger)column
{
    if (row >= 2 && row <= self.rows && column >= 2 && column <= self.columns)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}


- (NSArray *)allLocations
{
    return self.locations;
}

- (void)removeAllLocations
{
	[self.locations removeAllObjects];
}

- (void)compressLocationsAndWallsData
{
    NSError *error = nil;

    // locations
    NSData *decompressedLocationsData = [NSKeyedArchiver archivedDataWithRootObject: self.locations];
    
    NSData *compressedLocationsData = [BZipCompression compressedDataWithData: decompressedLocationsData
                                                                    blockSize: BZipDefaultBlockSize
                                                                   workFactor: BZipDefaultWorkFactor
                                                                        error: &error];

    if (error != nil)
    {
        [MAUtilities logWithClass: [self class] format: @"Unable to compress locations data. Error: %@", error];
    }
    
    self.locationsData = compressedLocationsData;

    // walls
    NSData *decompressedWallsData = [NSKeyedArchiver archivedDataWithRootObject: self.walls];
    
    NSData *compressedWallsData = [BZipCompression compressedDataWithData: decompressedWallsData
                                                                blockSize: BZipDefaultBlockSize
                                                               workFactor: BZipDefaultWorkFactor
                                                                    error: &error];
    
    if (error != nil)
    {
        [MAUtilities logWithClass: [self class] format: @"Unable to compress walls data. Error: %@", error];
    }
    
    self.wallsData = compressedWallsData;
}

- (void)decompressLocationsDataAndWallsData
{
    NSError *error = nil;

    //locations
    NSData *compressedLocationsData = self.locationsData;
    
    NSData *decompressedLocationsData = [BZipCompression decompressedDataWithData: compressedLocationsData
                                                                            error: &error];
    
    if (error != nil)
    {
        [MAUtilities logWithClass: [self class] format: @"Unable to decompress locations data. Error: %@", error];
    }
    
    _locations = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: decompressedLocationsData];

    // walls
    NSData *compressedWallsData = self.wallsData;
    
    NSData *decompressedWallsData = [BZipCompression decompressedDataWithData: compressedWallsData
                                                                        error: &error];
    
    if (error != nil)
    {
        [MAUtilities logWithClass: [self class] format: @"Unable to decompress walls data. Error: %@", error];
    }
    
    _walls = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: decompressedWallsData];
}

- (MAWall *)wallWithRow: (NSUInteger)row
                 column: (NSUInteger)column
              direction: (MADirectionType)direction
{
    switch (direction)
    {
        case MADirectionNorth:
        case MADirectionWest:
            break;
            
        case MADirectionSouth:
            row = row + 1;
            direction = MADirectionNorth;
            break;
            
        case MADirectionEast:
            column = column + 1;
            direction = MADirectionWest;
            break;
            
        default:
            [MAUtilities logWithClass: [self class] format: @"Direction set to an illegal value: %d", direction];
            break;
    }
    
	MAWall *wallRet = nil;
	
    for (MAWall *wall in self.walls)
    {
        if (wall.row == row && wall.column == column && wall.direction == direction)
        {
            wallRet = wall;
        }
    }
    
    if (wallRet == nil)
    {
        [MAUtilities logWithClass: [self class] format: @"Could not find wall with row: %d column: %d direction: %d", row, column, direction];
    }
    
	return wallRet;
}

- (BOOL)isValidWallWithRow: (NSUInteger)row
                    column: (NSUInteger)column
                 direction: (MADirectionType)direction;
{
    if ((row >= 1 && row <= self.rows && column >= 1 && column <= self.columns) ||
        (row == 0 && column >= 1 && column <= self.columns && direction == MADirectionSouth) ||
        (row == self.rows + 1 && column >= 1 && column <= self.columns && direction == MADirectionNorth) ||
        (column == 0 && row >= 1 && row <= self.rows && direction == MADirectionEast) ||
        (column == self.columns + 1 && row >= 1 && row <= self.rows && direction == MADirectionWest))
        return YES;
    else
        return NO;
}

- (NSArray *)allWalls
{
    return self.walls;
}

- (BOOL)isSurroundedByWallsWithLocation: (MALocation *)location
{
	MAWall *wallNorth = [self wallWithRow: location.row
                                   column: location.column
                                direction: MADirectionNorth];
    
	MAWall *wallSouth = [self wallWithRow: location.row
                                   column: location.column
                                direction: MADirectionSouth];
    
	MAWall *wallEast = [self wallWithRow: location.row
                                  column: location.column
                               direction: MADirectionEast];
    
	MAWall *wallWest = [self wallWithRow: location.row
                                  column: location.column
                               direction: MADirectionWest];
    
	if ((wallNorth.type == MAWallSolid || wallNorth.type == MAWallBorder || wallNorth.type == MAWallInvisible) &&
		(wallEast.type == MAWallSolid || wallEast.type == MAWallBorder || wallEast.type == MAWallInvisible) &&
		(wallSouth.type == MAWallSolid || wallSouth.type == MAWallBorder || wallSouth.type == MAWallInvisible) &&
		(wallWest.type == MAWallSolid || wallWest.type == MAWallBorder || wallWest.type == MAWallInvisible))
	{
		return YES;
	}
    else
    {
        return NO;
    }
}

- (BOOL)isInnerWall: (MAWall *)wall
{
	if ((wall.column == 1 && wall.row >= 2 && wall.row <= self.rows && wall.direction == MADirectionNorth) ||
		(wall.row == 1 && wall.column >= 2 && wall.column <= self.columns && wall.direction == MADirectionWest) ||
		(wall.column >= 2 && wall.column <= self.columns && wall.row >= 2 && wall.row <= self.rows))
    {
		return YES;
    }
	else
    {
		return NO;
    }
}

- (BOOL)isEqual: (id)object
{
    if ([object isKindOfClass: [MAMaze class]])
    {
        MAMaze *maze = object;
        
        return [self.mazeId isEqualToString: maze.mazeId];
    }
    
    return NO;
}

- (NSString *)description
{
    NSString *desc = [NSString stringWithFormat: @"<%@: %p;\n", [self class], self];
    desc = [desc stringByAppendingFormat: @"\tmazeId = %@;\n", self.mazeId];
    desc = [desc stringByAppendingFormat: @"\tuser = %@;\n", self.user];
    desc = [desc stringByAppendingFormat: @"\tname = %@;\n", self.name];
    desc = [desc stringByAppendingFormat: @"\tsize = %@;\n", self.size];
    desc = [desc stringByAppendingFormat: @"\tpublic = %d;\n", self.public];
    desc = [desc stringByAppendingFormat: @"\tbackgroundSound.soundId = %@;\n", self.backgroundSound.soundId];
    desc = [desc stringByAppendingFormat: @"\twallTexture.textureId = %@;\n", self.wallTexture.textureId];
    desc = [desc stringByAppendingFormat: @"\tfloorTexture.textureId = %@;\n", self.floorTexture.textureId];
    desc = [desc stringByAppendingFormat: @"\tceilingTexture.textureId = %@;\n", self.ceilingTexture.textureId];
    desc = [desc stringByAppendingFormat: @"\taverageRating = %f;\n", self.averageRating];
    desc = [desc stringByAppendingFormat: @"\tratingCount = %d;\n", self.ratingCount];

    desc = [desc stringByAppendingFormat: @"\tstartLocation = %@;\n", self.startLocation];
    desc = [desc stringByAppendingFormat: @"\tendLocation = %@;\n", self.endLocation];

    desc = [desc stringByAppendingFormat: @"\tpreviousSelectedLocation = %@;\n", self.previousSelectedLocation];
    desc = [desc stringByAppendingFormat: @"\tcurrentSelectedLocation = %@;\n", self.currentSelectedLocation];

    desc = [desc stringByAppendingFormat: @"\tpreviousSelectedWall = %@;\n", self.previousSelectedWall];
    desc = [desc stringByAppendingFormat: @"\tcurrentSelectedWall = %@;\n", self.currentSelectedWall];
   
    desc = [desc stringByAppendingFormat: @"\tlocationsData.length = %d;\n", self.locationsData.length];
    
    desc = [desc stringByAppendingFormat: @"\tlocations = %@;\n", self.locations];
    
    desc = [desc stringByAppendingFormat: @"\twalls = %@>", self.walls];

    return desc;
}

@end




















