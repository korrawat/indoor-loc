import numpy as np


class Coordinate(np.array):
    def __init__(self, x, y, z=0):
        self.x = x
        self.y = y
        self.z = z
        self.coordinate = np.array([x, y, z])


    def __repr__(self):
        return "3D({},{},{})".format(self.x, self.y, self.z)