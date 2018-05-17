import numpy as np
from scipy.optimize import minimize
import itertools

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
    if not result.success:
        return None
    return result.x

def single_ratio_error(predicted_location, beacon_location1, beacon_location2, observed_ratio):
    predicted_distance_beacon1 = np.linalg.norm(beacon_location1 - predicted_location)
    predicted_distance_beacon2 = np.linalg.norm(beacon_location2 - predicted_location)
    
    if predicted_distance_beacon2 == 0.0:
        return 1000

    predicted_ratio = predicted_distance_beacon1/predicted_distance_beacon2
    print "predicted_ratio", predicted_ratio

    return abs(observed_ratio - predicted_ratio)

def ratio_error(predicted_location, beacon_locations_dict, beacon_distance_ratios, pairs):
    print "predicted_location", predicted_location
    total_error = 0
    for pair in pairs:
        print "Pair", pair
        total_error += single_ratio_error(predicted_location, beacon_locations_dict[pair[0]], beacon_locations_dict[pair[1]], beacon_distance_ratios[pair])

    print "total_error", total_error
    return total_error/len(pairs)


def trilaterate_ratios(beacon_locations_dict, beacon_distances_dict):
    valid_beacon_ids = set(beacon_locations_dict.keys()) & set(beacon_distances_dict.keys())

    if len(valid_beacon_ids) < 3:
        return None

    pairs = list(itertools.combinations(valid_beacon_ids, 2))

    beacon_distance_ratios = {}
    for pair in pairs:
        distanceratio = beacon_distances_dict[pair[0]]/beacon_distances_dict[pair[1]]
        beacon_distance_ratios[pair] = distanceratio

    print "beacon distance ratios", beacon_distance_ratios
    # Get initial location guess
    min_distance = float('inf')
    for beacon_id in valid_beacon_ids:
        distance = beacon_distances_dict[beacon_id]
        if distance < min_distance:
            # initial guess is the location of beacon with largest rssi
            min_distance = distance
            initial_location_guess = beacon_locations_dict[beacon_id]

    result = minimize(ratio_error, initial_location_guess, args = (beacon_locations_dict, beacon_distance_ratios, pairs), 
        method = 'L-BFGS-B')

    print "Returning result", result.x
    if not result.success:
        return None
    return result.x
