JZSpeexKit
==========

An SpeexKit which can encode wav(caf) file to spx and decode spx to wav(caf). Based on speex offical demo: speexenc.c and speexdec.c. 


Add JZSpeexKit as a target dependency. [Here](http://stackoverflow.com/a/9726445/1343200) are some great step-by-step instructions on how to add static library dependencies in more recent versions of Xcode. And do not forget setting HEADER SEARCHING PATH in TARGET BUILD SETTINGS. 

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
