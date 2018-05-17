import matplotlib.pyplot as plt
import numpy as np
import json


class Point2D:
    def __init__(self, x, y, timestamp=None, label=None):
        self.x = x
        self.y = y
        self.coord = (x, y)
        self.timestamp = timestamp
        self.label = label


    @staticmethod
    def numpy_to_point(np_coord, timestamp=None, label=None):
        return Point2D(np_coord[0], np_coord[1], timestamp, label)


    def plot(self, ax, option='go', label=None, show_point_label=False):
        '''
            show_point_label shows Point2D's label attribute
            label is an explicit label and overrides show_point_label if exists
        '''
        OFFSET = 5
        ax.plot(self.x, self.y, option)
        if label or show_point_label:
            label_to_use = label if label else self.label
            ax.annotate(label_to_use, (self.x, self.y), xytext=(self.x + OFFSET, self.y + OFFSET))


    def translate(self, dx, dy):
        return Point2D(self.x + dx, self.y + dy, self.timestamp, self.label)
    
    def __repr__(self):
        return "{}: {}".format(self.timestamp, self.coord)


class Locations:
    def __init__(self, subject=None):
        self.subject = subject
        self.points = []


    def add_np_point(self, np_point, timestamp=None, label=None):
        self.points.append(Point2D(np_point[0], np_point[1], timestamp, label))


    def visualize(self, actual_loc=None, ax_limits=None, fig_ax=(None, None), downsample=None, arrow_color=None, first_arrow_color=None):
        fig, ax = fig_ax
        if fig == None or ax == None:
            fig, ax = plt.subplots()
        xs = np.array(map(lambda p: p.x, self.points))
        ys = np.array(map(lambda p: p.y, self.points))
        if downsample:
            xs = xs[::downsample]
            ys = ys[::downsample]
        # ax.plot(xs, ys, 'g.-')
        ax.quiver(xs[0], ys[0], xs[1]-xs[0], ys[1]-ys[0], scale_units='xy', angles='xy', scale=1, color=first_arrow_color)
        ax.quiver(xs[1:-1], ys[1:-1], xs[2:]-xs[1:-1], ys[2:]-ys[1:-1], scale_units='xy', angles='xy', scale=1, color=arrow_color)
        if actual_loc:
            actual_loc.plot(ax, 'ro', label=self.subject)
        if ax_limits:
            plt.axis(ax_limits)
        return ax


    def plot(self, actual_loc=None, ax_limits=None, fig_ax=(None, None), show_point_label=False, option='ro'):
        fig, ax = fig_ax
        if fig == None or ax == None:
            fig, ax = plt.subplots()
        for point in self.points:
            point.plot(ax, option=option, show_point_label=show_point_label)
        if actual_loc:
            actual_loc.plot(ax, 'go', label=self.subject, show_point_label=show_point_label)
        if ax_limits:
            plt.axis(ax_limits)
        return ax


    def translate_all(self, dx, dy):
        translated_Locations = Locations(self.subject)
        for point in self.points:
            translated_point = point.translate(dx, dy)
            translated_Locations.points.append(translated_point)
        return translated_Locations


    def get_dict_by_label(self):
        '''
            dict representation of self.points, key = point.label, value = point.coord
        '''
        d = {}
        for point in self.points:
            assert point.label is not None
            d[point.label] = point.coord
        return d
    
    def __repr__(self):
        return "Locs_{}: {}".format(self.subject, self.points)


class Room:
    def __init__(self, label=None):
        self.label = label
        self.beacons = Locations()
        self.turn_landmarks = Locations()
        self.step_landmarks = Locations()
        self.initial_location = None


    def add_beacons(self, beacon_locations):
        for _id, location in beacon_locations.items():
            _id = int(_id)
            self.beacons.add_np_point(location, label=_id)


    def add_turn_landmarks(self, initial_location, distance_to_landmarks):
        total_steps = 0
        x, y = tuple(initial_location)
        self.turn_landmarks.add_np_point((x, y), label=total_steps)
        for distance_to_landmark in distance_to_landmarks:
            dx, dy, steps = distance_to_landmark
            total_steps += steps
            x += dx
            y += dy
            self.turn_landmarks.add_np_point((x, y), label=total_steps)


    def interpolate_step_landmarks(self):
        # interpolate
        initial_location = self.turn_landmarks.points[0]
        self.step_landmarks.add_np_point(initial_location.coord, label=initial_location.label)
        for i in range(len(self.turn_landmarks.points) - 1):
            point1 = self.turn_landmarks.points[i]
            point2 = self.turn_landmarks.points[i + 1]
            step1, (x1, y1) = point1.label, point1.coord
            step2, (x2, y2) = point2.label, point2.coord
            ds = step2 - step1
            dx, dy = x2 - x1, y2 - y1
            for s in range(1, ds + 1):
                walk_coordinate = (x1 + 1. * s / ds * dx, y1 + 1. * s / ds * dy)
                total_steps = step1 + s
                self.step_landmarks.add_np_point(walk_coordinate, label=total_steps)


    @staticmethod
    def import_room_data(measurement_file, label):
        with open(measurement_file, 'r') as f:
            rooms_data = json.load(f)
        room_measurements = None
        for room_data in rooms_data:
            if room_data['label'] == label:
                room_measurements = room_data['measurements']
                break
        assert room_measurements is not None, "room data not found"

        room = Room(label)
        initial_location = room_measurements['initial_location']
        room.initial_location = Point2D(initial_location[0], initial_location[1])
        room.add_beacons(room_measurements['beacon_locations'])
        room.add_turn_landmarks(initial_location, room_measurements['distance_to_landmarks'])
        room.interpolate_step_landmarks()
        return room


    def visualize_with_groundtruth(self, predicted_locations, translate_init_loc=False, translate=(0, 0), downsample=1):
        fig, ax = plt.subplots(figsize=(6,8))
        dx, dy = 0, 0
        if translate_init_loc:
            dx, dy = self.step_landmarks.points[0].coord
        predicted_locations = predicted_locations.translate_all(dx + translate[0], dy + translate[1])
        ax = predicted_locations.visualize(fig_ax=(fig, ax), arrow_color='red', downsample=downsample)
        ax = self.step_landmarks.visualize(fig_ax=(fig, ax), arrow_color='green')
        ax = self.beacons.plot(fig_ax=(fig, ax), option='bo', show_point_label=True)
        ax.axis('equal')
        plt.gca().invert_yaxis()
        plt.grid()
        plt.show()

    def plot_with_groundtruth(self, predicted_locations, translate_init_loc=False, translate=(0, 0), downsample=1):
        fig, ax = plt.subplots(figsize=(6,8))
        dx, dy = 0, 0
        if translate_init_loc:
            dx, dy = self.step_landmarks.points[0].coord
        predicted_locations = predicted_locations.translate_all(dx + translate[0], dy + translate[1])
        ax = predicted_locations.plot(fig_ax=(fig, ax))
        ax = self.step_landmarks.visualize(fig_ax=(fig, ax), arrow_color='green')
        ax = self.beacons.plot(fig_ax=(fig, ax), option='bo', show_point_label=True)
        ax.axis('equal')
        plt.gca().invert_yaxis()
        plt.grid()
        plt.show()
