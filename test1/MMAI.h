//
//  MMAI.h
//  penteLive
//
//  Created by rainwolf on 08/06/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#ifndef MMAI_h
#define MMAI_h

#endif /* MMAI_h */

@interface MMAI : NSObject {
    NSMutableArray<NSNumber *> *moves;
    BOOL useOpeningBook;
    int seat, level, game;
    short int *scores, *table, *obk;
    int *pFk, *pFh, *pTr, *pTm, *pTo, *pTi, *pfhn;
}
@property(retain, nonatomic, readwrite) NSMutableArray<NSNumber *> *moves;
@property(assign, atomic, readwrite, getter=useOpeningBook,
          setter=setUseOpeningBook:) BOOL useOpeningBook;
@property(assign, readwrite, atomic, setter=setSeat:, getter=seat) int seat;
@property(assign, readwrite, atomic) int game;
@property(assign, readwrite, atomic, setter=setLevel:, getter=level) int level;
@property short int *scores, *table, *obk;
@property int *pFk, *pFh, *pTr, *pTm, *pTo, *pTi, *pfhn;

- (void)reset;
- (void)addMove:(int)move;
- (int)getMove;

@end
