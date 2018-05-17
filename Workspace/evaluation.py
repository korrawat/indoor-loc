import numpy as np
import matplotlib as plt

from math import atan2,degrees

def GetAngle(p1, p2):
    xDiff = p2.x - p1.x
    yDiff = p2.y - p1.y
    return degrees(atan2(yDiff, xDiff))

def evaluate(predicted_locs, ground_truth_locs):
    # start_timestamp = int(predicted_locs[0].times)
    # end_timestamp = int(predicted_locs[-1])

    num_groundtruth_locs = len(ground_truth_locs.points)
    # times = np.linspace(start_timestamp, end_timestamp, num_groundtruth_locs)

    subsampled_indices = range(0, len(predicted_locs.points), num_groundtruth_locs)

    subsampled_predicted_locs = [predicted_locs.points[i] for i in subsampled_indices]
    
    localization_error = []
    times = []
    for (pred_loc, truth_loc) in zip(subsampled_predicted_locs, ground_truth_locs.points):
        print pred_loc.coord, truth_loc.coord
        error = np.linalg.norm(np.asarray(truth_loc.coord) - np.asarray(pred_loc.coord))
        times.append(pred_loc.timestamp)
        localization_error.append(error)
    return localization_error, times

def evaluate_angle(predicted_locs, ground_truth_locs):
    num_groundtruth_locs = len(ground_truth_locs.points)

    subsampled_indices = range(0, len(predicted_locs.points), num_groundtruth_locs)
    subsampled_predicted_locs = [predicted_locs.points[i] for i in subsampled_indices]

    angle_errors = []
    times = []
    for i, (pred_loc, truth_loc) in enumerate(zip(subsampled_predicted_locs, ground_truth_locs.points)):
        if i >= len(subsampled_predicted_locs)-1:
            break 

        trueAngle = GetAngle(ground_truth_locs.points[i], ground_truth_locs.points[i+1])
        angle = GetAngle(subsampled_predicted_locs[i], subsampled_predicted_locs[i+1])

        # print trueAngle, angle
        # angleerror = 180 - abs(abs(trueAngle%360. - angle%360.)) - 180
        angleerror = trueAngle - angle
        angleerror = angleerror-360 if angleerror > 180 else angleerror
        angleerror = angleerror+360 if angleerror < -180 else angleerror

        angle_errors.append(abs(angleerror))
        times.append(pred_loc.timestamp)
    
    return angle_errors, times
