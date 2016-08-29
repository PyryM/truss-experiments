# compacts a .pts ascii point file into a binary file

import sys
import struct

def compact_pts(src, dest):
    npts = 0
    for idx, line in enumerate(src):
        if idx == 0:
            # write the number of points
            npts = int(line.strip())
            dest.write(struct.pack('I', npts))
        elif idx > 1:
            if idx-2 >= npts:
                print("Overly many points! " +
                      "Expected {}, now at {}".format(npts, idx-2))
            elif idx-2 == npts-1:
                print("Reached final expected point.")
            # a point
            gps = line.strip().split(" ")
            if len(gps) != 7:
                print("Unknown line {}: {}".format(idx, line))
                continue
            xyz = [float(x) for x in gps[0:3]]
            rgba = [int(x) for x in gps[3:7]]
            dest.write(struct.pack('fffBBBB', xyz[0], xyz[1], xyz[2],
                                       rgba[0], rgba[1], rgba[2], rgba[3]))

if __name__ == '__main__':
    with open(sys.argv[1], "rt") as src:
        with open(sys.argv[2], "wb") as dest:
            compact_pts(src, dest)
