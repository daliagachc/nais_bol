local util = require("util.lua")
local bit = util.bit
local isnan = util.isnan
local copy_table = util.copy_table
local defaults = require("nais_defaults.lua")
local instm = require("instrument.lua")

local M = {}

local Nais = instm.Instrument:new()

function Nais:sens_to_temperature(x)
    return x/0.01 - 273.15
end

local charger_current_voltage_coef = 30

function Nais:update_targets()
    if self.current_opmode.charger_on then
        spectops.set_persistent("tgt_pos_charger_current", self.target_pos_charger_current/charger_current_voltage_coef)
        spectops.set_persistent("tgt_neg_charger_current", self.target_neg_charger_current/charger_current_voltage_coef)
    end

    if self.has_discharger_control and self.current_opmode.discharger_on then
        spectops.set_persistent("tgt_neg_discharger_current",
            self.opmodes[self.current_opmode_name].neg_discharger_current/charger_current_voltage_coef)
        spectops.set_persistent("tgt_pos_discharger_current",
            self.opmodes[self.current_opmode_name].pos_discharger_current/charger_current_voltage_coef)
    end
end

local function apply_opmode_bits_boardv1(self, opmode)
    spectops.set_digout("000" ..
            bit[opmode.prefilter_on] ..
            (opmode.discharger_coice or "0") ..
            bit[not opmode.discharger_on] ..
            (opmode.charger_choice or "0") ..
            bit[not opmode.charger_on] ..
            "000" ..
            bit[opmode.bgfilter_on] ..
            bit[opmode.pumps_on and not self.pumps_off] ..
            "00" ..
            bit[opmode.postfilter_on])
end

local function apply_opmode_bits_boardv2(self, opmode)
    spectops.set_digout(bit[opmode.led0 or false] .. --7
            bit[opmode.led1 or false] .. --6
            bit[opmode.pumps_on and not self.pumps_off] .. --5
            "0" .. --4
            bit[opmode.cleanairfilter_on or false] .. --3
            bit[opmode.postfilter_on] .. --2
            bit[opmode.bgfilter_on] .. --1
            "0" .. --0
            bit[opmode.led2 or false] .. --15
            bit[opmode.led3 or false] .. --14
            bit[not opmode.discharger_on] .. --13
            bit[not opmode.prefilter_on] .. --12
            bit[not opmode.charger_on] .. --11
            (opmode.discharger_coice or "0") .. --10
            bit[not opmode.charger_modulator_on] .. --9
            (opmode.charger_choice or "0") --8
    )
end

function Nais:set_charger_feedback(ctrlon)
    if ctrlon then
        --log("charger control on")
        spectops.set_persistent("tgt_pos_charger_current", self.target_pos_charger_current/charger_current_voltage_coef)
        spectops.set_persistent("tgt_neg_charger_current", self.target_neg_charger_current/charger_current_voltage_coef)
    else
--         log("charger control off")
        spectops.set_persistent("tgt_pos_charger_current", nil)
        spectops.set_persistent("tgt_neg_charger_current", nil)
    end
end

function Nais:set_discharger_feedback(opmode_def)
    if opmode_def.discharger_on then
--         log("discharger control on")
        spectops.set_persistent("tgt_neg_discharger_current", opmode_def.neg_discharger_current/charger_current_voltage_coef)
        spectops.set_persistent("tgt_pos_discharger_current", opmode_def.pos_discharger_current/charger_current_voltage_coef)
    else
--         log("discharger control off")
        spectops.set_persistent("tgt_neg_discharger_current", nil)
        spectops.set_persistent("tgt_pos_discharger_current", nil)
    end
end

function Nais:init_opmode(target_opmode_name, target_opmode)
    local current_opmode = self.current_opmode
    local old_opmode = copy_table(current_opmode)

    local new_opmode = copy_table(target_opmode)

    new_opmode.discharger_on = current_opmode.discharger_on and target_opmode.discharger_on
    new_opmode.charger_on = current_opmode.charger_on and target_opmode.charger_on
    new_opmode.charger_modulator_on = current_opmode.charger_modulator_on and target_opmode.charger_modulator_on
    new_opmode.postfilter_on = current_opmode.postfilter_on or target_opmode.postfilter_on
    new_opmode.prefilter_on = current_opmode.prefilter_on or target_opmode.prefilter_on

    local any_feedback_ends = false
    local delay = 0

    if self.has_discharger_control and current_opmode.discharger_on then
        self:set_discharger_feedback(target_opmode)
        if target_opmode.discharger_on then
            if (target_opmode.pos_discharger_current ~= current_opmode.pos_discharger_current) or
               (target_opmode.neg_discharger_current ~= current_opmode.neg_discharger_current) then
                    delay = math.max(delay, self.discharger_feedback_change_settling)
            end
        else
            any_feedback_ends = true
        end
    end

    if not target_opmode.charger_on then
        self:set_charger_feedback(false)
        if current_opmode.charger_on then
            any_feedback_ends = true
        end
    end

    if any_feedback_ends then
        spectops.wait(self.feedback_end_delay)
    end

    if (not current_opmode.pumps_on and new_opmode.pumps_on) then
        delay = math.max(delay, self.pumps_startup_settling)
    elseif (not current_opmode.charger_on and target_opmode.charger_on) then
        delay = math.max(delay, self.postfilter_on_to_charger_on_delay)
    elseif (current_opmode.charger_on and not target_opmode.charger_on) then
        delay = math.max(delay, self.charger_off_to_postfilter_off_delay)
    end

    self:apply_opmode_bits(new_opmode)
    current_opmode = copy_table(new_opmode)
    spectops.wait(delay)

    if current_opmode ~= target_opmode then
        self:apply_opmode_bits(target_opmode)
        current_opmode = copy_table(target_opmode)
    end

    spectops.wait(self.feedback_start_delay)

    if current_opmode.charger_on and not old_opmode.charger_on then
        self:set_charger_feedback(true)
    end

    if self.has_discharger_control and current_opmode.discharger_on and not old_opmode.discharger_on then
        self:set_discharger_feedback(current_opmode)
    end

    spectops.wait(math.max(0, self.additional_settling - self.feedback_start_delay))

    self.current_opmode = current_opmode
