import sys

def to_index(s):
    if s == "":
        return -1
    else:
        return int(s)

def decode_face(tokens, linepos):
    # pos/texture/normal
    # p+n: pos//normal
    f = []
    for vertstr in tokens[1:]:
        vgps = vertstr.split("/")
        if len(vgps) < 3:
            vgps = vgps + ["","",""]
        indices = [to_index(vg) for vg in vgps[0:3]]
        f.append([vertstr] + indices)
    return f

def parse_obj(srcfile):
    faces = []
    attributes = {"v": [], "vn": [], "vt": []}
    for linepos, line in enumerate(srcfile):
        gps = line.strip().split()
        if len(gps) < 2:
            continue
        gtype = gps[0].strip()
        if gtype in attributes:
            values = [float(s) for s in gps[1:]]
            attributes[gtype].append(values)
        elif gtype == "f":
            face = decode_face(gps, linepos)
            if face:
                faces.append(face)
        else:
            print("Unknown line type: {} @ {}".format(gtype, linepos))

    return {position: attributes["v"], normal: attributes["vn"],
            texcoord0: attributes["vt"], faces: faces}

class VertexTable:
    def __init__(self):
        self.table = {}
        self.vlist = []
        self.next_index = 0

    def insert(self, v):
        ret_index = self.next_index
        self.table[v[0]] = self.next_index
        self.vlist.append(v)
        self.next_index += 1
        return ret_index

    def get(self, v):
        if v[0] in self.table:
            return self.table[v[0]]
        return self.insert(v)

# a face in an obj file can specify different indices for position, normal, uv
# this reindexes the vertices so that each vertex has its own attributes
def reindex_faces(data):
    vertex_table = VertexTable()
    num_malformed = 0
    num_quads = 0
    num_good = 0
    indices = []
    for f in data["faces"]:
        if len(f) < 3:
            num_malformed += 1
            continue
        elif len(f) > 3:
            num_quads += 1
            continue
        else:
            newtri = [vertex_table.get(v) for v in f]
            indices.append(newtri)
    print("Reindexed to {} vertices.".format(vertex_table.next_index))
    if num_malformed > 0:
        print("{} malformed faces.".format(num_malformed))
    if num_quads > 0:
        print("{} quads.".format(num_quads))
    return (indices, vertex_table.vlist)
