//
//  PenteGame.m
//  penteLive
//
//  Created by rainwolf on 25/01/2018.
//  Copyright © 2018 Triade. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PenteGame.h"

struct Capture {
    int color;
    int position;
};


@implementation PenteGame {
    NSMutableArray *captures;
}
@synthesize abstractBoard;
@synthesize whiteCaptures, blackCaptures;
@synthesize goStoneGroupsByPlayerAndID;
@synthesize goStoneGroupIDsByPlayer;













-(void) detectCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol {
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, myColor = (opponentColor == 1) ? 2 : 1;
    if ((i-3) > -1) {
        if (abstractBoard[i-3][j] == myColor) {
            if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor)) {
                abstractBoard[i-1][j] = 0;
                abstractBoard[i-2][j] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i-3) > -1) && ((j-3) > -1)) {
        if (abstractBoard[i-3][j-3] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i-2][j-2] == opponentColor)) {
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i-2][j-2] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if ((j-3) > -1) {
        if (abstractBoard[i][j-3] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j-2] == opponentColor)) {
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j-2] = 0;
                capture.color = opponentColor;
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i+3) < 19) && ((j-3) > -1)) {
        if (abstractBoard[i+3][j-3] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i+2][j-2] = 0;
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if ((i+3) < 19) {
        if (abstractBoard[i+3][j] == myColor) {
            if ((abstractBoard[i+1][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor)) {
                abstractBoard[i+1][j] = 0;
                abstractBoard[i+2][j] = 0;
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i+3) < 19) && ((j+3) < 19)) {
        if (abstractBoard[i+3][j+3] == myColor) {
            if ((abstractBoard[i+1][j+1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i+2][j+2] = 0;
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if ((j+3) < 19) {
        if (abstractBoard[i][j+3] == myColor) {
            if ((abstractBoard[i][j+1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j+2] = 0;
                capture.color = opponentColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i-3) > -1) && ((j+3) < 19)) {
        if (abstractBoard[i-3][j+3] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor)) {
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i-2][j+2] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
}


-(void) detectKeryoCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol {
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, myColor = (opponentColor == 1) ? 2 : 1;
    if ((i-4) > -1) {
        if (abstractBoard[i-4][j] == myColor) {
            if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i-3][j] == opponentColor)) {
                abstractBoard[i-1][j] = 0;
                abstractBoard[i-2][j] = 0;
                abstractBoard[i-3][j] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-3)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i-4) > -1) && ((j-4) > -1)) {
        if (abstractBoard[i-4][j-4] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i-3][j-3] == opponentColor)) {
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i-2][j-2] = 0;
                abstractBoard[i-3][j-3] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-3)*19 + (j-3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if ((j-4) > -1) {
        if (abstractBoard[i][j-4] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j-3] == opponentColor)) {
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j-2] = 0;
                abstractBoard[i][j-3] = 0;
                capture.color = opponentColor;
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i+4) < 19) && ((j-4) > -1)) {
        if (abstractBoard[i+4][j-4] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor) && (abstractBoard[i+3][j-3] == opponentColor)) {
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i+2][j-2] = 0;
                abstractBoard[i+3][j-3] = 0;
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+3)*19 + (j-3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if ((i+4) < 19) {
        if (abstractBoard[i+4][j] == myColor) {
            if ((abstractBoard[i+1][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor) && (abstractBoard[i+3][j] == opponentColor)) {
                abstractBoard[i+1][j] = 0;
                abstractBoard[i+2][j] = 0;
                abstractBoard[i+3][j] = 0;
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+3)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i+4) < 19) && ((j+4) < 19)) {
        if (abstractBoard[i+4][j+4] == myColor) {
            if ((abstractBoard[i+1][j+1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor) && (abstractBoard[i+3][j+3] == opponentColor)) {
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i+2][j+2] = 0;
                abstractBoard[i+3][j+3] = 0;
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+3)*19 + (j+3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if ((j+4) < 19) {
        if (abstractBoard[i][j+4] == myColor) {
            if ((abstractBoard[i][j+1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor) && (abstractBoard[i][j+3] == opponentColor)) {
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j+2] = 0;
                abstractBoard[i][j+3] = 0;
                capture.color = opponentColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i-4) > -1) && ((j+4) < 19)) {
        if (abstractBoard[i-4][j+4] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor) && (abstractBoard[i-3][j+3] == opponentColor)) {
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i-2][j+2] = 0;
                abstractBoard[i-3][j+3] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-3)*19 + (j+3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
}


-(BOOL) detectPoof: (int) myColor atPosition: (int) rowCol {
    BOOL poof = NO;
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, opponentColor = (myColor == 1) ? 2 : 1, capturesLength = (int) [captures count];
    if (((i-2) > -1) && ((i+1) < 19)) {
        if (abstractBoard[i-1][j] == myColor) {
            if ((abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i+1][j] == opponentColor)) {
                poof = YES;
                abstractBoard[i-1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                
            }
        }
    }
    if (((i-2) > -1) && ((j-2) > -1) && ((i+1) < 19) && ((j+1) < 19)) {
        if (abstractBoard[i-1][j-1] == myColor) {
            if ((abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i+1][j+1] == opponentColor)) {
                poof = YES;
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((j-2) > -1) && ((j+1) < 19)) {
        if (abstractBoard[i][j-1] == myColor) {
            if ((abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j+1] == opponentColor)) {
                poof = YES;
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i-1) > -1) && ((j-2) > -1) && ((i+2) < 19) && ((j+1) < 19)) {
        if (abstractBoard[i+1][j-1] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                poof = YES;
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i+2) < 19) && ((i-1) > -1)) {
        if (abstractBoard[i+1][j] == myColor) {
            if ((abstractBoard[i+2][j] == opponentColor) && (abstractBoard[i-1][j] == opponentColor)) {
                poof = YES;
                abstractBoard[i+1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i-1) > -1) && ((j-1) > -1) && ((i+2) < 19) && ((j+2) < 19)) {
        if (abstractBoard[i+1][j+1] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                poof = YES;
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((j+2) < 19) && ((j-1) > -1)) {
        if (abstractBoard[i][j+1] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                poof = YES;
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i-2) > -1) && ((j-1) > -1) && ((i+1) < 19) && ((j+2) < 19)) {
        if (abstractBoard[i-1][j+1] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor)) {
                poof = YES;
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    
    if (poof) {
        if (myColor == 1) {
            ++whiteCaptures;
        } else {
            ++blackCaptures;
        }
        capture.color = myColor;
        capture.position = i*19 + j;
        [captures insertObject:[NSValue value:&capture withObjCType:@encode(struct Capture)] atIndex: capturesLength];
    }
    return poof;
}

-(BOOL) detectPenteOf: (int) color atPosition: (int) rowCol {
    BOOL pente = NO;
    int penteCounter = 1;
    int row = rowCol / 19, col = rowCol % 19, i, j;
    i = row - 1;
    j = col;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i -= 1;
    }
    i = row + 1;
    j = col;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i += 1;
    }
    if (pente) {
        return pente;
    }
    penteCounter = 1;
    i = row;
    j = col - 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j -= 1;
    }
    i = row;
    j = col + 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j += 1;
    }
    if (pente) {
        return pente;
    }
    penteCounter = 1;
    i = row - 1;
    j = col - 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j -= 1;
        i -= 1;
    }
    i = row + 1;
    j = col + 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i += 1;
        j += 1;
    }
    if (pente) {
        return pente;
    }
    penteCounter = 1;
    i = row - 1;
    j = col + 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j += 1;
        i -= 1;
    }
    i = row + 1;
    j = col - 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i += 1;
        j -= 1;
    }
    
    return pente;
}




@end
