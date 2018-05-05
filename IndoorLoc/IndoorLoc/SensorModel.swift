//
//  SensorModel.swift
//  Anteater
//
//  Created by Justin Anderson on 8/1/16.
//  Copyright © 2016 MIT. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

protocol SensorModelDelegate {
    func sensorModel(_ model: SensorModel, didChangeActiveHill hill: Hill?)
    func sensorModel(_ model: SensorModel, didReceiveReadings readings: [Reading], forHill hill: Hill?)
}

extension Notification.Name {
    public static let SensorModelActiveHillChanged = Notification.Name(rawValue: "SensorModelActiveHillChangedNotification")
    public static let SensorModelReadingsChanged = Notification.Name(rawValue: "SensorModelHillReadingsChangedNotification")
}

enum ReadingType: Int {
    case Unknown = -1
    case Humidity = 2
    case Temperature = 1
    case Error = 0
}

struct Reading {
    let type: ReadingType
    let value: Double
    let date: Date = Date()
    let sensorId: String?
    
    func toJson() -> [String: Any] {
        return [
            "value": self.value,
            "type": self.type.rawValue,
            "timestamp": self.date.timeIntervalSince1970,
            "userid": UIDevice.current.identifierForVendor?.uuidString ?? "NONE",
            "sensorid": sensorId ?? "NONE"
        ]
    }
}

extension Reading: CustomStringConvertible {
    var description: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        guard let numberString = formatter.string(from: NSNumber(value: self.value)) else {
            print("Double \"\(value)\" couldn't be formatted by NumberFormatter")
            return "NaN"
        }
        switch type {
        case .Temperature:
            return "\(numberString)°F"
        case .Humidity:
            return "\(numberString)%"
        default:
            return "\(type)"
        }
    }
}

struct Hill {
    var readings: [Reading]
    var name: String
    
    init(name: String) {
        readings = []
        self.name = name
    }
}

extension Hill: CustomStringConvertible, Hashable, Equatable {
    var description: String {
        return name
    }
    
    var hashValue: Int {
        return name.hashValue
    }
}

func ==(lhs: Hill, rhs: Hill) -> Bool {
    return lhs.name == rhs.name
}

class SensorModel: BLEDelegate {
    
    static let kBLE_SCAN_TIMEOUT = 10000.0
    
    static let shared = SensorModel()
    
    var delegate: SensorModelDelegate?
    var sensorReadings: [ReadingType: [Reading]] = [.Humidity: [], .Temperature: []]
    var activeHill: Hill?
    var ble: BLE
    var peripheral: CBPeripheral?
    var currFloatString: String = "";
    var currMessageType: ReadingType = ReadingType.Unknown;
    var currVal: Float?;
    
    init() {
        ble = BLE();
        ble.delegate = self;
    }
    
    func ble(didUpdateState state: BLEState) {
        if (BLEState.poweredOn == state) {
            print("Connect to BLE is on...");
            ble.startScanning(timeout: SensorModel.kBLE_SCAN_TIMEOUT);
        } else {
            print("Connect to BLE is off...");
        }
    }
    func ble(didDiscoverPeripheral peripheral: CBPeripheral) {
        // core bluetooth
        print("Discover Anthill");
        ble.connectToPeripheral(peripheral);
        
    }
    func ble(didConnectToPeripheral peripheral: CBPeripheral) {
        self.activeHill = Hill(name: peripheral.name!);
        print("Connect to Anthill", SensorModel.shared.activeHill);
        // TODO: use alternative string if peripheral.name does NOT exist
        delegate?.sensorModel(SensorModel.shared, didChangeActiveHill: activeHill)
        self.peripheral = peripheral;
        
    }
    func ble(didDisconnectFromPeripheral peripheral: CBPeripheral) {
        if (self.peripheral == peripheral) {
            ble.disconnectFromPeripheral(peripheral);
            print("Disconnect from Anthill", SensorModel.shared.activeHill);
            self.activeHill = nil;
            self.peripheral = nil;
            ble.startScanning(timeout: SensorModel.kBLE_SCAN_TIMEOUT);
        }
        
    }
    func ble(_ peripheral: CBPeripheral, didReceiveData data: Data?) {
        if (data == nil) {
            return;
        }
        print("Receive the data from Anthil...", data!.count)
        for d in data! {
            let s = String(UnicodeScalar(d));
            switch s {
            case "H":
                currMessageType = ReadingType.Humidity;
            case "T":
                currMessageType = ReadingType.Temperature;
            case "E":
                currMessageType = ReadingType.Error;
            case "D":
                let val: Double = NSString(string: currFloatString).doubleValue;
                let reading = Reading(type: currMessageType, value: val, sensorId: peripheral.name);
                if (currMessageType == ReadingType.Humidity || currMessageType == ReadingType.Temperature) {
                    if (self.activeHill != nil) {
                        self.activeHill!.readings.append(reading);
                        delegate?.sensorModel(SensorModel.shared, didReceiveReadings: [reading], forHill: activeHill);
                        
                        //                            self.activeHill!.readings
                        print(self.activeHill!.readings);
                    }
                }
                
                
                // reset back after flush the reading data
                currFloatString = "";
                currMessageType = ReadingType.Unknown;
            default:
                currFloatString += s;
            }
            
        }
    }
}

