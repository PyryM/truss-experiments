-- pointcloudtest.t
--
-- testing big point clouds

local AppScaffold = require("utils/appscaffold.t").AppScaffold
local gfx = require("gfx")
local pbr = require("shaders/pbr.t")
local line = require('geometry/line.t')
local grid = require('geometry/grid.t')
local pcloud = require('staticpointcloud.t')
local stringutils = require('utils/stringutils.t')

function createGeometry()
    thegrid = grid.Grid({thickness = 0.01})
    thegrid.quaternion:fromEuler({math.pi/2, 0, 0})
    thegrid:updateMatrix()
    app.scene:add(thegrid)

    pwidth = 128*2
    pheight = 106*2
    ptex = gfx.MemTexture(pwidth, pheight)
    thecloud = pcloud.loadBinPoints("models/room.binpts")
    thecloud:setPointSize(0.004)
    --thecloud.position:set(0.0, 1.0, 0.0)
    thecloud.quaternion:fromEuler({x=-math.pi / 2,y=0,z=0})
    thecloud:updateMatrix()
    app.scene:add(thecloud)
end

function init()
    app = AppScaffold({title = "pointcloud",
                       width = 1280,
                       height = 720,
                       usenvg = false})
    app.preRender = preRender

    rotator = gfx.Object3D()
    app.scene:add(rotator)
    rotator:add(app.camera)

    app.camera.position:set(0.0, 0.2, 0.75)
    app.camera:updateMatrix()

    local fpass = app.pipeline.stages.forwardpass
    fpass:addShader("line", line.LineShader("vs_line", "fs_line_depth"))
    fpass:addShader("staticpointcloud", pcloud.StaticPointCloudShader())

    createGeometry()
end

function update()
    rotator.quaternion:fromEuler({x=0,y=app.time*0.25,z=0})
    rotator:updateMatrix()
    app:update()
end
