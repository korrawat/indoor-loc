import os
import json


DATA_PARENT_DIR = "../Server/collected_data"


class RSSIData:
    def __init__(self, entry):
        self.rssi = entry['rssi']
        self.id = entry['id']
        self.timestamp = entry['timestamp']
        
    def __repr__(self):
        return "RSSIData({})@{}: rssi={}".format(self.id, self.timestamp, self.rssi)
    
    @staticmethod
    def initialize(rssi, _id, timestamp):
        entry = {"rssi": rssi, "id": _id, "timestamp": timestamp}
        return RSSIData(entry)


def load_rssi_data(data_label):
    data_dir = os.path.join(DATA_PARENT_DIR, data_label, "ibeacons")
    data = []
    for json_file in sorted(os.listdir(data_dir)):
        if json_file[0] == '.':
            # ignore hidden files
            continue
        with open(os.path.join(data_dir, json_file)) as f:
            data_file = json.load(f)
            data += data_file
    return data


def get_rssi_data_by_timestamp(data, rssi_thres=-10000, adjust_time=False):
    initial_timestamp = data[0]['timestamp']
    data_by_timestamp = {}
    for entry in data:
        if entry['rssi'] == 0 or entry['rssi'] < rssi_thres:
            continue
        # if entry['timestamp'] != timestamp:
        #     timestamp = entry['timestamp']
        new_entry = entry.copy()
        if adjust_time:
            new_entry['timestamp'] -= initial_timestamp
        timestamp = new_entry['timestamp']
        data_by_timestamp[timestamp] = data_by_timestamp.get(timestamp, []) + [RSSIData(new_entry)]
    return data_by_timestamp

def convert_rssi_data_by_id_to_timestamp(data_by_id):
    data_by_timestamp = {}
    for data in data_by_id.values():
        for entry in data:
            if entry.rssi == 0:
                continue
            data_by_timestamp[entry.timestamp] = data_by_timestamp.get(entry.timestamp, []) + [entry]
    return data_by_timestamp


def convert_to_rough_timestamp(data_by_timestamp):
    data_by_rough_timestamp = {};
    for time in data_by_timestamp.keys():
        rough_time = float(int(time))
        data_by_rough_timestamp[rough_time] = data_by_rough_timestamp.get(rough_time, []) + data_by_timestamp[time]
    return data_by_rough_timestamp

def get_rssi_data_from_id(beacon_id, data_by_timestamp):
    rssi_data_over_time = []
    for timestamp in list(sorted(data_by_timestamp.keys())):
        rssi_dataset = data_by_timestamp[timestamp] 
        target_rssi_data = filter(lambda rssi_data: rssi_data.id == beacon_id, rssi_dataset)
        if len(target_rssi_data) > 0:
            rssi_data_over_time.append(target_rssi_data[0])
    return rssi_data_over_time

# Pick the middle or average of middle
# ex. [-3, 4, 10, 12] pick 7
def get_median(data):
    sorted_data = list(sorted(data))
    if len(data) % 2 == 0:
        return (sorted_data[len(data)//2 - 1] + sorted_data[len(data)//2]) / 2.0
    return sorted_data[len(data)//2]

# Pick the middle or one lower than middle
# ex. [-3, 4, 10, 12] pick 4
def get_median_restrict(data):
    return list(sorted(data))[(len(data)-1)//2]

def get_smooth_rssi_datapoint(rssi_data_seq, option):
#     ensure input data trying to smooth come from the same beacon_id
    ibeacon_id = rssi_data_seq[0].id
    bad_id = list( filter(lambda rssi_data: rssi_data.id != ibeacon_id, rssi_data_seq))
    assert len(bad_id) == 0, "Average on rssi data has to be on same ibeacon id"
    assert option in ["average", "median"], "Option can only be either average or median"
    
    rssis = list( map(lambda rssi_data: rssi_data.rssi, rssi_data_seq))
    if option == "average":
        smooth_rssi = sum(rssis) / float(len(rssi_data_seq))
    elif option == "median":
        smooth_rssi = get_median(rssis)
    median_timestamp = get_median_restrict(list(map(lambda rssi_data: rssi_data.timestamp, rssi_data_seq)))
    return RSSIData.initialize(smooth_rssi, ibeacon_id, median_timestamp)
    
def crop_data(data_seq, index, radius):
    st = index - radius if index > radius else 0
    en = index + radius if index + radius < len(data_seq) else len(data_seq)
    return data_seq[st: en]
def get_smooth_rssi_data(rssi_data_seq, radius, option="average"):
    assert option in ["average", "median"], "Option can only be either average or median"
    return [get_smooth_rssi_datapoint(crop_data(rssi_data_seq, i, radius), option) for i in range(0, len(rssi_data_seq), radius)]
    
# old format
class iBeaconData:
    def __init__(self, entry):
        self.rssi = entry['rssi']
        self.proximity = entry['proximity']
        self.minor = entry['minor']
        self.accuracy = entry['accuracy']
        self.timestamp = entry['timestamp']

    def __repr__(self):
        return "iBeacon({})@{}: rssi={}, prox={}, accu={}".format(self.minor, self.timestamp, self.rssi, self.proximity, self.accuracy)    
    
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

def get_data_from_ibeacon(minor, ibeacons_by_timestamp):
    ibeacon_over_time = []
    for timestamp in list(sorted(ibeacons_by_timestamp.keys())):
        ibeacons = ibeacons_by_timestamp[timestamp] 
        target_ibeacons = filter(lambda ibeacon: ibeacon.minor == minor, ibeacons)
        if len(target_ibeacons) > 0:
            ibeacon_over_time.append(target_ibeacons[0])
    return ibeacon_over_time

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

def get_ibeacon(minor, ibeacons_by_timestamp):
    ibeacon_over_time = []
    for timestamp in list(sorted(ibeacons_by_timestamp.keys())):
        ibeacons = ibeacons_by_timestamp[timestamp] 
        target_ibeacons = filter(lambda ibeacon: ibeacon.minor == minor, ibeacons)
        if len(target_ibeacons) > 0:
            ibeacon_over_time.append(target_ibeacons[0])
    return ibeacon_over_time