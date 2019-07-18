//
//  MainViewController.swift
//  modplayer
//
//  Created by Nico on 16/07/2019.
//  Copyright © 2019 Nico. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation

class MainViewController: UIViewController {

    let audioEngine = AVAudioEngine()
    var myAUNode: AVAudioUnit?        =  nil
    // Do any additional setup after loading the view.
    let mixer = AVAudioMixerNode()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //play()
        self.audioSetup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        audioStart()
    }
    
    func audioSetup() {
        print("audioSetup()")
        let sess = AVAudioSession.sharedInstance()
        try! sess.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)))
        do {
            try sess.setPreferredSampleRate(48000.0)
            sampleRateHz    = 48000.0
        } catch { sampleRateHz    = 44100.0 }        // for Simulator and old devices
        do {
            let duration = 1.00 * (256.0/48000.0)
            try sess.setPreferredIOBufferDuration(duration)   // 256 samples
        } catch { }
        try! sess.setActive(true)
        
        // audioEngine = AVAudioEngine()
        
        
        let myUnitType = kAudioUnitType_Generator
        let mySubType : OSType = 1
        
        let compDesc = AudioComponentDescription(componentType:     myUnitType,
                                                 componentSubType:  mySubType,
                                                 componentManufacturer: 0x666f6f20, // 4 hex byte OSType 'foo '
            componentFlags:        0,
            componentFlagsMask:    0 )
        
        print("registerSubclass")
        // MyV3AudioUnit5.self
        AUAudioUnit.registerSubclass(ModPlayerAudioUnit.self,
                                     as:        compDesc,
                                     name:      "ModPlayerAudioUnit",   // "My3AudioUnit5" my AUAudioUnit subclass
            version:   1 )
        
        let outFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        
        print("intantiate")
        AVAudioUnit.instantiate(with: compDesc,
                                options: .init(rawValue: 0)) { (audiounit, error) in
                                    
                                    print("completed: \(audiounit) \(error)")
                                    self.myAUNode = audiounit   // save AVAudioUnit
                                    print("completed 1")
                                    self.audioEngine.attach(audiounit!)
                                    print("completed 2")
                                    self.audioEngine.connect(audiounit!,
                                                              to: self.audioEngine.mainMixerNode,
                                                              format: outFormat)
        }
        print("end audioSetup")
    }
    
    func audioStart() {
        print("audioStart()")
//        let bus0 : AVAudioNodeBus   =  0    // output of the inputNode
//        let inputNode   =  audioEngine!.inputNode
//        let inputFormat =  inputNode.outputFormat(forBus: bus0)
      
        let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)  // AVAudioFormat
        sampleRateHz = Double(outputFormat.sampleRate)
    
        audioEngine.connect(audioEngine.mainMixerNode,
        to: audioEngine.outputNode,
        format: outputFormat)
    
        audioEngine.prepare()
    
        do {
            try audioEngine.start()
                // self.myInfoLabel1.text = "engine started"
                // toneCount = 44100 / 2
                print("engine started")
            } catch let error as NSError {
                // self.myInfoLabel1.text = (error.localizedDescription)
                print("error: \(error.localizedDescription)")
        }
    
//        if (displayTimer == nil) {
//        displayTimer = CADisplayLink(target: self,
//        selector: #selector(self.updateView) )
//        displayTimer.preferredFramesPerSecond = 60  // 60 Hz
//        displayTimer.add(to: RunLoop.current,
//        forMode: RunLoop.Mode.common )
//        }
    }
    
    func play() {
        DispatchQueue.global(qos: .background).async {
            let avAudioUnit = AVAudioUnit()
            
            // creates global mixer and point its output to the audio output
            self.audioEngine.attach(avAudioUnit)
            self.audioEngine.attach(self.mixer)
            self.audioEngine.connect(self.mixer, to: self.audioEngine.outputNode, format: nil)
            try! self.audioEngine.start()
            
            // create a node player and connect it to the mixer
//            let audioPlayer = AVAudioPlayerNode()
//            self.audioEngine.attach(audioPlayer)
//            // Notice the output is the mixer in this case
//             self.audioEngine.connect(audioPlayer, to: self.mixer, format: nil)
//
//            // load a new file
//            let path = Bundle.main.path(forResource: "onlylove", ofType: "mp3")
//            let audioFileURL = URL(fileURLWithPath: path!)
//
//            var file: AVAudioFile = try! AVAudioFile.init(forReading: audioFileURL.absoluteURL)
//
//            audioPlayer.scheduleFile(file, at: nil, completionHandler: nil)
//            audioPlayer.play(at: nil)
            
            // own audio
            // avAudioUnit.auAudioUnit.isInputEnabled  = true
            avAudioUnit.auAudioUnit.outputProvider = { // AURenderPullInputBlock()
                
                (actionFlags, timestamp, frameCount, inputBusNumber, inputData) -> AUAudioUnitStatus in
                
                print("outputProvider: \(timestamp)")
                
                return 0
            }
            
            self.audioEngine.connect(avAudioUnit, to: self.mixer, format: nil)
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onToneTap(_ sender: Any) {
        print("tone!")
        toneCount = 44100 / 2;
    }
}

fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}
