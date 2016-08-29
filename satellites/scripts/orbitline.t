-- line.t
--
-- a shader-based projected line

local class = require("class")
local math = require("math")
local Matrix4 = math.Matrix4
local Quaternion = math.Quaternion
local Vector = math.Vector
local gfx = require("gfx")
local shaderutils = require("utils/shaderutils.t")

local m = {}

local ColorLineObject = gfx.Object3D:extend("ColorLineObject")

local internals = {}
struct internals.VertexType {
    position: float[3];
    normal: float[3];
    color0: float[4];
    color1: uint8[4];
}

local terra declareLineVertexType(vertDecl: &bgfx.bgfx_vertex_decl_t)
    bgfx.bgfx_vertex_decl_begin(vertDecl, bgfx.bgfx_get_renderer_type())
    bgfx.bgfx_vertex_decl_add(vertDecl, bgfx.BGFX_ATTRIB_POSITION, 3,
                                bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
    bgfx.bgfx_vertex_decl_add(vertDecl, bgfx.BGFX_ATTRIB_NORMAL, 3,
                                bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
    bgfx.bgfx_vertex_decl_add(vertDecl, bgfx.BGFX_ATTRIB_COLOR0, 4,
                                bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
    bgfx.bgfx_vertex_decl_add(vertDecl, bgfx.BGFX_ATTRIB_COLOR1, 4,
                                bgfx.BGFX_ATTRIB_TYPE_UINT8, true, false)
    bgfx.bgfx_vertex_decl_end(vertDecl)
end

local function getVertexInfo()
    if internals.vertInfo == nil then
        local vspec = terralib.new(bgfx.bgfx_vertex_decl_t)
        declareLineVertexType(vspec)
        internals.vertInfo = {vertType = internals.VertexType,
                              vertDecl = vspec,
                              attributes = {position=3, normal=3, color0=4, color1=4}}
    end

    return internals.vertInfo
end

function ColorLineObject:init(maxpoints, dynamic)
    ColorLineObject.super.init(self)

    self.maxpoints = maxpoints
    self.dynamic = not not dynamic -- coerce to boolean
    self:createBuffers_()
    self.material = m.OrbitLineMaterial()
    self.mat = self.material

    self.npts_ = 0
    self.vertidx_ = 0
    self.idxidx_ = 0
end

local function packVec3(dest, arr)
    -- dest is a 0-indexed terra type, arr is a 1-index lua table
    dest[0] = arr[1]
    dest[1] = arr[2]
    dest[2] = arr[3]
end

local function packVertex(dest, curPoint, prevPoint, nextPoint, dir, color)
    packVec3(dest.position, curPoint)
    packVec3(dest.normal, prevPoint)
    packVec3(dest.color0, nextPoint)
    packVec3(dest.color1, color)
    dest.color0[3] = dir
end

function ColorLineObject:appendSegment_(segpoints, segcolors, vertidx, idxidx)
    local npts = #segpoints
    local nlinesegs = npts - 1
    local startvert = vertidx

    -- emit two vertices per point
    local vbuf = self.geo.verts
    for i = 1,npts do
        local curpoint = segpoints[i]
        local curcolor = segcolors[i] or segcolors[1]
        -- shader detects line start if prevpoint==curpoint
        --                line end   if nextpoint==curpoint
        local prevpoint = segpoints[i-1] or curpoint
        local nextpoint = segpoints[i+1] or curpoint

        packVertex(vbuf[vertidx]  , curpoint, prevpoint, nextpoint,  1.0, curcolor)
        packVertex(vbuf[vertidx+1], curpoint, prevpoint, nextpoint, -1.0, curcolor)

        vertidx = vertidx + 2
    end

    -- emit two triangles (six indices) per segment
    -- note that we have allocated two triangles *per vertex*, so in the worst
    -- case (all disconnected line segments with 2 points), we'll be wasting
    -- half the index buffer
    local ibuf = self.geo.indices
    for i = 1,nlinesegs do
        ibuf[idxidx+0] = startvert + 0
        ibuf[idxidx+1] = startvert + 1
        ibuf[idxidx+2] = startvert + 2
        ibuf[idxidx+3] = startvert + 2
        ibuf[idxidx+4] = startvert + 1
        ibuf[idxidx+5] = startvert + 3
        idxidx = idxidx + 6
        startvert = startvert + 2
    end

    return vertidx, idxidx
end

function ColorLineObject:createBuffers_()
    local vinfo = getVertexInfo()
    log.debug("Allocating line buffers...")
    if self.dynamic then
        self.geo = gfx.DynamicGeometry()
    else
        self.geo = gfx.StaticGeometry()
    end
    self.geo:allocate(vinfo, self.maxpoints * 2, self.maxpoints * 6)
end

-- Update the line buffers: for a static line (dynamic == false)
-- this will only work once
function ColorLineObject:setPoints(lines, colors)
    self:clear()
    local nlines = #lines
    for i = 1,nlines do
        self:addCurveSegment(lines[i], colors[i])
    end
    self:build()
end

function ColorLineObject:clear()
    self.npts_ = 0
    self.vertidx_ = 0
    self.idxidx_ = 0
    return self
end

function ColorLineObject:addCurveSegment(positions, colors)
    local newpoints = #positions
    if self.npts_ + newpoints > self.maxpoints then
        log.error("Exceeded max points! ["
                            .. (self.npts_+newpoints)
                            .. "/" .. self.maxpoints .. "]")
        return
    end
    self.vertidx_, self.idxidx_ = self:appendSegment_(positions, colors,
                                                    self.vertidx_, self.idxidx_)
end

function ColorLineObject:build()
    self.geo:update()
end

local OrbitLineShader = class("OrbitLineShader")
function OrbitLineShader:init(vshader, fshader)
    local color = gfx.Uniform("u_color", gfx.VECTOR, 1)
    local thickness = gfx.Uniform("u_thickness", gfx.VECTOR, 1)
    local matUniforms = gfx.UniformSet()
    matUniforms:add(color, "color")
    matUniforms:add(thickness, "thickness")

    -- want additive blending:
    self.state = math.combineFlags(
                 bgfx_const.BGFX_STATE_RGB_WRITE,
                 bgfx_const.BGFX_STATE_ALPHA_WRITE,
                 bgfx_const.BGFX_STATE_DEPTH_TEST_LESS,
                 bgfx_const.BGFX_STATE_CULL_CW,
                 bgfx_const.BGFX_STATE_MSAA,
                 bgfx_const.BGFX_STATE_BLEND_ADD)
    self.uniforms = matUniforms
    self.program = shaderutils.loadProgram(vshader or "vs_line_colored",
                                           fshader or "fs_line_colored")
end

local function OrbitLineMaterial(pass)
    return {shadername = pass or "orbitline",
            color = math.Vector(1.0,1.0,1.0,1.0),
            thickness = math.Vector(0.005)}
end

function m.createTestOrbits(norbits, npoints)
    local totalPoints = norbits*npoints
    local orbits = ColorLineObject(totalPoints, false)
    orbits:clear()
    local tempcolor = Vector()
    local tempposition = Vector()
    local axis0 = Vector()
    local axis1 = Vector()
    for i = 1,norbits do
        local color = tempcolor:randUniform(0,40):toArray()
        axis0:set(1 + math.random()*0.7,0,0)
        axis1:set(0,math.random()*2,1 + math.random()*0.7)
        local pts = {}
        for j = 1,npoints do
            local theta = math.pi*2.0 * (j-1)/(npoints-1)
            tempposition:linComb(axis0, axis1, math.cos(theta), math.sin(theta))
            tempposition.elem.y = tempposition.elem.y + 1.0
            local v = tempposition:toArray()
            --v[2] = 1.0
            table.insert(pts, v)
        end
        orbits:addCurveSegment(pts, {color})
    end
    orbits:build()
    return orbits
end

m.ColorLineObject = ColorLineObject
m.OrbitLineShader = OrbitLineShader
m.OrbitLineMaterial = OrbitLineMaterial

return m