end

function Nais:set_flow_targets(d)
    relbaro = d.baro/1000.0
    if self.single_sampleflow then
        d.tgt_sampleflow = self:sampleflow_to_sens(self.target_sampleflow, d.baro)
    else
        d.tgt_pos_sampleflow = self:pos_sampleflow_to_sens(self.target_pos_sampleflow, d.baro)
        d.tgt_neg_sampleflow = self:neg_sampleflow_to_sens(self.target_neg_sampleflow, d.baro)
    end
    d.tgt_neg_sheathflow = self:neg_sheathflow_to_sens(self.target_neg_sheathflow/relbaro, d.baro)
    d.tgt_pos_sheathflow = self:pos_sheathflow_to_sens(self.target_pos_sheathflow/relbaro, d.baro)
end

function Nais:shutdown_pumps()
    nais.pumps_off = true
    if nais.single_sampleflow then
        spectops.set_pid_parameters("ctrl_sampleflow", 0, 0, 0, 0)
    else
        spectops.set_pid_parameters("ctrl_pos_sampleflow", 0, 0, 0, 0)
        spectops.set_pid_parameters("ctrl_neg_sampleflow", 0, 0, 0, 0)
    end
    spectops.set_pid_parameters("ctrl_pos_sheathflow", 0, 0, 0, 0)
    spectops.set_pid_parameters("ctrl_neg_sheathflow", 0, 0, 0, 0)
end

function Nais:setup_known_settings()
    self.known_settings = {}
    for i, s in ipairs(defaults.known_settings) do
        table.insert(self.known_settings, s)
    end

    if self.single_sampleflow then
        for i, s in ipairs(defaults.known_settings_single_sampleflow) do
            table.insert(self.known_settings, s)
        end
    else
        for i, s in ipairs(defaults.known_settings_double_sampleflow) do
            table.insert(self.known_settings, s)
        end
    end
    self.known_opmode_parameters = defaults.known_opmode_parameters
    self.required_opmode_parameters = defaults.required_opmode_parameters
    self.default_settings = defaults.settings
end

function Nais:sens_to_baro(sens)
    return ((sens/5.1) + 0.095)/0.0009
end


local function update_persistent_dac(name, diff, default)
    v = spectops.get_persistent(name)
    if isnan(v) or (v == nil) then
        v = default
    end
    v = v + diff
    if v > 5.0 then
        v = 5.0
    elseif v < 0.0 then
        v = 0.0
    end
    spectops.set_persistent(name, v)
end

