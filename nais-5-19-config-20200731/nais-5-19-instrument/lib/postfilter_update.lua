local util = require("util.lua")

M = {}

function M.postfilter_updater(settings)

    function change_postfilter(name, vars, x)
        local oldv = spectops.get_var(name .. '_postfilter_voltage_vout')

        local v = oldv

        if util.isnan(v) or (v == nil) then
            v = settings[name .. '_default']
        end

        v = v*math.exp(x*3.0)--+ x --*math.exp(x)

        if v > 5.0 then
            v = 5.0
        elseif v < 0.01 then
            v = 0.01
        end

        spectops.set_var(name .. '_postfilter_voltage_vout', v)
    end

    function update_postfilter(rec, vars)
        if (rec.opmode == "particles") and settings.auto_postfilter then
            local currents = rec.current

            local possum = currents[3] + currents[4]
            local set_pos_postf

            if util.isnan(possum) then
                set_pos_postf = settings.postfil_maxregul
            else
                set_pos_postf = (possum - settings.postfil_pos_tgt)*0.01

                if set_pos_postf > settings.postfil_maxregul/4 then
                    if possum > 2 or (util.nanval(currents[1] + currents[2], 0)/2) < (possum/3) then
                        set_pos_postf = settings.postfil_maxregul
                    else
                        set_pos_postf = -settings.postfil_maxregul/2
                    end
                elseif set_pos_postf < -settings.postfil_maxregul then
                    set_pos_postf = -settings.postfil_maxregul
                end

                if (currents[3]+currents[4])>2 then
                    set_pos_postf = settings.postfil_maxregul/4
                elseif ((currents[1]+currents[2])/2*1.5>(currents[3]+currents[4])/2
                        or ((currents[1]+currents[2]/2)< -settings.postfil_pos_tgt*1.5)
                        or (currents[3]< -settings.postfil_pos_tgt/1)
                        or (currents[4]< -settings.postfil_pos_tgt/2)) then
                    set_pos_postf = -settings.postfil_maxregul/8
                elseif (currents[5]+currents[6])>((currents[3]+ currents[4])*1.5) and (currents[3]+ currents[4])>settings.postfil_pos_tgt then
                    set_pos_postf = settings.postfil_maxregul/4
                end
            end

            if vars['pos_postfilter_voltage.mean'] > 300 then
                spectops.log('error', 'Positive postfilter voltage is too high. Resetting to default value')
                spectops.set_var('pos_postfilter_voltage_vout', settings['pos_default'])
            elseif not util.isnan(set_pos_postf) then
                change_postfilter("pos", vars, set_pos_postf)
            end

            local negbase = 21 + 4
            local negsum = currents[negbase + 2] + currents[negbase + 3]
            local set_neg_postf

            if util.isnan(negsum) then
                set_neg_postf = settings.postfil_maxregul
            else
                set_neg_postf = (negsum - settings.postfil_neg_tgt)*0.01
                if set_neg_postf > settings.postfil_maxregul/4 then
                    if negsum > 2 or util.nanval(currents[negbase + 1], 0) < (negsum/3) then
                        set_neg_postf = settings.postfil_maxregul
                    else
                        set_neg_postf = -settings.postfil_maxregul/2
                    end
                elseif set_neg_postf < -settings.postfil_maxregul then
                    set_neg_postf = -settings.postfil_maxregul
                end
                if (currents[negbase + 2]+currents[negbase + 3])>2 then
                    set_neg_postf = settings.postfil_maxregul/4
                elseif (currents[negbase + 1]*1.0>(currents[negbase + 2]+currents[negbase + 3])/2
                    or currents[negbase + 1] < -settings.postfil_neg_tgt/1
                    or currents[negbase + 2] < settings.postfil_neg_tgt/1
                    or currents[negbase + 3] < settings.postfil_neg_tgt/2) then
                    if currents[negbase + 1]<0 then
                        set_neg_postf = -settings.postfil_maxregul/4
                    else
                        set_neg_postf = -settings.postfil_maxregul/8
                    end
                elseif (currents[negbase + 4]+currents[negbase + 5])>((currents[negbase + 1]+ currents[negbase + 2]+currents[negbase + 3])*1.0)
                    and (currents[negbase + 2]+ currents[negbase + 3]) > settings.postfil_neg_tgt then
                    set_neg_postf = settings.postfil_maxregul/4
                end
            end

            if vars['neg_postfilter_voltage.mean'] < -300 then
                spectops.log('error', 'Negative postfilter voltage is too high. Resetting to default value')
                spectops.set_var('neg_postfilter_voltage_vout', settings['neg_default'])
            elseif not util.isnan(set_neg_postf) then
                change_postfilter("neg", vars, set_neg_postf)
            end

            spectops.log("debug", string.format("Adjusted postfilters. (Pos: sum=%.1f, tgt=%.2f, adj=%.3f; Neg: sum=%.1f, tgt=%.2f, adj=%.3f)",
                possum, settings.postfil_pos_tgt, set_pos_postf, negsum, settings.postfil_neg_tgt, set_neg_postf))
        end
    end

    return update_postfilter

end

return M
