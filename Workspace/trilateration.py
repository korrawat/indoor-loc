import numpy as np
from scipy.optimize import minimize


def single_error(beacon_location, beacon_distance, predicted_location):
    predicted_distance = np.linalg.norm(beacon_location - predicted_location)
    return abs(beacon_distance - predicted_distance)


def mean_error(predicted_location, beacon_locations, beacon_distances, L2):
    '''
        beacon_locations and beacon_distances must have the same length.
        If L2 is True, use L2 norm to average the error. Use L1 otherwise.
    '''
    assert len(beacon_locations) == len(beacon_distances)
    total_error = 0.0
    for beacon_location, beacon_distance in zip(beacon_locations, beacon_distances):
        exponent = 2 if L2 else 1
        total_error += pow(single_error(beacon_location, beacon_distance, predicted_location), exponent)
    return total_error / len(beacon_distances)


def trilaterate(beacon_locations_dict, beacon_distances_dict, L2=True):
    '''
        beacon_locations_dict is a dictionary mapping each beacon id to its location
        beacon_distances_dict is a dictionary mapping each beacon id to its estimated distance
    '''
    valid_beacon_ids = set(beacon_locations_dict.keys()) & set(beacon_distances_dict.keys())
    if len(valid_beacon_ids) < 3:
        # too few data points; can't trilaterate
        return None

    beacon_locations = []
    beacon_distances = []
    initial_location_guess = None
    min_distance = float('inf')
    for beacon_id in valid_beacon_ids:
        location = beacon_locations_dict[beacon_id]
        distance = beacon_distances_dict[beacon_id]
        beacon_locations.append(location)
        beacon_distances.append(distance)
        if distance < min_distance:
            # initial guess is the location of beacon with largest rssi
            min_distance = distance
            initial_location_guess = location

    result = minimize(mean_error, initial_location_guess,
                      args=(beacon_locations, beacon_distances, L2),
                      method='L-BFGS-B')
    assert result.success
    return result.x
        
        
        
        
        
        
        
        


