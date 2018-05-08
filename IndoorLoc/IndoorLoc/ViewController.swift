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

class ViewController: UIViewController, CLLocationManagerDelegate {
    var trueHeading = 0.0
    var magneticHeading = 0.0
    let locationManager = CLLocationManager()
    let pedometer = CMPedometer()
    var motionManager: CMMotionManager!
    var timer: Timer!
    var sendloop: Timer!
    var beaconsToRange: [CLBeaconRegion] = []
    var accelerometerArray = [Any]()
    
    @IBOutlet weak var trueHeadingLabel: UILabel!
    @IBOutlet weak var magneticHeadingLabel: UILabel!
    @IBOutlet weak var accXLabel: UILabel!
    @IBOutlet weak var accYLabel: UILabel!
    @IBOutlet weak var accZLabel: UILabel!
    
    private func sendData(json: [String: Any], endpoint: String) {
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
                return
            }
            
            print(NSString(data: data, encoding: String.Encoding.utf8.rawValue) ?? "default")
        }
        task.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 0
        locationManager.headingOrientation = .portrait
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        
        startAccelerometers()
        monitorBeacons();
        startPedometer();
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startAccelerometers() {
        // Make sure the accelerometer hardware is available.
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0
            motionManager.startAccelerometerUpdates()
            
            // Configure a timer to fetch the data.
            timer = Timer(fire: Date(), interval: (10.0/60.0),
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
                                        "zAcceleration": z ,
                                    ]
                                    
                                    self.accelerometerArray.append(accelerometerDict);
                                    
                                }
            })
            
            sendloop = Timer(fire: Date(), interval: 5.0, repeats: true, block: { (timer) in
                print("Sending accelerometer data, len array", self.accelerometerArray.count)
                var jsondata: [String: Any] = [
                    "magneticHeading": self.magneticHeading,
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
        ]
        
        print("Pedometer data:", pedometerDict)
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
    
    func locationManager(_ manager: CLLocationManager,
                         didEnterRegion region: CLRegion) {
        
        print("Enter: ", region);
        print("region.id: ", region.identifier);
        if region is CLBeaconRegion {
            // Start ranging only if the feature is available.
            if CLLocationManager.isRangingAvailable() {
                manager.startRangingBeacons(in: region as! CLBeaconRegion)
                
                // Store the beacon so that ranging can be stopped on demand.
                beaconsToRange.append(region as! CLBeaconRegion)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        beaconsToRange = beaconsToRange.filter() {$0 != region}
        print("Exit region");
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didRangeBeacons beacons: [CLBeacon],
                         in region: CLBeaconRegion) {
        if beacons.count > 0 {
            var beaconArray = [Any]()
            print(beacons.count, beacons)
            
            let timestamp = NSDate().timeIntervalSince1970
            
            for beacon in beacons {
                let major = CLBeaconMajorValue(beacon.major)
                let minor = CLBeaconMinorValue(beacon.minor)
                let rssi = beacon.rssi
                let accuracy = beacon.accuracy
                let proximity = beacon.proximity.rawValue
                
                let beaconDict: [String: Any] = [
                    "minor": minor,
                    "rssi": rssi,
                    "accuracy": accuracy,
                    "proximity": proximity,
                    "timestamp": timestamp
                ]
                
                beaconArray.append(beaconDict)
            }
            
            let jsonData = ["ibeacons": beaconArray, "timestamp": timestamp] as [String : Any]
            print("Number of Beacons: ", beacons.count)
            print("Beacons: ", jsonData)
            
            sendData(json: jsonData, endpoint: "ibeacons")
        }
    }
    
    func monitorBeacons() {
        if CLLocationManager.isMonitoringAvailable(for:
            CLBeaconRegion.self) {
            // Match all beacons with the specified UUID
            let proximityUUID = UUID(uuidString:
                "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")
            let beaconID = "com.example.myBeaconRegion"
            let major: CLBeaconMajorValue = 10999
            
            // Create the region and begin monitoring it.
            let region = CLBeaconRegion(proximityUUID: proximityUUID!, major: major,
                                        identifier: beaconID)
            self.locationManager.startMonitoring(for: region)
            
            print("is monitoring BLE");
        }
    }

}

