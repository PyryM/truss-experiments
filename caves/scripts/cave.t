-- cave.t
--
-- view a photogrammetric cave in vr

local VRApp = require("vr/vrapp.t").VRApp
local uvsphere = require("geometry/uvsphere.t")
local icosphere = require("geometry/icosphere.t")
local pbr = require("shaders/pbr.t")
local gfx = require("gfx")
local openvr = require("vr/openvr.t")
local objloader = require("loaders/objloader.t")
local flat = require("shaders/flat.t")
local ezteleport = require("vr/ezteleport.t")

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

function randu(magnitude)
    return (math.random() * 2.0 - 1.0)*(magnitude or 1.0)
end

function createGeometry()
    local geo = uvsphere.uvSphereGeo({latDivs = 60, lonDivs = 60}, "uvsphere")
    local mat = pbr.PBRMaterial("solid"):roughness(0.8):tint(0.1,0.1,0.1)

    --skytex = require("utils/textureutils.t").loadTexture("textures/starmap_8k.ktx")
    skytex = require("utils/textureutils.t").loadTexture("textures/fairyland.ktx")
    local skymat = flat.FlatMaterial({diffuseMap = skytex, skybox=true})
    local skybox = gfx.Object3D(geo, skymat)
    skybox.scale:set(-60, -60, -60)
    skybox.quaternion:fromEuler({math.pi,0,0}, 'ZYX')
    skybox:updateMatrix()
    app.scene:add(skybox)

    --add cave model
    local cavedata = objloader.loadOBJ("models/cave.obj")
    local vertInfo = gfx.createStandardVertexType({"position", "normal", "texcoord0"})
    local cavegeo = gfx.StaticGeometry("cave"):fromData(vertInfo, cavedata)
    --local cavetex = require("utils/textureutils.t").loadTexture("textures/cave_8k.ktx")
    --local cavetex = require("utils/textureutils.t").loadTexture("textures/cone.png")
    local cavetex = require("utils/textureutils.t").loadTexture("textures/cave_8k.ktx")
    local cavemat = flat.FlatMaterial({diffuseMap = cavetex})
    thecave = gfx.Object3D(cavegeo, cavemat)
    thecave.scale:set(1,1,1)
    thecave.position:set(0,0,0)
    thecave.quaternion:fromEuler({-math.pi/2,0,0}, 'ZYX')
    thecave:updateMatrix()
    app.scene:add(thecave)
    --app.roomroot.position:set(0,10,0)
    --app.roomroot:updateMatrix()

    axisGeo = require("geometry/widgets.t").axisWidgetGeo("axis_widget_geo", 0.1)
    axisMat = pbr.PBRMaterial("solid"):roughness(0.8):diffuse(0.2,0.2,0.2)

    app.scene:add(gfx.Object3D(axisGeo, axisMat))

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
