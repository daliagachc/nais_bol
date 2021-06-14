
local checks = require("lib/checks.lua")
local postfilter = require("lib/postfilter_update.lua")

local postfilter_options = {
    auto_postfilter = true,
    postfil_maxregul = 0.05,
    postfil_pos_tgt = 0.5,
    postfil_neg_tgt = 0.5,
    pos_default = 0.26,
    neg_default = 0.20
}

local has_diluter = false

local update_postfilter = postfilter.postfilter_updater(postfilter_options)

local function isnan(x)
    return not (x == x)
end

function on_record(record, vars)
    --spectops.log("prelim record " .. record.variant)

    c = checks.Checker(record, vars)

    -- Flows

    c:exists('pos_sampleflow.mean')
    c:exists('neg_sampleflow.mean')
    c:exists('pos_sheathflow.mean')
    c:exists('neg_sheathflow.mean')

    c:stddev("pos_sampleflow", 1.2)
    c:stddev("neg_sampleflow", 1.2)
    c:stddev("pos_sheathflow", 0.7)
    c:stddev("neg_sheathflow", 0.7)

    c:feedback("pos_sampleflow")
    c:feedback("neg_sampleflow")
    c:feedback("pos_sheathflow")
    c:feedback("neg_sheathflow")

    c:low_stddev("pos_sampleflow_vin")
    c:low_stddev("neg_sampleflow_vin")
    c:low_stddev("pos_sheathflow_vin")
    c:low_stddev("neg_sheathflow_vin")

    -- Env sensors

    c:stddev("baro", 1.5)

    if isnan(vars['baro.mean']) then
        record:add_flag(("{type: failure, message: '%s value is missing, air flow rates may be wrong', vars: ['baro.mean']}"):format(spectops.var_names['baro.mean']))
    end

    c:low_stddev("baro")

    c:exists('relhum')
    c:exists('temperature')

    c:exists('baro_internal')
    c:exists('relhum_internal')
    c:exists('temperature_internal')

    -- Dischargers

    c:exists("pos_discharger_current")
    c:exists("neg_discharger_current")

    c:stddev("pos_discharger_current", 5)
    c:stddev("neg_discharger_current", 5)

    if (record.opmode == "offset") or (record.opmode == "alterch") then
        c:feedback("pos_discharger_current")
        c:feedback("neg_discharger_current")
    else
        c:limits("pos_discharger_current", 0, 0.4, nil, "when switched off")
        c:limits("neg_discharger_current", 0, 0.4, nil, "when switched off")
    end

    -- Prefilters

    c:exists("pos_prefilter_voltage")
    c:exists("neg_prefilter_voltage")

    if record.opmode == "offset" then
        c:limits("pos_prefilter_voltage", 500,  50, nil, "during offset")
        c:limits("neg_prefilter_voltage", -500, 50, nil, "during offset")
    else
        c:limits("pos_prefilter_voltage", 0, 15, nil, "when switched off")
        c:limits("neg_prefilter_voltage", 0, 15, nil, "when switched off")
    end

    -- Main chargers

    c:exists("pos_charger_current")
    c:exists("neg_charger_current")

    c:stddev("pos_charger_current", 5)
    c:stddev("neg_charger_current", 5)

    if (record.opmode == "offset") or (record.opmode == "ions") then
        c:limits("pos_charger_current", 0, 0.65, nil, "when switched off")
        c:limits("neg_charger_current", 0, 0.65, nil, "when switched off")
    else
        c:feedback("pos_charger_current")
        c:feedback("neg_charger_current")
    end

    -- Postfilters

    if (record.opmode == "particles") or (record.opmode == "alterch") then
        if vars["pos_postfilter_voltage.mean"] > 200 then
            record:add_flag("{type: warning, message: '+ postfilter voltage may be too high', vars: ['pos_postfilter_voltage.mean']}")
        elseif vars["pos_postfilter_voltage.mean"] < 10 then
            record:add_flag("{type: warning, message: '+ postfilter voltage may be too low', vars: ['pos_postfilter_voltage.mean']}")
        end
        if vars["neg_postfilter_voltage.mean"] < -200 then
            record:add_flag("{type: warning, message: '− postfilter voltage may be too high negative', vars: ['neg_postfilter_voltage.mean']}")
        elseif vars["neg_postfilter_voltage.mean"] > -10 then
            record:add_flag("{type: warning, message: '− postfilter voltage may be too low negative', vars: ['neg_postfilter_voltage.mean']}")
        end
    else
        c:limits("pos_postfilter_voltage", 0, 4, 2, "when switched off")
        c:limits("neg_postfilter_voltage", 0, 4, 2, "when switched off")
    end

    -- Analyzers

    c:exists("pos_analyzer_1")
    c:exists("neg_analyzer_1")
    c:exists("pos_analyzer_2")
    c:exists("neg_analyzer_2")
    c:exists("pos_analyzer_3")
    c:exists("neg_analyzer_3")
    c:exists("pos_analyzer_4")
    c:exists("neg_analyzer_4")

    c:limits("pos_analyzer_1",    9, 0.5,   2)
    c:limits("neg_analyzer_1",   -9, 0.5,   2)
    c:limits("pos_analyzer_2",   35, 1.5,   2)
    c:limits("neg_analyzer_2",  -35, 1.5,   2)
    c:limits("pos_analyzer_3",  150,   6,   6)
    c:limits("neg_analyzer_3", -150,   6,   6)
    c:limits("pos_analyzer_4",  700,  20,  10)
    c:limits("neg_analyzer_4", -700,  20,  10)

    if not isnan(vars["temperature_internal.mean"]) and not isnan(vars["temperature.mean"])
        and (vars["temperature_internal.mean"] - vars["temperature.mean"] < -2  ) then
        record:add_flag("{type: failure, message: 'Water condensation danger! Instrument temperature is lower than sample air', vars: ['temperature_internal.mean', 'temperature.mean']}")
    end

    if not ((vars["diluter_flow.tgt.mean"] == nil) or isnan(vars["diluter_flow.tgt.mean"])) then
        if isnan(vars["diluter_flow.mean"]) then
            record:add_flag("{type: warning, message: 'Diluter flow requested but device not present', vars: ['diluter_flow.mean']}")
        else
            if vars["diluter_flow.vout.mean"] > 3.9 then
                record:add_flag("{type: warning, message: 'Diluter flow may be too low', vars: ['diluter_flow.mean', 'diluter_flow.tgt.mean']}")
            elseif vars["diluter_flow.vout.mean"] < 0.1 then
                record:add_flag("{type: warning, message: 'Diluter flow may be too high', vars: ['diluter_flow.mean', 'diluter_flow.tgt.mean']}")
            end
        end
    end

end

function on_final_record(record, vars)
    --spectops.log(string.format('Final %s %s', record.variant, record.opmode))

    var_limit = 3.0/math.sqrt(record.duration)

    for i = 0, spectops.num_elm - 1 do
        local cur, var, raw = record:elm(i)
        if var > var_limit then
            record:add_flag(("{type: note, message: 'Elm. %s is noisy', elms: [%d]}"):format(
                spectops.elm_names[i], i))
        end
    end

    if record.variant == 'block' then
        update_postfilter(record, vars)
    end
end

spectops.on_record = on_record
spectops.on_final_record = on_final_record
