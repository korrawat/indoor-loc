class iBeaconData:
    def __init__(self, entry):
        self.rssi = entry['rssi']
        self.proximity = entry['proximity']
        self.minor = entry['minor']
        self.accuracy = entry['accuracy']
        self.timestamp = entry['timestamp']


    def __repr__(self):
        return "iBeacon({})@{}: rssi={}, prox={}, accu={}".format(self.minor, self.timestamp, self.rssi, self.proximity, self.accuracy)

    
class RSSIData:
    def __init__(self, entry):
        self.rssi = entry['rssi']
        self.id = entry['id']
        self.timestamp = entry['timestamp']
        
    def __repr__(self):
        return "RSSIData({})@{}: rssi={}".format(self.id, self.timestamp, self.rssi)
    

def get_data_by_timestamp(data):
    timestamp = None
    data_by_timestamp = {}
    for entry in data:
        if entry['rssi'] == 0:
            continue
        if entry['timestamp'] != timestamp:
            timestamp = entry['timestamp']
        data_by_timestamp[timestamp] = data_by_timestamp.get(timestamp, []) + [iBeaconData(entry)]
    return data_by_timestamp

def get_rssi_data_by_timestamp(data):
    timestamp = None
    data_by_timestamp = {}
    for entry in data:
        if entry['rssi'] == 0:
            continue
        if entry['timestamp'] != timestamp:
            timestamp = entry['timestamp']
        data_by_timestamp[timestamp] = data_by_timestamp.get(timestamp, []) + [RSSIData(entry)]
    return data_by_timestamp


def get_data_from_ibeacon(minor, ibeacons_by_timestamp):
    ibeacon_over_time = []
    for timestamp in list(sorted(ibeacons_by_timestamp.keys())):
        ibeacons = ibeacons_by_timestamp[timestamp] 
        target_ibeacons = filter(lambda ibeacon: ibeacon.minor == minor, ibeacons)
        if len(target_ibeacons) > 0:
            ibeacon_over_time.append(target_ibeacons[0])
    return ibeacon_over_time


# old format
def get_rssi_values_from_ibeacons(data_by_timestamp, timestamp):
    rssi_values = {}
    for ibeacon_data in data_by_timestamp[timestamp]:
        minor = ibeacon_data.minor
        rssi = ibeacon_data.rssi
        rssi_values[minor] = rssi
    return rssi_values

def get_rssi_values(data_by_timestamp, timestamp):
    rssi_values = {}
    for rssi_data in data_by_timestamp[timestamp]:
        _id = rssi_data.id
        rssi = rssi_data.rssi
        rssi_values[_id] = rssi
    return rssi_values

def get_beacon_distances_from_rssi(rssi_values, A, n, conversion):
    beacon_distances = {}
    for minor, rssi in rssi_values.items():
        beacon_distances[minor] = rssi_to_distance(rssi, A, n, conversion)
    return beacon_distances

def rssi_to_distance(rssi, A, n, conversion):
    """ need to find the params A, n that actually match our beacons """
    exponent = 1. * (A - rssi) / (10 * n)
    distance_m = pow(10, exponent)
    return distance_m * conversion