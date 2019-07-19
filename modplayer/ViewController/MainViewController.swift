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
    // let mixer = AVAudioMixerNode()
    var playing = false
    
    @IBOutlet weak var playButton: UIButton!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.audioSetup()
    }

    override func viewDidAppear(_ animated: Bool) {
        print("viewDidAppear")
        print("loadData")
        self.loadData()
        print("audioPrepare")
        audioPrepare()
        print("all done")
    }
    
    func loadData() {
        // panic
        let myUrl = URL(string: "https://api.modarchive.org/downloads.php?moduleid=34568")
        // cannon fodder
        // let myUrl = URL(string: "https://api.modarchive.org/downloads.php?moduleid=34568")
        do {
            let data = try Data(contentsOf: myUrl!)
            let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)  // AVAudioFormat
            sampleRateHz = Double(outputFormat.sampleRate)
            (myAUNode?.auAudioUnit as! ModPlayerAudioUnit).mixingRate = Float(sampleRateHz)
            (myAUNode?.auAudioUnit as! ModPlayerAudioUnit).prepareModule(buffer: data)
            pauseButton.isEnabled = true
            playButton.isEnabled = true
            spinner.isHidden = true
            titleLabel.text = "♫ " + (myAUNode?.auAudioUnit as! ModPlayerAudioUnit).name
            print("Set mixingRate to \(sampleRateHz)")
            
        } catch {
            print("oops")
        }
    }
    
    func audioSetup() {
        print("audioSetup()")
        
        let myUnitType = kAudioUnitType_Generator
        let mySubType : OSType = 1
        
        let compDesc = AudioComponentDescription(componentType:     myUnitType,
                                                 componentSubType:  mySubType,
                                                 componentManufacturer: 0x666f6f20, // 4 hex byte OSType 'foo '
            componentFlags:        0,
            componentFlagsMask:    0 )
        
        print("registerSubclass")
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
    
    func audioPrepare() {
        print("audioPrepare()")
//        let bus0 : AVAudioNodeBus   =  0    // output of the inputNode
//        let inputNode   =  audioEngine!.inputNode
//        let inputFormat =  inputNode.outputFormat(forBus: bus0)
      
        let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)  // AVAudioFormat
        sampleRateHz = Double(outputFormat.sampleRate)
    
        audioEngine.connect(audioEngine.mainMixerNode,
        to: audioEngine.outputNode,
        format: outputFormat)
    
        audioEngine.prepare()
    
//        if (displayTimer == nil) {
//        displayTimer = CADisplayLink(target: self,
//        selector: #selector(self.updateView) )
//        displayTimer.preferredFramesPerSecond = 60  // 60 Hz
//        displayTimer.add(to: RunLoop.current,
//        forMode: RunLoop.Mode.common )
//        }
    }
    
    func audioStart() {
        do {
            try audioEngine.start()
            playing = true
            (myAUNode?.auAudioUnit as! ModPlayerAudioUnit).play()
            print("engine started")
        } catch let error as NSError {
            // self.myInfoLabel1.text = (error.localizedDescription)
            print("error: \(error.localizedDescription)")
        }
    }
    
    func audioPause() {
        do {
            try audioEngine.pause()
            playing = false
            // self.myInfoLabel1.text = "engine started"
            // toneCount = 44100 / 2
            print("engine paused")
        } catch let error as NSError {
            // self.myInfoLabel1.text = (error.localizedDescription)
            print("error: \(error.localizedDescription)")
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

    
    @IBAction func onPlayTap(_ sender: Any) {
        print("onPlay")
        self.audioStart()
    }
    
    @IBAction func onPauseTap(_ sender: Any) {
        print("onPause")
        self.audioPause()
    }
}

fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}
