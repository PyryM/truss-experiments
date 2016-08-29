-- radialgrid.t
--
-- creates a radial floor grid thing

-- we'll go ahead and reuse the orbitline shader
local orbitline = require("orbitline.t")

local m = {}

function m.createSector(theta0, theta1, rad0, rad1, margin, npts)
    rad0 = rad0 + margin
    rad1 = rad1 - margin
    local thetaMargin0 = math.atan2(margin, rad0)
    local thetaMargin1 = math.atan2(margin, rad1)

    local pts = {}
    -- create bottom arc
    local dtheta = (theta1 - theta0 - 2*thetaMargin0) / (npts-1)
    for i = 1,npts do
        local theta = (i-1)*dtheta + theta0 + thetaMargin0
        local curpt = {rad0*math.cos(theta), 0, rad0*math.sin(theta)}
        table.insert(pts, curpt)
    end

    -- duplicate last point to avoid artifacts from the cursp
    table.insert(pts, pts[#pts])

    -- create top arc (note we go 'backwards' so the shape closes properly)
    local dtheta = (theta1 - theta0 - 2*thetaMargin1) / (npts-1)
    for i = 1,npts do
        local theta = theta1 - thetaMargin1 - (i-1)*dtheta
        local curpt = {rad1*math.cos(theta), 0, rad1*math.sin(theta)}
        table.insert(pts, curpt)
        if i == 1 then table.insert(pts, pts[#pts]) end
    end

    -- create other edge
    table.insert(pts, pts[#pts])
    table.insert(pts, pts[1])

    return pts
end

function m.createGrid(options)
    options = options or {}
    local minrad = options.minrad or 0.5
    local maxrad = options.maxrad or 5.0
    local raddivs = options.raddivs or 10
    local drad = (maxrad - minrad) / raddivs
    local margin = options.margin or 0.05
    local nsectors = options.sectors or 12
    local dtheta = math.pi * 2.0 / nsectors
    local npts = options.npts or 5
    local color = options.color or {255,255,255,255}

    local maxpoints = raddivs*nsectors*(npts*2 + 4)
    local grid = orbitline.ColorLineObject(maxpoints, false)
    grid:clear()

    for radidx = 1,raddivs do
        for thetaidx = 1,nsectors do
            local theta0 = (thetaidx-1)*dtheta
            local theta1 = theta0 + dtheta
            local rad0 = (radidx-1)*drad + minrad
            local rad1 = rad0 + drad
            local pts = m.createSector(theta0, theta1, rad0, rad1, margin, npts)
            log.info("Adding " .. #pts .. " points")
            grid:addCurveSegment(pts, {color})
        end
    end

    grid:build()
    return grid
end

return m
