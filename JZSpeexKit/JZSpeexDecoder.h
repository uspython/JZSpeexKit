//
//  JZSpeexDecoder.m
//  JZSpeexKit
//
//  Created by JeffZhao on 3/25/13.
//  Copyright (c) 2013 JeffZhao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <speex/speex.h>
#import <ogg/ogg.h>
#include <speex/speex_header.h>
#include <speex/speex_stereo.h>
#include <speex/speex_callbacks.h>

#define FRAME_SIZE 160


@interface JZSpeexDecoder : NSObject {

}
- (void)decodeInFilePath:(NSString *)inputFilePath outFilePath:(NSString *)outPutfilePath;

@end
