//
//  PenteGame.h
//  penteLive
//
//  Created by rainwolf on 25/01/2018.
//  Copyright © 2018 Triade. All rights reserved.
//

#ifndef PenteGame_h
#define PenteGame_h

#endif /* PenteGame_h */
typedef int AbstractBoard[19];

@interface PenteGame : NSObject {

    AbstractBoard *abstractBoard;

    int whiteCaptures, blackCaptures;
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *>
                                        *> *goStoneGroupIDsByPlayer;
    NSMutableDictionary<
        NSNumber *,
        NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
        *goStoneGroupsByPlayerAndID;
}
@property(nonatomic) AbstractBoard *abstractBoard;
@property(atomic, assign) int whiteCaptures, blackCaptures;
@property(nonatomic, retain)
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *>
                                        *> *goStoneGroupIDsByPlayer;
@property(nonatomic, retain) NSMutableDictionary<
    NSNumber *, NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
    *goStoneGroupsByPlayerAndID;

+ (NSString *)getGameName:(int)gameInt;

@end
