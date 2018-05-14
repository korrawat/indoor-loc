//
//  ViewController.swift
//  IndoorLoc
//
//  Created by Korrawat Pruegsanusak on 5/4/18.
//  Copyright © 2018 Korrawat Pruegsanusak. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion

var globalBeacons = [BeaconInfo?](repeating: nil, count: 9)

import CoreFoundation

class ParkBenchTimer {
    
    let startTime:CFAbsoluteTime
    var endTime:CFAbsoluteTime?
    
    init() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func stop() -> CFAbsoluteTime {
        endTime = CFAbsoluteTimeGetCurrent()
        
        return duration!
    }
    
    var duration:CFAbsoluteTime? {
        if let endTime = endTime {
            return endTime - startTime
        } else {
            return nil
        }
    }
}

class ViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate, BeaconScannerDelegate {
    var trueHeading = 0.0
    var magneticHeading = 0.0
    let locationManager = CLLocationManager()
    let pedometer = CMPedometer()
    var motionManager: CMMotionManager!
    var timer: Timer!
    var sendloop: Timer!
    var timerDeviceMotion: Timer!
    var sendloopDeviceMotion: Timer!
    var beaconsToRange: [CLBeaconRegion] = []
    var accelerometerArray = [Any]()
    var deviceMotionArray = [Any]()
    let proximityUUID = UUID(uuidString:
        "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")
    let beaconID = "com.example.myBeaconRegion"
    let major: CLBeaconMajorValue = 10999
    var region: CLBeaconRegion!
    var dataLabel = ""
    var stopwatch: ParkBenchTimer!
    var stopwatchloop: Timer!
    var stopped = true
    var beaconScanner: BeaconScanner!
    var beaconTimer: Timer!

    @IBOutlet weak var dataTextField: UITextField!
    
    @IBOutlet weak var trueHeadingLabel: UILabel!
    @IBOutlet weak var magneticHeadingLabel: UILabel!
    @IBOutlet weak var accXLabel: UILabel!
    @IBOutlet weak var accYLabel: UILabel!
    @IBOutlet weak var accZLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var stepsLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var responseLabel: UILabel!
    
    private func sendData(json: [String: Any], endpoint: String) {
        if self.stopped {
            self.responseLabel.text = "Stopped"
            return
        }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        print("JSON: ", json);
        let url = URL(string: "http://159.65.37.143:3000/"+endpoint);
        var request = URLRequest(url: url!);
        request.httpMethod = "POST";
        request.httpBody = jsonData;
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                DispatchQueue.main.async {
                    self.responseLabel.text = error?.localizedDescription ?? "No data"
                }
                return
            }
            
