//
//  main.m
//  CAConverter
//
//  Created by Brian Ball on 3/28/13.
//  Copyright (c) 2013 Brian Ball. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kInputFileLocation  CFSTR("/Users/brian/Downloads/TV_Ghost_-_07_-_Cold_Fish.mp3")

#pragma mark user data struct
// Insert listing 6.2
typedef struct MyAudioConverterSettings{
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    AudioFileID inputFile;
    AudioFileID outputFile;
    UInt64 inputFilePacketIndex;
    UInt64 inputFilePacketCount;
    UInt32 inputFilePacketMaxSize;
    AudioStreamPacketDescription *inputFilePacketDescriptions;
    void *sourceBuffer;
} MyAudioConverterSettings;

#pragma mark utility functions
// Insert listing 4.2
static void CheckError(OSStatus error, const char *operation){
    if(error == noErr) return;
    
    char errorString[20];
    *(UInt32*)(errorString+1) = CFSwapInt32HostToBig(error);
    if(isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])){
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
        sprintf(errorString, "%d", (int)error);
    }
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}


#pragma mark converter callback function
OSStatus MyAudioConverterCallback(AudioConverterRef inAudioConverter,
                                  UInt32 *ioDataPacketCount,
                                  AudioBufferList *ioData,
                                  AudioStreamPacketDescription **outDataPacketDescription,
                                  void *inUserData){
    MyAudioConverterSettings *audioConverterSettings = (MyAudioConverterSettings*)inUserData;
    ioData->mBuffers[0].mData = NULL;
    ioData->mBuffers[0].mDataByteSize = 0;
    if(audioConverterSettings->inputFilePacketIndex + *ioDataPacketCount > audioConverterSettings->inputFilePacketCount)
        *ioDataPacketCount = audioConverterSettings->inputFilePacketCount - audioConverterSettings->inputFilePacketIndex;
    if(*ioDataPacketCount == 0)
        return noErr;
    if(audioConverterSettings -> sourceBuffer != NULL){
        free(audioConverterSettings->sourceBuffer);
        audioConverterSettings->sourceBuffer = NULL;
    }
    audioConverterSettings->sourceBuffer = (void*)calloc(1, *ioDataPacketCount * audioConverterSettings->inputFilePacketMaxSize);
    
    UInt32 outByteCount = 0;
    OSStatus result = AudioFileReadPackets(audioConverterSettings->inputFile, true, &outByteCount, audioConverterSettings->inputFilePacketDescriptions, audioConverterSettings->inputFilePacketIndex, ioDataPacketCount, audioConverterSettings->sourceBuffer);
#ifdef MAC_OS_X_VERSION_10_7
    if(result == kAudioFileEndOfFileError && *ioDataPacketCount)
        result = noErr;
#else
    if(result == eofErr && *ioDataPacketCount)
        result = noErr;
#endif
    else if(result != noErr)
        return result;
    
    audioConverterSettings->inputFilePacketIndex += *ioDataPacketCount;
    ioData->mBuffers[0].mData = audioConverterSettings->sourceBuffer;
    ioData->mBuffers[0].mDataByteSize = outByteCount;
    if(outDataPacketDescription)
        *outDataPacketDescription = audioConverterSettings->inputFilePacketDescriptions;
    return result;
}

