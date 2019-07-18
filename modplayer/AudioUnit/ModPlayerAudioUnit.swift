//
//  ModPlayerUnit.swift
//  modplayer
//
//  Created by Nico on 18/07/2019.
//  Copyright © 2019 Nico. All rights reserved.
//

import Foundation
import AVFoundation

let PaulaPeriods:Array<Float> = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113];

var waveForms:Array<Array<Float>> = [[Float](repeating: 0.0, count: 64)];

// module channel struct
struct Channel {
    var sample = -1
    var samplePos = 0
    var period:Float = 0.0
    var volume = 64
    var slideTo = -1
    var slideSpeed = 0
    var delay = 0
    var vform:Float = 0.0
    var vdepth = 0
    var vspeed = 0
    var vpos = 0
    var loopInitiated = false
    var id = 0
    var cmd = 0
}

class ModPlayerAudioUnit: CustomAudioUnit {
    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        
        buildTables()
    }
    
    func buildTables() {
        // Sin waveform
        // an amplitude of 64 is supposed to be enough
        for i in 0..<waveForms[0].count {
            waveForms[0][i] = 64.0 * sin(Float.pi * 2.0 * (Float(i) / 64.0));
        }
    }
    
    // audio mix callback: this is where all the magic happens
    let mix: AURenderBlock = {
        (actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AVAudioFrameCount,
        outputBusNumber: NSInteger,
        outputBufferListPtr: UnsafeMutablePointer<AudioBufferList>,
        pullInputBlock: AURenderPullInputBlock?) -> AUAudioUnitStatus in
        
            let numBuffers = outputBufferListPtr.pointee.mNumberBuffers
            let ptr = outputBufferListPtr.pointee.mBuffers.mData?.assumingMemoryBound(to: Float.self)
        
            if true {
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
        
            return noErr
    }
        
    override var renderBlock: AURenderBlock {
        get {
            return self.mix
        }
    }
}