            let responsetext = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            DispatchQueue.main.async {
                self.responseLabel.text = responsetext as! String
            }
            print(responsetext!)
        }
        task.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataTextField.delegate = self
        
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 0
        locationManager.headingOrientation = .portrait
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
 
        // Create the region
        region = CLBeaconRegion(proximityUUID: proximityUUID!, major: major, identifier: beaconID)

    }
    
    //Text field delegate methods
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField){
        self.dataLabel = textField.text!
    }
    
    //Actions
    @IBAction func startCollecting(_ sender: UIButton) {
        if self.stopped == false {
            self.statusLabel.text = "Already started"
            return
        }
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        
        startAccelerometers();
        monitorBeacons();
        startPedometer();
        self.stopped = false
        
        self.stopwatch = ParkBenchTimer()
        
        self.stopwatchloop = Timer(fire: Date(), interval: 1.0, repeats: true, block: { (timer) in
                let time = self.stopwatch.stop()
                let hours = Int(time) / 3600
                let minutes = Int(time) / 60 % 60
                let seconds = Int(time) % 60
                let stamp = String(format:"%02i:%02i:%02i", hours, minutes, seconds)
                self.statusLabel.text = stamp
        })
        
        RunLoop.current.add(self.stopwatchloop!, forMode: .defaultRunLoopMode)
    }
    
    
    @IBAction func stopCollecting(_ sender: UIButton) {
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        self.stopped = true
        
        self.locationManager.stopMonitoring(for: region)
        
        // Invalidate timers
        if timer != nil {
            timer.invalidate()
            timer = nil
        }
        
        if sendloop != nil {
            sendloop.invalidate()
            sendloop = nil
        }
        
        if self.stopwatchloop != nil {
            self.stopwatchloop.invalidate()
            self.stopwatchloop = nil
        }
        
        if self.beaconTimer != nil {
            self.beaconTimer.invalidate()
            self.beaconTimer = nil
        }
        
        
        statusLabel.text = "Stopped"
        self.responseLabel.text = "Stopped"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func monitorBeacons(){
        self.beaconScanner = BeaconScanner()
        self.beaconScanner!.delegate = self
        self.beaconScanner!.startScanning()
        
        beaconTimer = Timer(fire: Date(), interval: 0.1, repeats: true, block: { (timer) in
            if globalBeacons.count > 0 {
                var beaconArray = [[String: Any]]()
                print(globalBeacons.count, globalBeacons)

                for beacon in globalBeacons {
                    if beacon == nil {
                        continue
                    }
                    let rssi = beacon!.RSSI
                    let id = beacon!.beaconID.beaconNum()
                    
                    let beaconDict: [String: Any] = [
                        "id": id,
                        "rssi": rssi,
                    ]

                    beaconArray.append(beaconDict)
                }

                let timestamp = NSDate().timeIntervalSince1970
                let jsonData = ["ibeacons": beaconArray, "timestamp": timestamp, "label": self.dataLabel] as [String : Any]
                print("Number of Beacons: ", globalBeacons.count)
                print("Beacons: ", jsonData)

                self.sendData(json: jsonData, endpoint: "ibeacons")
            }
        })
        
        RunLoop.current.add(self.beaconTimer!, forMode: .defaultRunLoopMode)
    }
    
    
    func didFindBeacon(beaconScanner: BeaconScanner, beaconInfo: BeaconInfo) {
        NSLog("FOUND: %@", beaconInfo.description)
        globalBeacons[beaconInfo.beaconID.beaconNum() - 1] = beaconInfo
    }
    
    func didLoseBeacon(beaconScanner: BeaconScanner, beaconInfo: BeaconInfo) {
        NSLog("LOST: %@", beaconInfo.description)
        globalBeacons[beaconInfo.beaconID.beaconNum() - 1] = beaconInfo
    }
    
    func didUpdateBeacon(beaconScanner: BeaconScanner, beaconInfo: BeaconInfo) {
        globalBeacons[beaconInfo.beaconID.beaconNum() - 1] = beaconInfo
        NSLog("UPDATE: %@", beaconInfo.description)
    }
    
    func didObserveURLBeacon(beaconScanner: BeaconScanner, URL: NSURL, RSSI: Int) {
        NSLog("URL SEEN: %@, RSSI: %d", URL, RSSI)
    }
    
    func startDeviceMotion() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01
            motionManager.showsDeviceMovementDisplay = true
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            
            // Configure a timer to fetch the motion data.
            self.timer = Timer(fire: Date(), interval: (1.0/60.0), repeats: true,
                               block: { (timer) in
                                if let data = self.motionManager.deviceMotion {
                                    // Get the attitude relative to the magnetic north reference
                                    let attitude = data.attitude.quaternion
                                    let userAcceleration = data.userAcceleration
                                    
                                    
                                    // Use the motion data in your app.
                                    
                                    // Send device motion data to the server
                                    let timestamp = Date().timeIntervalSince1970
                                    var deviceMotionDict: [String: Any];
                                    deviceMotionDict = [
                                        "timestamp": timestamp,
                                        "wAttitude": attitude.w,
                                        "xAttitude": attitude.x,
                                        "yAttitude": attitude.y,
                                        "zAttitude": attitude.z,
                                        "xAcceleration": userAcceleration.x,
                                        "yAcceleration": userAcceleration.y,
                                        "zAcceleration": userAcceleration.z
                                    ]
                                    
                                    self.deviceMotionArray.append(deviceMotionDict)
                                }
            })
            
            sendloopDeviceMotion = Timer(fire: Date(), interval: 2.0, repeats: true, block: { (timer) in
                print("Sending device motion data, len array", self.deviceMotionArray.count)
                
                let jsondata: [String: Any] = [
                    "label": self.dataLabel,
                    "readings": self.deviceMotionArray
                ]
                
                self.sendData(json: jsondata, endpoint: "devicemotion")
                self.deviceMotionArray = [Any]()
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timerDeviceMotion!, forMode: .defaultRunLoopMode)
            RunLoop.current.add(self.sendloopDeviceMotion!, forMode: .defaultRunLoopMode)
        }
    }

    
    func startAccelerometers() {
        // Make sure the accelerometer hardware is available.
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.01
            motionManager.startAccelerometerUpdates()
            
            // Configure a timer to fetch the data.
            timer = Timer(fire: Date(), interval: 0.01,
                               repeats: true, block: { (timer) in
                                // Get the accelerometer data.
                                if let data = self.motionManager.accelerometerData {
                                    let x = data.acceleration.x
                                    let y = data.acceleration.y
                                    let z = data.acceleration.z
                                    
                                    // Use the accelerometer data in your app.
                                    self.accXLabel.text = String(format: "x: %+.2f", x)
                                    self.accYLabel.text = String(format: "y: %+.2f", y)
                                    self.accZLabel.text = String(format: "z: %+.2f", z)
                                    
                                    // Send accelerometer data to the server
                                    
                                    let timestamp = Date().timeIntervalSince1970
                                    var accelerometerDict: [String: Any];
                                    accelerometerDict = [
                                        "timestamp": timestamp,
                                        "xAcceleration": x,
                                        "yAcceleration": y,
                                        "zAcceleration": z,
                                        "magneticHeading": self.magneticHeading
                                    ]
                                    
                                    self.accelerometerArray.append(accelerometerDict);
                                    
                                }
            })
            
            sendloop = Timer(fire: Date(), interval: 2.0, repeats: true, block: { (timer) in
                print("Sending accelerometer data, len array", self.accelerometerArray.count)

                let jsondata: [String: Any] = [
                    "label": self.dataLabel,
                    "readings": self.accelerometerArray
                ]
                
                self.sendData(json: jsondata, endpoint: "accelerometer")
                self.accelerometerArray = [Any]()
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .defaultRunLoopMode)
            RunLoop.current.add(self.sendloop!, forMode: .defaultRunLoopMode)
        }
    }
    
    func startPedometer(){
        pedometer.startUpdates(from: Date()) {
            [weak self] pedometerData, error in
            guard let pedometerData = pedometerData, error == nil else { print(error); return }
            
            DispatchQueue.main.async {
                self?.updatePedometerData(pedometerData: pedometerData)
            }
        }
    }
    
    func updatePedometerData(pedometerData: CMPedometerData){
        var  pedometerDict = [String: Any]()
        let timestamp = NSDate().timeIntervalSince1970
        
        var roundedDistance: Double = 0;
        if pedometerData.distance != nil {
            roundedDistance = pedometerData.distance!.doubleValue.rounded()
        }

        pedometerDict = [
            "timestamp": timestamp,
            "steps": pedometerData.numberOfSteps,
            "distanceTraveled": roundedDistance,
             "label": self.dataLabel
        ]
        
        print("Pedometer data:", pedometerDict)
        stepsLabel.text = String(pedometerData.numberOfSteps as! Int)
        distanceLabel.text = String(roundedDistance)
        sendData(json: pedometerDict, endpoint: "pedometer")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // prefer magnetic heading (because true heading calculated using GPS)
        trueHeading = newHeading.trueHeading
        magneticHeading = newHeading.magneticHeading
        trueHeadingLabel.text = String(format: "True Heading: %.2f", trueHeading)
        magneticHeadingLabel.text = String(format: "Magn Heading: %.2f", magneticHeading)
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // your code here
        //        userCoord = locationManager.location?.coordinate
//        userCoord = locations.last?.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print(status)
        print(status.rawValue)
    }
    
