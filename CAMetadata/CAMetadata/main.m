//
//  main.m
//  CAMetadata
//
//  Created by Brian Ball on 3/10/13.
//  Copyright (c) 2013 Brian Ball. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        if(argc < 2){
            printf("Usage: CAMetadata /full/path/to/audiodata\n");
            return -1;
        }
        
        NSString *audioFilePath = [[NSString stringWithUTF8String:argv[1]] stringByExpandingTildeInPath];
        
        NSURL *audioUrl = [NSURL fileURLWithPath:audioFilePath];
        
        AudioFileID audioFile;
        OSStatus theErr = noErr;
        
        theErr = AudioFileOpenURL((__bridge CFURLRef) audioUrl, kAudioFileReadPermission, 0, &audioFile);
        
        assert(theErr == noErr);
        
        UInt32 dictionarySize;
        CFDictionaryRef dictionary;
 
        theErr = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, 0);
        assert(theErr == noErr);
        theErr = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, &dictionary);
        assert(theErr == noErr);
        
        NSLog(@"dictionary: %@", dictionary);
        CFRelease(dictionary);
        theErr = AudioFileClose(audioFile);
        assert(theErr == noErr);
    }
    return 0;
}

