local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local Shop = require(script.Parent.Shop)

Controls.start()
Hud.start(Controls)
Shop.start()
