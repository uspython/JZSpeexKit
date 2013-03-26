//
//  JZViewController.m
//  JZSpeexKitDemo
//
//  Created by JeffZhao on 3/25/13.
//  Copyright (c) 2013 JeffZhao. All rights reserved.
//

#import "JZViewController.h"
#import <JZSpeexKit.h>

@interface JZViewController ()
-(IBAction)toggleEncodeCafFile:(id)sender;
-(IBAction)toggleDncodeSpxFile:(id)sender;
@end

@implementation JZViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)toggleEncodeCafFile:(id)sender
{
    JZSpeexEncoder* encoder = [[JZSpeexEncoder alloc] init];
    NSArray* searchPathArr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* outPutPath = [[searchPathArr objectAtIndex:0] stringByAppendingPathComponent:@"encodespx.spx"];
    /**
     inputcaf.wav
     simple rate: 8000
     channel: 1(mono)
     PCMBitDepth: 16
     */
    NSString* inputFilePath = [[NSBundle mainBundle] pathForResource:@"inputcaf" ofType:@"wav"];
    [encoder encodeInFilePath:inputFilePath outFilePath:outPutPath];
}
-(void)toggleDncodeSpxFile:(id)sender
{
    JZSpeexDecoder* decoder = [[JZSpeexDecoder alloc] init];
    NSArray* searchPathArr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* outPutPath = [[searchPathArr objectAtIndex:0] stringByAppendingPathComponent:@"decodecaf.wav"];
    NSString* inputFilePath = [[NSBundle mainBundle] pathForResource:@"inputspx" ofType:@"spx"];
    [decoder decodeInFilePath:inputFilePath outFilePath:outPutPath];
}

@end