// Insert listing 6.8-6.15
void Convert(MyAudioConverterSettings *mySettings){
    AudioConverterRef audioConverter;
    CheckError(AudioConverterNew(&mySettings->inputFormat, &mySettings->outputFormat, &audioConverter), "AudioConverterNew failed");
    
    UInt32 packetsPerBuffer = 0;
    UInt32 outputBufferSize = 32 * 1024;
    UInt32 sizePerPacket = mySettings -> inputFormat.mBytesPerPacket;
    if(sizePerPacket == 0){
        UInt32 size = sizeof(sizePerPacket);
        CheckError(AudioConverterGetProperty(audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &sizePerPacket), "Couldn't get kAudioConverterPropertyMaximumOutputPacketSize");
        
        if(sizePerPacket > outputBufferSize)
            outputBufferSize = sizePerPacket;
        packetsPerBuffer = outputBufferSize / sizePerPacket;
        
        mySettings -> inputFilePacketDescriptions = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription)*packetsPerBuffer);
    } else {
        packetsPerBuffer = outputBufferSize / sizePerPacket;
    }
    
    UInt8 *outputBuffer = (UInt8*)malloc(sizeof(UInt8)*outputBufferSize);
    UInt32 outputFilePacketPosition = 0;
    while(1){
        AudioBufferList convertedData;
        convertedData.mNumberBuffers = 1;
        convertedData.mBuffers[0].mNumberChannels = mySettings-> inputFormat.mChannelsPerFrame;
        convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
        convertedData.mBuffers[0].mData = outputBuffer;
        UInt32 ioOutputDataPackets = packetsPerBuffer;
        OSStatus error = AudioConverterFillComplexBuffer(audioConverter, MyAudioConverterCallback, mySettings, &ioOutputDataPackets, &convertedData, (mySettings->inputFilePacketDescriptions? mySettings->inputFilePacketDescriptions : nil));
        if(error || !ioOutputDataPackets){
            break;
        }
        
        CheckError(AudioFileWritePackets(mySettings->outputFile, false, ioOutputDataPackets, NULL, outputFilePacketPosition / mySettings->outputFormat.mBytesPerPacket, &ioOutputDataPackets, convertedData.mBuffers[0].mData), "Couldn't write packets to file");
        outputFilePacketPosition += (ioOutputDataPackets * mySettings->outputFormat.mBytesPerPacket);
    }
    AudioConverterDispose(audioConverter);
}


#pragma mark main function
int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // Open input file
        // Insert listing 6.3
        MyAudioConverterSettings audioConverterSettings = {0};
        CFURLRef inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                              kInputFileLocation,
                                                              kCFURLPOSIXPathStyle,
                                                              false);
        CheckError(AudioFileOpenURL(inputFileURL, kAudioFileReadPermission, 0, &audioConverterSettings.inputFile), "AudioFileOpenURL failed");
        CFRelease(inputFileURL);
        
        // Get input format
        // Insert listing 6.4
        UInt32 propSize = sizeof(audioConverterSettings.inputFormat);
        CheckError(AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyDataFormat, &propSize, &audioConverterSettings.inputFormat), "Couldn't get fie's data format");
        
        // Set up output file
        // Insert listing 6.5
        propSize = sizeof(audioConverterSettings.inputFilePacketCount);
        CheckError(AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyAudioDataPacketCount, &propSize, &audioConverterSettings.inputFilePacketCount), "Couldn't get file's packet count");
        propSize = sizeof(audioConverterSettings.inputFilePacketMaxSize);
        CheckError(AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyMaximumPacketSize, &propSize, &audioConverterSettings.inputFilePacketMaxSize), "couldn't get file's max packet size");
        
        // Perform conversion
        // Insert listing 6.6
        audioConverterSettings.outputFormat.mSampleRate = 44100.0;
        audioConverterSettings.outputFormat.mFormatID = kAudioFormatLinearPCM;
        audioConverterSettings.outputFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioConverterSettings.outputFormat.mBytesPerPacket = 4;
        audioConverterSettings.outputFormat.mFramesPerPacket = 1;
        audioConverterSettings.outputFormat.mBytesPerFrame = 4;
        audioConverterSettings.outputFormat.mChannelsPerFrame = 2;
        audioConverterSettings.outputFormat.mBitsPerChannel = 16;
        
        CFURLRef outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("output.aif"), kCFURLPOSIXPathStyle, false);
        CheckError(AudioFileCreateWithURL(outputFileURL, kAudioFileAIFFType, &audioConverterSettings.outputFormat, kAudioFileFlags_EraseFile, &audioConverterSettings.outputFile), "AudioFileCreateWithURL failed");
        CFRelease(outputFileURL);
        
        // Insert listing 6.7
        fprintf(stdout, "Converting ... \n");
        Convert(&audioConverterSettings);
    cleanup:
        AudioFileClose(audioConverterSettings.inputFile);
        AudioFileClose(audioConverterSettings.outputFile);
    }
    return 0;
}

