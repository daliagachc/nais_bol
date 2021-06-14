local util = require("util.lua")

local M = {}

local Instrument = {}

M.Instrument = Instrument

function Instrument:new(o)
    o = o or {}   -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

function Instrument:set_flow_coef_calibration(channelname, coef)
    self[channelname .. "_to_sens"] = function (self, flow, baro)
        return coef*baro/1005*((flow/60)^2)
    end

    self["sens_to_" .. channelname] = function (self, sens, baro)
        return math.sqrt(sens/coef/(baro/1005))*60
    end
end

function Instrument:check_setup()
    local lines = {}

    if self.known_settings == nil then
        self:setup_known_settings()
    end

    table.insert(lines, "Checking instrument control scripts:")

    local setres = util.check_items(self, self.known_settings, self.known_settings)

    for i = 1, #setres.missing do
        table.insert(lines, ("- missing '%s'"):format(setres.missing[i]))
    end

    for i = 1, #setres.unknown do
        table.insert(lines, ("? unknown '%s'"):format(setres.unknown[i]))
    end

    for opmode, opmodeparams in pairs(self.opmodes) do
        local opres = util.check_items(opmodeparams, self.known_opmode_parameters, self.required_opmode_parameters)

        for i = 1, #opres.missing do
            table.insert(lines, ("- missing 'opmode.%s.%s'"):format(opmode, opres.missing[i]))
        end

        for i = 1, #opres.unknown do
            table.insert(lines, ("? unknown 'opmode.%s.%s'"):format(opmode, opres.unknown[i]))
        end
    end

    local nondef_count = 0

    for k, v in pairs(self) do
        local dv = self.default_settings[k]

        if dv == nil then
            --table.insert(lines, string.format("    '%s': no default -> %s", k, tostring(v)))
        elseif v ~= dv then
            nondef_count = nondef_count + 1

            table.insert(lines, ("! changed '%s' %s -> %s"):format(k, tostring(dv), tostring(v)))
        end
    end

    if #lines ~= 0 then
        spectops.log("info", table.concat(lines, "\n"))
    end
end

if false then --function M.enable_setup_debug()
    function Instrument.__index(table, key)
        local h
        local v
        if type(table) == "table" then
            v = rawget(table, key)
            if v ~= nil then return v end
            h = metatable(table).__index
            if h == nil then return nil end
        else
            h = metatable(table).__index
            if h == nil then
                log("error", "Something awful has happened!")
            end
        end
        if type(h) == "function" then
            v = (h(table, key))     -- call the handler
        else
            v = h[key]           -- or repeat operation on it
        end

        if v == nil then
            log("warning", string.format("A missing setting was requested: '%s'", key))
        end

        return v
    end
end

return M