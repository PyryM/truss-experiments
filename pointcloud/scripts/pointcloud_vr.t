-- pointcloud_vr.t
--
-- view a pointcloud in vr

local VRApp = require("vr/vrapp.t").VRApp
local uvsphere = require("geometry/uvsphere.t")
local icosphere = require("geometry/icosphere.t")
local pbr = require("shaders/pbr.t")
local gfx = require("gfx")
local openvr = require("vr/openvr.t")
local objloader = require("loaders/objloader.t")
local flat = require("shaders/flat.t")
local ezteleport = require("vr/ezteleport.t")
local pcloud = require('staticpointcloud.t')

CaveApp = VRApp:extend("CaveApp")

function CaveApp:onControllerConnected(idx, controllerobj)
    local axisObj = gfx.Object3D(axisGeo, axisMat)
    controllerobj:add(axisObj)
    log.info("Added axis?")
    if idx == 1 then
        teleporter.controller = controllerobj
    end
end

function CaveApp:preRender()
    -- nothing to do ATM
end

function CaveApp:initPipeline()
    self:setupTargets()
    self.pipeline = gfx.Pipeline()

    local pbr = require("shaders/pbr.t")
    local flat = require("shaders/flat.t")
    local forwardpass = gfx.MultiShaderStage({
        renderTarget = nil,
        clear = {color = 0x303030ff},
        shaders = {solid = pbr.PBRShader(),
                   staticpointcloud = pcloud.StaticPointCloudShader(),
                   flatTextured = flat.FlatShader({texture=true}),
                   flatTexturedSkybox = flat.FlatShader({texture=true, skybox=true})}
    })
    self.forwardpass = forwardpass

    for i = 1,2 do
        local eyePassSolid = forwardpass:duplicate(self.targets[i])
        self.pipeline:add("forward_" .. i, eyePassSolid, self.eyeContexts[i])
    end

    -- finalize pipeline
    self.pipeline:setupViews(0)
    self.windowView = self.pipeline.nextAvailableView
    self.backbuffer:setViewClear(self.windowView, {color = 0x303030ff,
                                                   depth = 1.0})

    self:setDefaultLights()
end

function createGeometry()
    --add pointcloud
    thecloud = pcloud.loadBinPoints("models/room.binpts")
    thecloud:setPointSize(0.02)
    --thecloud.position:set(0.0, 1.0, 0.0)
    thecloud.quaternion:fromEuler({x=-math.pi / 2,y=0,z=0})
    thecloud:updateMatrix()
    app.scene:add(thecloud)
    --app.roomroot.position:set(0,10,0)
    --app.roomroot:updateMatrix()

    axisGeo = require("geometry/widgets.t").axisWidgetGeo("axis_widget_geo", 0.1)
    axisMat = pbr.PBRMaterial("solid"):roughness(0.8):diffuse(0.1,0.05,0.001)
    axisMat:tint(0.8, 0.4, 0.01)

    app.roomroot:add(gfx.Object3D(axisGeo, axisMat))

    -- create the teleport marker
    local spheregeo = require("geometry/icosphere.t").icosphereGeo(0.1, 3, "icosphere")
    teleportmarker = gfx.Object3D(spheregeo, axisMat)
    app.scene:add(teleportmarker)

    teleporter = ezteleport.EZTeleport(app.roomroot, teleportmarker)
end

function init()
    app = CaveApp({title = "caves",
                         width = 1280,
                         height = 720})
    createGeometry()
end

function update()
    teleporter:update()
    app:update()
end
