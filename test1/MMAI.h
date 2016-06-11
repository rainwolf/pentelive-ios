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
    int seat, level, game;
}
@property(retain, nonatomic, readwrite) NSMutableArray<NSNumber *> *moves;
@property(assign, readwrite, atomic, setter=setSeat:, getter=seat) int seat;
@property(assign, readwrite, atomic) int game;
@property(assign, readwrite, atomic, setter=setLevel:, getter=level) int level;

-(void) reset;
-(void) addMove: (int) move;
-(int) getMove;

@end

