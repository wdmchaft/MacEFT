//
//  EveShip.h
//  MacEFT
//
//  Created by John Kraal on 3/26/11.
//  Copyright 2011 Netframe. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SQLBridge;

@interface EveShip : NSObject {
    NSNumber * highSlots;
    NSNumber * medSlots;
    NSNumber * lowSlots;
    
    NSNumber * missileHardpoints;
    NSNumber * turretHardpoints;

    NSNumber * basePowergrid;
    NSNumber * baseCPU;

}

- (id)initWithBridge:(SQLBridge *)bridge andShipID:(NSNumber *)shipID;
+ (id)shipWithBridge:(SQLBridge *)bridge andShipID:(NSNumber *)shipID;

@property (retain) NSNumber * highSlots, * medSlots, * lowSlots, * missileHardPoints, * turretHardpoints, * basePowergrid, * baseCPU;


@end
