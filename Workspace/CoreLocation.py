import matplotlib.pyplot as plt


class Point2D:
    def __init__(self, x, y, timestamp):
        self.x = x
        self.y = y
        self.coord = (x, y)
        self.timestamp = timestamp


    @staticmethod
    def numpy_to_point(np_coord, timestamp):
        return Point2D(np_coord[0], np_coord[1], timestamp)


    def plot(self, ax, option='go', label=None):
        OFFSET = 5
        ax.plot(self.x, self.y, option)
        if label:
            ax.annotate(label, (self.x, self.y), xytext=(self.x + OFFSET, self.y + OFFSET))


class Locations:
    def __init__(self, subject=None):
        self.subject = subject
        self.points = []


    def add_np_point(self, np_point, timestamp):
        self.points.append(Point2D(np_point[0], np_point[1], timestamp))


    def visualize(self, actual_loc=None, ax_limits=None, fig_ax=(None, None)):
        fig, ax = fig_ax
        if fig == None or ax == None:
            fig, ax = plt.subplots()
        xs = list(map(lambda p: p.x, self.points))
        ys = list(map(lambda p: p.y, self.points))
        ax.plot(xs, ys, 'go-')
        if actual_loc:
            actual_loc.plot(ax, 'ro', label=self.subject)
        if ax_limits:
            plt.axis(ax_limits)
        return ax


    def plot(self, actual_loc=None, ax_limits=None, fig_ax=(None, None)):
        fig, ax = fig_ax
        if fig == None or ax == None:
            fig, ax = plt.subplots()
        for point in self.points:
            point.plot(ax)
        if actual_loc:
            actual_loc.plot(ax, 'ro', label=self.subject)
        if ax_limits:
            plt.axis(ax_limits)
        return ax
