//
//  ExceptionCatcher.h
//  Vskit
//
//  Created by Stephen zake on 2019/5/28.
//  Copyright © 2019 Transsnet. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_INLINE NSException * _Nullable tryBlock(void(^_Nonnull tryBlock)(void)) {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        return exception;
    }
    return nil;
}

