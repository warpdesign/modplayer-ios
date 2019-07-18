//
//  MyAudioUnit.swift
//  modplayer
//
//  Created by Nico on 16/07/2019.
//  Copyright © 2019 Nico. All rights reserved.
//

import Foundation
import AVFoundation

var sampleRateHz = 48000.0
var testFrequency = 880.0
var testVolume = 0.5
var toneCount = 0

class CustomAudioUnit: AUAudioUnit {
    // @interface
    var outputBusArray: AUAudioUnitBusArray?

    // @implementation
    // let myAudioBufferist: AudioBufferList?
    var my_pcmBuffer:AVAudioPCMBuffer?
    var outputBus:AUAudioUnitBus?
    var myAudioBufferList:AudioBufferList?
    static var ph = 0.0

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
       
        let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRateHz, channels: 2)
        outputBus = try AUAudioUnitBus(format: defaultFormat!)
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus!])

        self.maximumFramesToRender = 512

        print("end init")
    }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        my_pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputBus!.format, frameCapacity: 4096)
        myAudioBufferList = my_pcmBuffer!.audioBufferList.pointee

    }

    override func deallocateRenderResources() {
        super.deallocateRenderResources()
    }

    override var outputBusses: AUAudioUnitBusArray {
        get {
            return outputBusArray!
        }
    }
    
    override var renderBlock: AURenderBlock {
        get {
            return {
                (actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, timestamp: UnsafePointer<AudioTimeStamp>, frameCount: AVAudioFrameCount,
                outputBusNumber: NSInteger, outputBufferListPtr: UnsafeMutablePointer<AudioBufferList>,
                pullInputBlock: AURenderPullInputBlock?) -> AUAudioUnitStatus in

                let numBuffers = outputBufferListPtr.pointee.mNumberBuffers
                // var ptrLeft  = outputBufferListPtr.pointee.mBuffers[0].mData;
                let ptr = outputBufferListPtr.pointee.mBuffers.mData?.assumingMemoryBound(to: Float.self)

                // this is where the audio buffers need to be filled: simply override this method
                if false {
                    let n = frameCount
                    let f0 = testFrequency
                    let v0 = testVolume
                    let dp = 2.0 * Double.pi * f0 / sampleRateHz
                    var offset = 0

                    for _ in 0..<n {
                        var x = 0.0
                        if toneCount != 0 {
                            x = v0 * sin(CustomAudioUnit.ph)
                            CustomAudioUnit.ph = CustomAudioUnit.ph + dp
                            if CustomAudioUnit.ph > Double.pi {
                                CustomAudioUnit.ph -= 2.0 * Double.pi
                            }
                            toneCount -= 1
                        }

                        (ptr! + offset).pointee = Float(x)

                        // handle right channel
                        if numBuffers == 2 {
                            (ptr! + offset + Int(n)).pointee = Float(x)
                        }
                        offset = offset + 1
                    }
                }
    //             *ptrRight = NULL;
    //            if (numBuffers == 2) {
    //                ptrRight    = (float*)outputBufferListPtr->mBuffers[1].mData;
    //            }

                return noErr
            }
        }
    }
}
