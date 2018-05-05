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
    var curHeading = 0.0
    let locationManager = CLLocationManager()
    var motionManager: CMMotionManager!
    var timer: Timer!
    
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var accXLabel: UILabel!
    @IBOutlet weak var accYLabel: UILabel!
    @IBOutlet weak var accZLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        let url = URL(string: "http://159.65.37.143:3000/addpoint/2")
//
//        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
//            print(NSString(data: data!, encoding: String.Encoding.utf8.rawValue) ?? "default")
//        }
//
//        task.resume()
        
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
            timer = Timer(fire: Date(), interval: (1.0/60.0),
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
                                }
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .defaultRunLoopMode)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        curHeading = newHeading.trueHeading
        headingLabel.text = String(format: "Heading: %.2f", curHeading)
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

}

