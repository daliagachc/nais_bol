local M = {}

local function isnan(x)
    return not (x == x)
end

local Checker = {}
Checker.__index = Checker

M.Checker = Checker

setmetatable(Checker, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

function Checker.new(record, vars)
    local self = setmetatable({}, Checker)
    self.record = record
    self.vars = vars
    return self
end

function Checker:limits_exp(name, target, tolerance, stddev)
    local value = self.vars[name .. ".mean"]
    if value > target + tolerance then
        self.record:add_flag(("{type: warning, message: '%s is above %g, expected %g, vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"],
            target + tolerance,
            target,
            name .. ".mean"))
    elseif value < target - tolerance then
        self.record:add_flag(("{type: warning, message: '%s is below %g, expected %g', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"],
            target - tolerance,
            target,
            name .. ".mean"))
    end

    if (stddev ~= nil) and (self.vars[name .. ".stddev"] > stddev) then
        self.record:add_flag(("{type: warning, message: '%s is fluctuating', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"], name .. ".stddev"))
    end
end

local function too_high(target)
    if target < 0 then
        return "too low negative"
    else
        return "too high"
    end
end

local function too_low(target)
    if target > 0 then
        return "too low"
    else
        return "too high negative"
    end
end

function Checker:limits(name, target, tolerance, stddev, when)
    local value = self.vars[name .. ".mean"]

    if when == nil then
        when = ""
    else
        when = " " .. when
    end

    if value > target + tolerance then
        self.record:add_flag(("{type: warning, message: '%s is %s%s', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"],
            too_high(target),
            when,
            name .. ".mean"))
    elseif value < target - tolerance then
        self.record:add_flag(("{type: warning, message: '%s is %s%s', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"],
            too_low(target),
            when,
            name .. ".mean"))
    end

    if (stddev ~= nil) and (self.vars[name .. ".stddev"] > stddev) then
        self.record:add_flag(("{type: warning, message: '%s is fluctuating%s', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"],
            when,
            name .. ".stddev"))
    end
end

function Checker:feedback(name)
    mean = self.vars[name .. "_vout.mean"]
    stddev = self.vars[name .. "_vout.stddev"]
    ctrl_low = mean - 2*stddev
    ctrl_high = mean + 2*stddev
    if ctrl_low < 0.1 then
        self.record:add_flag(("{type: warning, message: '%s control signal is near minimum', vars: ['%s', '%s']}"):format(
            spectops.var_names[name .. ".mean"], name .. ".mean", name .. "_vout.mean"))
    end
    if ctrl_high > 4.9 then
        self.record:add_flag(("{type: warning, message: '%s control signal is near maximum', vars: ['%s', '%s']}"):format(
            spectops.var_names[name .. ".mean"], name .. ".mean", name .. "_vout.mean"))
    end
    if isnan(mean) then
        self.record:add_flag(("{type: warning, message: '%s control signal is unknown', vars: ['%s', '%s']}"):format(
            spectops.var_names[name .. ".mean"], name .. ".mean", name .. "_vout.mean"))
    end
end

function Checker:stddev(name, stddev)
    if self.vars[name .. ".stddev"] > stddev then
        self.record:add_flag(("{type: warning, message: '%s is fluctuating', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"], name .. ".stddev"))
    end
end

function Checker:low_stddev(name, stddev)
    if self.vars[name .. ".stddev"] == 0.0 then
        self.record:add_flag(("{type: warning, message: '%s is constant, possible sensor problem', vars: ['%s']}"):format(
            spectops.var_names[name .. ".mean"], name .. ".stddev"))
    end
end

function Checker:exists(name)
    if isnan(self.vars[name]) then
        self.record:add_flag(("{type: warning, message: '%s value is missing', vars: ['%s']}"):format(spectops.var_names[name], name))
    end
end


return M