function M.init_nais_setup(options)
    local nais = Nais:new(options)

    spectops.on_opmode_change = function (old_opmode_name, new_opmode_name)
        if new_opmode_name ~= old_opmode_name then
            spectops.set_measurements_valid(false)

            spectops.set_lcd_message(nais.name .. " measuring " .. new_opmode_name)

            nais.current_opmode_name = new_opmode_name

            opmode_def = nais.opmodes[nais.current_opmode_name]
            if opmode_def == nil then
                log("Unknown opmode '" .. nais.current_opmode_name .. "'")
                nais.current_opmode_name = "shutdown"
                opmode_def = nais.opmodes[nais.current_opmode_name]
            end

            nais:init_opmode(opmode_name, opmode_def)
            if opmode_name ~= "shutdown" then
                spectops.set_measurements_valid(true)
            end
        end
    end

    spectops.on_raw_record = function (d)
        d.pos_prefilter_voltage = 1000*d.sens_pos_prefilter_voltage
        d.neg_prefilter_voltage = 1000*d.sens_neg_prefilter_voltage
        d.neg_discharger_current = 30*d.sens_neg_discharger_current
        d.pos_discharger_current = 30*d.sens_pos_discharger_current
        d.pos_charger_current = 30*d.sens_pos_charger_current
        d.neg_charger_current = 30*d.sens_neg_charger_current

        d.pos_analyzer_1 = 100*d.sens_pos_analyzer_1
        d.neg_analyzer_1 = 100*d.sens_neg_analyzer_1

        d.pos_analyzer_2 = 100*d.sens_pos_analyzer_2
        d.neg_analyzer_2 = 100*d.sens_neg_analyzer_2

        d.pos_analyzer_3 = 1000*d.sens_pos_analyzer_3
        d.neg_analyzer_3 = 1000*d.sens_neg_analyzer_3

        d.pos_analyzer_4 = 1000*d.sens_pos_analyzer_4
        d.neg_analyzer_4 = 1000*d.sens_neg_analyzer_4

        d.neg_sheathfilter_current = 1000*d.sens_neg_sheathfilter_current
        d.pos_sheathfilter_current = 1000*d.sens_pos_sheathfilter_current
        d.neg_postfilter_voltage = -200*d.sens_neg_postfilter_voltage
        d.pos_postfilter_voltage = 200*d.sens_pos_postfilter_voltage

        if d.sens_bgfilter_voltage then
            d.bgfilter_voltage = 200*d.sens_bgfilter_voltage
        end

        d.baro = nais:sens_to_baro(d.sens_baro)

        nais:set_flow_targets(d)

        if nais.single_sampleflow then
            d.sampleflow = nais:sens_to_sampleflow(d.sens_sampleflow, d.baro)
        else
            d.pos_sampleflow = nais:sens_to_pos_sampleflow(d.sens_pos_sampleflow, d.baro)
            d.neg_sampleflow = nais:sens_to_neg_sampleflow(d.sens_neg_sampleflow, d.baro)
        end

        d.neg_sheathflow = nais:sens_to_neg_sheathflow(d.sens_neg_sheathflow, d.baro)
        d.pos_sheathflow = nais:sens_to_pos_sheathflow(d.sens_pos_sheathflow, d.baro)

        d.relhum = (d.sens_relhum - 0.958)/0.0368
        d.temperature = nais:sens_to_temperature(d.sens_temperature)

        if nais.has_internal_temperature then
            d.internal_temperature = nais:sens_to_temperature(d.sens_internal_temperature)
        end
    end

    spectops.on_block_record = function (opmode, electrometers, currents)

        if (opmode == "particles") and nais.auto_postfilter then
            local possum = electrometers[3] + electrometers[4]
            local set_pos_postf

            if isnan(possum) then
                set_pos_postf = nais.postfil_maxregul
            else
                set_pos_postf = (possum - nais.postfil_tgt)*0.01
                if set_pos_postf > nais.postfil_maxregul/4 then
                    if possum > 2 or (nanval(electrometers[1] + electrometers[2], 0)/2) < (possum/3) then
                        set_pos_postf = nais.postfil_maxregul
                    else
                        set_pos_postf = -nais.postfil_maxregul/2
                    end
                elseif set_pos_postf < -nais.postfil_maxregul then
                    set_pos_postf = -nais.postfil_maxregul
                end
            end

            if not isnan(set_pos_postf) then
                update_persistent_dac("dac_pos_postfilter", set_pos_postf, 0.0)
            end

            local negsum = electrometers[23] + electrometers[24]
            local set_neg_postf

            if isnan(negsum) then
                set_neg_postf = nais.postfil_maxregul
            else
                set_neg_postf = (negsum - nais.postfil_tgt)*0.01
                if set_neg_postf > nais.postfil_maxregul/4 then
                    if negsum > 2 or nanval(electrometers[22], 0) < (negsum/3) then
                        set_neg_postf = nais.postfil_maxregul
                    else
                        set_neg_postf = -nais.postfil_maxregul/2
                    end
                elseif set_neg_postf < -nais.postfil_maxregul then
                    set_neg_postf = -nais.postfil_maxregul
                end
            end

            if not isnan(set_neg_postf) then
                update_persistent_dac("dac_neg_postfilter", set_neg_postf, 0.0)
            end

            log("info", string.format("Adjusted postfilter pos(sum=%g, adj=%g) neg(sum=%g, adj=%g)", possum, set_pos_postf, negsum, set_neg_postf))
        end
    end

    return nais
end

function Nais:new(options)
    nais = instm.Instrument.new(self, options)
    nais.current_opmode = {
        discharger_coice = "0",
        charger_choice = "0",

        bgfilter_on = false,
        discharger_on = false,
        prefilter_on = false,
        charger_on = false,
        postfilter_on = false,
        pumps_on = false,
    }

    if nais.board_version == 1 then
        nais.apply_opmode_bits = apply_opmode_bits_boardv1
    elseif nais.board_version == 2 then
        nais.apply_opmode_bits = apply_opmode_bits_boardv2
    end

    nais.opmodes = util.deep_copy_table(defaults.opmodes)

    return nais
end


return M
