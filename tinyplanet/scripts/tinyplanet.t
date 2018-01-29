-- tinyplanet.t
--
-- a tiny vr planet you can walk around on

local app = require("app/app.t")
local geometry = require("geometry")
local pbr = require("shaders/pbr.t")
local graphics = require("graphics")
local orbitcam = require("gui/orbitcam.t")
local grid = require("graphics/grid.t")
local config = require("utils/config.t")
local objloader = require("loaders/objloader.t")
local gfx = require("gfx")
local ecs = require("ecs")
local math = require("math")

local models = {}
local function load_base_models()
  local filenames = {
    trunk = "trunk.obj",
    bend = "bend.obj",
    leaf_cap = "hemisphere.obj",
    leaf_body = "offsetcylinder.obj"
  }
  for modelname, modelfn in pairs(filenames) do
    local data = objloader.load_obj("models/" .. modelfn)
    models[modelname] = gfx.StaticGeometry(modelname):from_data(data)
  end
end

local function create_leaf_section(root, n_sections)
  local bottom_cap = root:create_child(graphics.Mesh, "bc", models.leaf_cap)
  bottom_cap.quaternion:euler{x = math.pi, y = 0, z = 0}
  bottom_cap:update_matrix()
  local top_cap = root:create_child(graphics.Mesh, "tc", models.leaf_cap)
  top_cap.position:set(0.0, n_sections * 2, 0.0)
  top_cap:update_matrix()
  for i = 0, (n_sections - 1) do
    local body = root:create_child(graphics.Mesh, "b", models.leaf_body)
    body.position:set(0.0, i * 2 + 1, 0.0)
    body:update_matrix()
  end
end

local function create_branch(root, n_sections)
  local bend = root:create_child(graphics.Mesh, "b", models.bend)
  local offset = bend:create_child(ecs.Entity3d, "o")
  offset.position:set(-2.0, 1.7, 0.0)
  offset.scale:set(0.8, 0.8, 0.8)
  offset:update_matrix()
  create_leaf_section(offset, n_sections)
end

local function random_tree(root)
  local trunk = root:create_child(graphics.Mesh, "t", models.trunk)
  local h = math.random(3, 6)
  trunk.scale:set(0.3, h/2, 0.3)
  trunk:update_matrix()
  local rootleaf = root:create_child(ecs.Entity3d, "rl")
  rootleaf.position:set(0.0, h, 0.0)
  rootleaf:update_matrix()
  create_leaf_section(rootleaf, math.random(0, 3))
  for i = 0, 5 do
    if math.random() < 0.5 then
      local branch = root:create_child(ecs.Entity3d, "b")
      branch.position:set(0.0, math.random(1,h-1), 0.0)
      branch.quaternion:euler{x = 0, y = i * math.pi/3.0, z = 0}
      branch:update_matrix()
      create_branch(branch, math.random(0, 3))
    end
  end
end

local function urand()
  return math.random() * 2.0 - 1.0
end

-- given a frame (4x4 matrix) where y=up, -z=forward,
-- and a new up vector, modify the frame to use the new up vector
local temp_x, temp_y, temp_z = math.Vector(), math.Vector(), math.Vector()
local function update_frame_up_vector(frame, new_up)
  -- project z into the plane of the new up, and then normalize
  frame:get_column(3, temp_z)
  local normal_part = new_up:dot(temp_z)
  temp_z:lincomb(temp_z, new_up, 1.0, -normal_part) -- z <- z - (z dot y) y
  temp_z:normalize3()

  -- x = y cross z
  temp_x:cross(new_up, temp_z)
  frame:from_basis{temp_x, new_up, temp_z}
end

local function frame_on_sphere(point, target)
  temp_y:copy(point):normalize3()
  temp_x:set(urand(), urand(), urand()):normalize3()
  temp_z:cross(temp_x, temp_y):normalize3()
  temp_x:cross(temp_y, temp_z)
  point.elem.w = 1.0
  target = target or math.Matrix4()
  return target:from_basis{temp_x, temp_y, temp_z, point}
end

local function rand_point_in_sphere(target)
  local ret = target or math.Vector()
  while true do
    ret:set(urand(), urand(), urand())
    if ret:length3() <= 1.0 then
      return ret
    end
  end
end

function merge_trees(n_trees, world_radius)
  local builder = geometry.util.Builder()
  for _ = 1, n_trees do
    local treeroot = builder.root:create_child(ecs.Entity3d, "tree")
    local treepos = rand_point_in_sphere():normalize3():multiply(world_radius)
    frame_on_sphere(treepos, treeroot.matrix)
    random_tree(treeroot)
  end
  local ret = builder:build()
  log.debug("Merged together into " .. ret.n_verts .. " vertices and " 
            .. ret.n_indices .. " indices.")
  return ret
end

function init()
  local cfg = config.Config{
      orgname = "truss_experiments", 
      appname = "tiny_planet", 
      use_global_save_dir = false,
      defaults = {
        width = 1280, height = 720, msaa = true, stats = true
      }
    }:load()
  cfg.title = "tiny planet experiment"  -- settings added after creation aren't saved
  cfg.clear_color = 0x000000ff 
  cfg:save()

  myapp = app.App(cfg)
  myapp.camera:add_component(orbitcam.OrbitControl{min_rad = 1, max_rad = 4})

  local world_radius = 5.0
  local planetgeo = geometry.icosphere_geo{radius = world_radius, detail = 4}
  local mat = pbr.FacetedPBRMaterial{diffuse = {0.5, 0.5, 0.5, 1.0}, 
                                     tint = {0.001, 0.001, 0.001}, 
                                     roughness = 0.6
                                    }
  local planetmat = pbr.FacetedPBRMaterial{diffuse = {0.2, 0.2, 0.2, 1.0}, 
                                     tint = {0.001, 0.001, 0.001}, 
                                     roughness = 0.6
                                    }


  local planet = myapp.scene:create_child(graphics.Mesh, "planet", 
                                          planetgeo, planetmat)
  planet.scale:set(0.5, 0.5, 0.5)
  planet:update_matrix()

  load_base_models()
  local trees = merge_trees(5, world_radius)
  treemesh = myapp.scene:create_child(graphics.Mesh, "treemesh", trees, mat)
  treemesh.scale:set(0.5, 0.5, 0.5)
  treemesh:update_matrix()

  --create_leaf_section(myapp.scene, 4, 1.0, mat)
  mygrid = myapp.scene:create_child(grid.Grid, {thickness = 0.03,
                                                numlines = 0, numcircles = 30,
                                                spacing = 2.0,
                                                color = {0.9, 0.1, 0.1, 1.0}})
  mygrid.position:set(0.0, -0.5, 0.0)
  mygrid.quaternion:euler({x = math.pi / 2.0, y = 0.0, z = 0.0})
  mygrid:update_matrix()
end

function update()
  myapp:update()
end
