import json
import os


DATA_PARENT_DIR = "../Server/collected_data"
DATA_TYPES = ["accelerometer", "pedometer"]
STEP_LENGTH = 24 # inches of average human step
STATIONARY_TIME = 1.5 # seconds we have to be standing still in one spot to register as not walking

class PedometerData:
    def __init__(self, entry):
        self.timestamp = entry['timestamp']
        self.distanceTraveled = entry['distanceTraveled']
        self.steps = entry['steps']


    def __repr__(self):
        return "ped({})@{}: dist={}, steps={}".format(self.label, self.timestamp, self.distanceTraveled, self.steps)


class MotionData:
    def __init__(self, entry):
        self.xAcceleration = entry['xAcceleration']
        self.yAcceleration = entry['yAcceleration']
        self.zAcceleration = entry['zAcceleration']
        self.magneticHeading = entry['magneticHeading']
        self.timestamp = entry['timestamp']


    def __repr__(self):
        return "acc@{}: x={}, y={}, z={}, heading={}".format(
            self.timestamp, self.xAcceleration, self.yAcceleration, self.zAcceleration, self.magneticHeading)


def load_data_by_type(data_label, data_type, start_after_time=None):
    assert data_type in DATA_TYPES

    data_dir = os.path.join(DATA_PARENT_DIR, data_label, data_type)
    data = []
    last_timestamp = None
    for json_file in sorted(os.listdir(data_dir)):
        if json_file[0] == '.':
            # ignore hidden files
            continue
        with open(os.path.join(data_dir, json_file)) as f:
            data_file = json.load(f)
            for entry in data_file:
                if data_type == "pedometer":
                    entry_parsed = PedometerData(entry)
                elif data_type == "accelerometer":
                    entry_parsed = MotionData(entry)
                if (last_timestamp is None or entry_parsed.timestamp >= last_timestamp) and \
                    start_after_time is None or entry_parsed.timestamp >= start_after_time:
                    # reject old data points ("spilled over")
                    data.append(entry_parsed)
                last_timestamp = entry_parsed.timestamp
    return data


def load_data_all(data_label, start_after_time=None):
    ped_data = load_data_by_type(data_label, "pedometer", start_after_time)
    acc_data = load_data_by_type(data_label, "accelerometer", start_after_time)
    begin_timestamp = acc_data[0].timestamp
    begin_pedometer_data = PedometerData({"timestamp": begin_timestamp,
        "distanceTraveled": 0, "steps": 0})
    ped_data = [begin_pedometer_data] + ped_data
    return ped_data, acc_data

def speed_at_timestamp(step_timestamps, distance_at, walking_intervals, timestamp):
    # print timestamp
    # print step_timestamps[0]
    # print step_timestamps[-1]
    if not step_timestamps[0] <= timestamp < step_timestamps[-1]:
        return None

    # Check if timestamp in known walking intervals
    # If not, return speed 0 

    if not any(interval[0] <= timestamp < interval[1] for interval in walking_intervals):
        return 0       
    # for i in range(len(ped_data) - 1):
    #     entry2 = ped_data[i + 1]
    #     entry1 = ped_data[i]
    #     if entry1.timestamp <= timestamp < entry2.timestamp:
    #         distance = entry2.distanceTraveled - entry1.distanceTraveled
    #         elapsed_time = entry2.timestamp - entry1.timestamp
    #         return distance / elapsed_time

    for i in range(len(step_timestamps)-1):
        ts1 = step_timestamps[i]
        ts2 = step_timestamps[i+1]
        if ts1 <= timestamp < ts2:
            distance = (distance_at[i+1]-distance_at[i]) # feet
            elapsed_time = ts2 - ts1 

            speed = distance/elapsed_time
            return speed 


def steps_count(acc_data, axis='z'):
    '''
    Takes acceleration data array, returns (number of steps, [timestamps of steps])
    '''
    step_count = 0
    distance_traveled = 0
    hit_top, hit_bottom = None, None

    finding_step_start = True
    step_timestamps = []
    steps_at = []
    distance_at = []
    walking_timestamps = []

    for i, entry in enumerate(acc_data):
        if axis == 'z':
            accel = entry.zAcceleration
        elif axis == 'y':
            accel = entry.yAcceleration
        elif axis == 'x':
            accel = entry.xAcceleration
        # check for high peak, start of step
        if finding_step_start:
            if accel > -.93: 
                hit_top = entry.timestamp
                finding_step_start = False
        else:
            # check for low peak, end of step 
            if accel < -1.05:
                hit_bottom = entry.timestamp 
                
            if hit_top and hit_bottom:
                time_diff = hit_bottom - hit_top
                if time_diff < 0: 
                    print "Negative time diff! BAD BAD"

                if .1 < time_diff < .8:
                    step_count += 1
                    distance_traveled = distance_traveled + STEP_LENGTH # inches of an average human step
                    step_timestamps.append(hit_top)
                    steps_at.append(step_count)
                    distance_at.append(distance_traveled)
                # else:
                    # Otherwise, Gap between top and bottom threshold too large or too small, not a step. 

                # Reset hit thresholds
                hit_top, hit_bottom = None, None
                finding_step_start = True

    find_walk_start = True
    start_walk = 0
    for i in range(len(step_timestamps)-1):
        if find_walk_start:
            start_walk = step_timestamps[i]
            find_walk_start = False
        if step_timestamps[i+1] - step_timestamps[i] > STATIONARY_TIME:
            # If >1.5 seconds between next step and this step 
            # we were stationary during this time
            # walk has ended 
            end_walk = step_timestamps[i]
            walking_timestamps.append((start_walk, end_walk))
            find_walk_start = True

    if not find_walk_start:
        # We were walking at the end
        # Add the last walk interval
        walking_timestamps.append((start_walk, step_timestamps[-1]))

    return step_count, step_timestamps, steps_at, distance_at, walking_timestamps

def parse_data(data, data_type):
    assert data_type in DATA_TYPES

    # timestamp = None
    data_by_timestamp = {}
    for entry in data:
        if data_type == "pedometer":
            entry_parsed = PedometerData(entry)
        elif data_type == "accelerometer":
            entry_parsed = MotionData(entry)

        # if entry_parsed.timestamp != timestamp:
        #     timestamp = entry_parsed.timestamp
        # data_by_timestamp[timestamp] = data_by_timestamp.get(timestamp, []) + [entry_parsed]
        data_by_timestamp[entry_parsed.timestamp] = entry_parsed
    return data_by_timestamp


def get_data_from_ibeacon(minor, ibeacons_by_timestamp):
    ibeacon_over_time = []
    for timestamp in list(sorted(ibeacons_by_timestamp.keys())):
        ibeacons = ibeacons_by_timestamp[timestamp] 
        target_ibeacons = filter(lambda ibeacon: ibeacon.minor == minor, ibeacons)
        if len(target_ibeacons) > 0:
            ibeacon_over_time.append(target_ibeacons[0])
    return ibeacon_over_time
