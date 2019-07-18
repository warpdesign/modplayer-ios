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
    var volume:UInt8 = 64
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

struct Sample {
    var name: String
    var length: UInt16
    var finetune: UInt8
    var volume: UInt8
    var repeatStart: UInt16
    var repeatLength: UInt16
    var data: Array<Float>?
}

class ModPlayerAudioUnit: CustomAudioUnit {
    var name = ""
    var samples: Array<Sample> = []
    var patterns: Array<Array<UInt8>> = []
    var positions: Array<UInt8> = []
    var songLength:UInt8 = 0
    var channels: Array<Channel> = [Channel](repeating: Channel(), count: 4)
    var maxSamples:UInt = 0
    // These are the default Mod speed/bpm
    var bpm = 125
    // number of ticks before playing next pattern row
    var speed = 6
    var speedUp = 1
    var position:UInt8 = 0
    var pattern = 0
    var row = 0
    var patternOffset = 0
    
    // samples to handle before generating a single tick (50hz)
    var samplesPerTick = 0
    var filledSamples = 0
    var ticks = 0
    var newTick = true
    var rowRepeat = 0
    var rowJump = -1
    var skipPattern = false
    var jumpPattern = -1

    var buffer:Data? = nil
    var started = false
    var ready = false
    
    // new for audioworklet
    var playing = false
    
    let patternLength = 1024
    
    var mixingRate = Float(48000.0)
    
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

    func resetProperties() {
        name = ""
        samples = []
        patterns = []
        positions = []
        songLength = 0
        channels = [Channel](repeating: Channel(), count: 4)
        maxSamples = 0
        // These are the default Mod speed/bpm
        bpm = 125
        // number of ticks before playing next pattern row
        speed = 6
        speedUp = 1
        position = 0
        pattern = 0
        row = 0
        
        // samples to handle before generating a single tick (50hz)
        samplesPerTick = 0
        filledSamples = 0
        ticks = 0
        newTick = true
        rowRepeat = 0
        rowJump = -1
        skipPattern = false
        jumpPattern = -1
        patternOffset = 0
        
        buffer = nil
        started = false
        ready = false
        
        // new for audioworklet
        playing = false
    }
    
    func resetSongValues() {
        self.started = false
        self.position = 0
        self.row = 0
        self.ticks = 0
        self.filledSamples = 0
        self.speed = 6
        self.newTick = true
        self.rowRepeat = 0
        self.rowJump = -1
        self.skipPattern = false
        self.jumpPattern = -1
        self.createChannels()
        // self.decodeRow()
    }
    
    func prepareModule(buffer: Data) {
        print("Decoding module data...")
        self.ready = false
        self.resetProperties()
        self.buffer = buffer;
        self.name = BinUtils.readAscii(&self.buffer!, 20)
        
        self.getInstruments()
        self.getPatternData()
        self.getSampleData()
        self.calcTickSpeed()
        self.createChannels()
        self.resetSongValues()
        self.ready = true
    }

    func detectMaxSamples() {
        // first modules were limited to 15 samples
        // later it was extended to 31 and the 'M.K.'
        // marker was added at offset 1080
        // new module format even use other markers
        // but we stick to good old ST/NT modules
        let str = BinUtils.readAscii(&self.buffer!, 4, 1080)
        self.maxSamples = str.contains("M.K.") ? 31 : 15;
        
        if (self.maxSamples == 15) {
            self.patternOffset = 1080 - 480
        } else {
            self.patternOffset = 1084
        }
    }
    
    func getPatternData() {
        // pattern data always starts at offset 950
        let offset = self.maxSamples == 15 ? 470 : 950;
        
        // const uint8buffer = new Uint8Array(this.buffer, offset);
        let uint8buffer = Array(Array(self.buffer!)[offset..<self.buffer!.count])
        self.songLength = uint8buffer[0]
        var position = 2
        var max:UInt8 = 0
        
        for i in 0..<self.songLength {
            let pos = uint8buffer[position + Int(i)]
            self.positions.append(pos);
            if pos > max {
                max = pos
            }
        }
        
        position = self.patternOffset
        
        for  _ in 0...max {
            // self.patterns.append(this.buffer.slice(position, position + this.patternLength));
            self.patterns.append(Array(Array(self.buffer!)[position..<position + self.patternLength]))
            position += self.patternLength;
        }
    }
    