//    func locationManager(_ manager: CLLocationManager,
//                         didEnterRegion region: CLRegion) {
//
//        print("Enter: ", region);
//        print("region.id: ", region.identifier);
//        if region is CLBeaconRegion {
//            // Start ranging only if the feature is available.
//            if CLLocationManager.isRangingAvailable() {
//                manager.startRangingBeacons(in: region as! CLBeaconRegion)
//
//                // Store the beacon so that ranging can be stopped on demand.
//                beaconsToRange.append(region as! CLBeaconRegion)
//            }
//        }
//    }
    
//    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
//        beaconsToRange = beaconsToRange.filter() {$0 != region}
//        print("Exit region");
//    }
//
//    func locationManager(_ manager: CLLocationManager,
//                         didRangeBeacons beacons: [CLBeacon],
//                         in region: CLBeaconRegion) {
//        if beacons.count > 0 {
//            var beaconArray = [[String: Any]]()
//            print(beacons.count, beacons)
//
//            for beacon in beacons {
//                let major = CLBeaconMajorValue(beacon.major)
//                let minor = CLBeaconMinorValue(beacon.minor)
//                let rssi = beacon.rssi
//                let accuracy = beacon.accuracy
//                let proximity = beacon.proximity.rawValue
//
//                let beaconDict: [String: Any] = [
//                    "minor": minor,
//                    "rssi": rssi,
//                    "accuracy": accuracy,
//                    "proximity": proximity,
//                ]
//
//                beaconArray.append(beaconDict)
//            }
//
//            let timestamp = NSDate().timeIntervalSince1970
//            globalBeacons = beaconArray
//            let jsonData = ["ibeacons": beaconArray, "timestamp": timestamp, "label": self.dataLabel] as [String : Any]
//            print("Number of Beacons: ", beacons.count)
//            print("Beacons: ", jsonData)
//
//            sendData(json: jsonData, endpoint: "ibeacons")
//        }
//    }
//
//    func monitorBeacons() {
//        if CLLocationManager.isMonitoringAvailable(for:
//            CLBeaconRegion.self) {
//            // Match all beacons with the specified UUID
//
//            self.locationManager.startMonitoring(for: region)
//
//            print("is monitoring BLE");
//        }
//    }
//
}

