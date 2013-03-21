//
//  main.m
//  CAToneFileGenerator
//
//  Created by Brian Ball on 3/10/13.
//  Copyright (c) 2013 Brian Ball. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define SAMPLE_RATE 44100
#define DURATION 5.0
#define FILENAME_FORMAT @"%0.3f-sine.aif"


int main(int argc, const char * argv[])
{

    @autoreleasepool {
        if(argc<2){
            printf("Usage: CAToneFileGenerator n\n(where n is the tone in Hz)");
            return -1;
        }
        
        double hz = atof(argv[1]);
        assert(hz > 0);
        NSLog(@"gererating %f hz tone", hz);
        
        NSString *fileName = [NSString stringWithFormat:FILENAME_FORMAT, hz];
        NSString *filePath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:fileName];
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        
        AudioStreamBasicDescription asbd;
        memset(&asbd, 0, sizeof(asbd));
        
        asbd.mSampleRate = SAMPLE_RATE;
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        asbd.mBitsPerChannel = 16;
        asbd.mChannelsPerFrame = 1;
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerFrame = 2;
        asbd.mBytesPerPacket = 2;
        
        AudioFileID audioFile;
        OSStatus audioErr = noErr;
        audioErr = AudioFileCreateWithURL((__bridge CFURLRef)fileUrl,
                                          kAudioFileAIFFType,
                                          &asbd,
                                          kAudioFileFlags_EraseFile,
                                          &audioFile);
        
        assert(audioErr == noErr);
        
        long maxSampleCount = SAMPLE_RATE * DURATION;
        long sampleCount = 0;
        UInt32 bytesToWrite = 2;
        double wavelengthInSamples = SAMPLE_RATE / hz;
        
        while(sampleCount < maxSampleCount){
            for(int i = 0; i < wavelengthInSamples; i++){
                // Sine
                SInt16 sample = CFSwapInt16HostToBig((SInt16) SHRT_MAX * sin(2*M_PI * (i/wavelengthInSamples)));
                audioErr = AudioFileWriteBytes(audioFile, false, sampleCount*2, &bytesToWrite, &sample);
                assert(audioErr == noErr);
                sampleCount++;                
                
                // Saw
//                SInt16 sample = CFSwapInt16HostToBig(((i/wavelengthInSamples)*SHRT_MAX*2) - SHRT_MAX);
//                audioErr = AudioFileWriteBytes(audioFile, false, sampleCount*2, &bytesToWrite, &sample);
//                assert(audioErr == noErr);
//                sampleCount++;
                
                // Square
//                SInt16 sample;
//                if(i < wavelengthInSamples/2){
//                    sample = CFSwapInt16HostToBig(SHRT_MAX);
//                } else {
//                    sample = CFSwapInt16HostToBig(SHRT_MIN);
//                }
//                audioErr = AudioFileWriteBytes(audioFile, false, sampleCount*2, &bytesToWrite, &sample);
//                assert(audioErr == noErr);
//                
//                sampleCount++;
            }
        }
        audioErr = AudioFileClose(audioFile);
        assert(audioErr == noErr);
        
        NSLog(@"Wrote %ld samples", sampleCount);
        
    }
    return 0;
}

