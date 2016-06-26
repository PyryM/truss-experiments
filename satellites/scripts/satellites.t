-- satellites.t
--
-- satellite visualization

local VRApp = require("vr/vrapp.t").VRApp
local uvsphere = require("geometry/uvsphere.t")
local icosphere = require("geometry/icosphere.t")
local pbr = require("shaders/pbr.t")
local gfx = require("gfx")
local openvr = require("vr/openvr.t")

SatelliteApp = VRApp:extend("SatelliteApp")

function SatelliteApp:onControllerConnected(idx, controllerobj)
    local axisObj = gfx.Object3D(axisGeo, axisMat)
    controllerobj:add(axisObj)
    log.info("Added axis?")
end

function SatelliteApp:preRender()
    -- nothing to do ATM
end

function SatelliteApp:initPipeline()
    self:setupTargets()
    -- self.nvgBuffer = gfx.RenderTarget(uiwidth, uiheight):makeRGB8()
    -- self.nvgTexture = self.nvgBuffer.attachments[1]
    self.pipeline = gfx.Pipeline()

    -- set up nvg pass
    -- local nvgpass = gfx.NanoVGStage({
    --     renderTarget = self.nvgBuffer,
    --     clear = {color = 0x300000ff},
    --     draw = uiDrawStuff
    -- })
    -- nvgpass.extraNvgSetup = function(stage)
    --     stage.nvgfont = nanovg.nvgCreateFont(stage.nvgContext, "sans", "font/VeraMono.ttf")
    -- end
    -- self.pipeline:add("uipass", nvgpass)

    -- set up individual eye passes by creating one forward pass and then
    -- duplicating it twice
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
        local eyePass = forwardpass:duplicate(self.targets[i])
        self.pipeline:add("forward_" .. i, eyePass, self.eyeContexts[i])
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

    skytex = require("utils/textureutils.t").loadTexture("textures/starmap.ktx")
    local skymat = require("shaders/flat.t").FlatMaterial({diffuseMap = skytex, skybox=true})
    local skybox = gfx.Object3D(geo, skymat)
    skybox.scale:set(-60, -60, -60)
    skybox:updateMatrix()
    app.scene:add(skybox)

    local earthtex = require("utils/textureutils.t").loadTexture("textures/earth.ktx")
    local earthmat = require("shaders/flat.t").FlatMaterial({diffuseMap = earthtex})
    local theearth = gfx.Object3D(geo, earthmat)
    theearth.scale:set(0.5,0.5,0.5)
    theearth.position:set(0,1,0)
    theearth:updateMatrix()
    app.scene:add(theearth)

    local nspheres = 20
    for i = 1,nspheres do
        local sphere = gfx.Object3D(geo, mat)
        sphere.position:set(randu(5), randu(5), i*3)
        sphere:updateMatrix()
        app.scene:add(sphere)
    end

    log.info("Created axis stuff")
    axisGeo = require("geometry/widgets.t").axisWidgetGeo("axis_widget_geo", 0.1)
    axisMat = pbr.PBRMaterial("solid"):roughness(0.8):diffuse(0.2,0.2,0.2)

    app.scene:add(gfx.Object3D(axisGeo, axisMat))
end

function init()
    app = SatelliteApp({title = "satellites",
                         width = 1280,
                         height = 720})
    createGeometry()
end

function update()
    app:update()
end