    func getInstruments() {
        self.detectMaxSamples()
        self.samples = []
        // instruments data starts at offset 20
        var offset = 20
        let uint8buffer = Array(self.buffer!)
        let headerLength = 30

        for _ in 0..<self.maxSamples {
            var sample = Sample(
                name: BinUtils.readAscii(&self.buffer!, 22, offset),
                length: BinUtils.readWord(&self.buffer!, offset + 22) * 2,
                finetune: uint8buffer[offset + 24] & 0xF0,
                volume: uint8buffer[offset + 25],
                repeatStart: BinUtils.readWord(&self.buffer!, offset + 26) * 2,
                
                repeatLength: BinUtils.readWord(&self.buffer!, offset + 28) * 2,
                data: nil
            )

            if sample.finetune > 0 {
                print("finetune")
            }

            // Existing mod players seem to play a sample only once if repeatLength is set to 2
            if sample.repeatLength == 2 {
                sample.repeatLength = 0
                // some modules seems to skip the first two bytes for length
                if sample.length == 2 {
                    sample.length = 0
                }
            }

            if sample.repeatLength > sample.length {
                sample.repeatLength = 0
                sample.repeatStart = 0
            }

            self.samples.append(sample);

            offset += headerLength;
        }
    }
    
    func getSampleData() {
        // samples start right after patterns
        var offset = self.patternOffset + self.patterns.count * self.patternLength
        
        for i in 0..<self.samples.count {
            let length = self.samples[i].length
            var data = [Float](repeating: 0.0, count: Int(length))
            let maxLength = (offset + Int(length)) > self.buffer!.count ? self.buffer!.count - offset : Int(length)
            // var toto = Array(self.buffer!.map{Int8(bitPattern: $0)})
            var pcm = Array(Array(self.buffer!.map{Int8(bitPattern: $0)})[offset..<offset+maxLength])
            // var pcm =  new Int8Array(this.buffer, offset, maxLength);
            
            // convert 8bit pcm format to webaudio format
            for j in 0..<length {
                data[Int(j)] = Float(pcm[Int(j)]) / 128.0;
            }
            
            self.samples[i].data = data
            
            offset += maxLength
        }
    }

    func calcTickSpeed() {
        self.samplesPerTick = ((Int(self.mixingRate) * 60) / (self.bpm * self.speedUp)) / 24;
    }

    func createChannels() {
        for i in 0..<self.channels.count {
            var channel = Channel(
                sample: -1,
                samplePos: 0,
                period: 0,
                volume: 64,
                slideTo: -1,
                slideSpeed: 0,
                delay: 0,
                vform: 0,
                vdepth: 0,
                vspeed: 0,
                vpos: 0,
                loopInitiated: false,
                id: i,
                cmd: 0
            )
    
            self.channels[i] = channel
//            if (!this.channels[i]) {
//            this.channels[i] = channel;
//            } else {
//            Object.assign(this.channels[i], channel);
//            }
        }
    }
    
    // audio mix callback: this is where all the magic happens
    // let mix: AURenderBlock =
    override var renderBlock: AURenderBlock {
        get {
            return {
                (actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                timestamp: UnsafePointer<AudioTimeStamp>,
                frameCount: AVAudioFrameCount,
                outputBusNumber: NSInteger,
                outputBufferListPtr: UnsafeMutablePointer<AudioBufferList>,
                pullInputBlock: AURenderPullInputBlock?) -> AUAudioUnitStatus in
                
                let numBuffers = outputBufferListPtr.pointee.mNumberBuffers
                let ptr = outputBufferListPtr.pointee.mBuffers.mData?.assumingMemoryBound(to: Float.self)
                
                if /*self.ready && self.playing*/ true {
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
                            // toneCount -= 1
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
        }
    }
}
