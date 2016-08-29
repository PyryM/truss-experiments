-- staticpointcloud.t
--
-- a static point cloud

local class = require("class")
local math = require("math")
local Matrix4 = math.Matrix4
local Quaternion = math.Quaternion
local Vector = math.Vector
local geometry = require("gfx/geometry.t")
local Object3D = require("gfx/object3d.t").Object3D
local uniforms = require("gfx/uniforms.t")
local shaderutils = require("utils/shaderutils.t")

local m = {}

local StaticPointCloud = Object3D:extend("StaticPointCloud")

function StaticPointCloud:init(pointlist, npts)
    StaticPointCloud.super.init(self)
    self.npts = npts
    self:createBuffers_(pointlist, npts)
    self.material = {shadername = "staticpointcloud",
                     pointParams = math.Vector(0.002,1.0,3.0,2.0)}
    self.mat = self.material
end

function StaticPointCloud:setPointSize(p)
    self.mat.pointParams.elem.x = p
end

function StaticPointCloud:createBuffers_(pointlist, npts, useTriangles)
    local vdefs = require("gfx/vertexdefs.t")
    local vinfo = vdefs.createStandardVertexType({"position",
                                                  "normal",
                                                  "color0"})
    if useTriangles then
        self.geo = geometry.StaticGeometry():allocate(vinfo, npts*3, npts*3)
        m.setTriPointData_(self.geo, pointlist, npts)
    else
        self.geo = geometry.StaticGeometry():allocate(vinfo, npts*4, npts*6)
        m.setQuadPointData_(self.geo, pointlist, npts)
    end
    self.geo:build()
end

local StaticPointCloudShader = class("StaticPointCloudShader")
function StaticPointCloudShader:init(vshader, fshader)
    local pointParams = uniforms.Uniform("u_pointParams", uniforms.VECTOR, 1)
    local matUniforms = uniforms.UniformSet()
    matUniforms:add(pointParams, "pointParams")
    self.uniforms = matUniforms
    local vertexProgram = vshader
    self.program = shaderutils.loadProgram(vertexProgram or "vs_staticpoints",
                                           fshader or "fs_staticpoints")
end

-- creates an array of particles
function m.setQuadPointData_(geo, pointlist, npts)
    -- 3:(-1, 1) +------+ 2:(1, 1)
    --           |    / |
    --           | /    |
    -- 0:(-1,-1) +------+ 1:(1,-1)
    local normals = {{-1,-1,0}, {1,-1,0}, {1,1,0}, {-1,1,0}}
    local vpos = 0
    local ipos = 0

    local vdata = geo.verts
    local idata = geo.indices

    for idx = 0,npts-1 do
        -- all four vertices share the same position
        -- but have different normals (shader will expand based on normal)
        local p = pointlist[idx]
        for ii = 0,3 do
            for jj = 0,2 do
                vdata[vpos+ii].position[jj] = p.position[jj]
                vdata[vpos+ii].normal[jj] = normals[ii+1][jj+1]
            end
            for jj = 0,3 do
                vdata[vpos+ii].color0[jj] = p.color[jj]
            end
        end
        idata[ipos+0], idata[ipos+1], idata[ipos+2] = vpos+0, vpos+1, vpos+2
        idata[ipos+3], idata[ipos+4], idata[ipos+5] = vpos+0, vpos+2, vpos+3
        ipos = ipos + 6
        vpos = vpos + 4
    end
end

struct m.BinPoint {
    position: float[3];
    color: uint8[4];
}
m.BinPoint:complete()

-- read a little endian uint32
terra m.readUint32LE(buffer: &uint8, startpos: uint32)
	var ret: uint32 = [uint32](buffer[startpos  ])       or
					  [uint32](buffer[startpos+1]) << 8  or
					  [uint32](buffer[startpos+2]) << 16 or
					  [uint32](buffer[startpos+3]) << 24
	return ret
end

terra m.castToPoints(buffer: &uint8, startpos: uint32)
    var ret: &m.BinPoint = [&m.BinPoint](&(buffer[startpos]))
    return ret
end

function m.loadBinPoints(filename)
    local starttime = tic()
	local srcMessage = truss.truss_load_file(filename)
	if srcMessage == nil then
		log.error("Error: unable to open file " .. filename)
		return nil
	end

	local npts = m.readUint32LE(srcMessage.data, 0)
    log.info(filename .. " contains " .. npts .. " points.")
    if srcMessage.data_length ~= (npts*16 + 4) then
        log.error("Size mismatch: expected " .. (npts*16+4) ..
                  ", got " .. srcMessage.data_length)
        return nil
    end

    local pointlist = m.castToPoints(srcMessage.data, 4)
    local ret = m.StaticPointCloud(pointlist, npts)

	truss.truss_release_message(srcMessage)

    local dtime = toc(starttime)
	log.info("Loaded " .. filename .. " in " .. (dtime*1000.0) .. " ms")
	return ret
end

m.StaticPointCloud = StaticPointCloud
m.StaticPointCloudShader = StaticPointCloudShader
return m
