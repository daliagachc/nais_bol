local M = {}

M.settings = {
    target_pos_charger_current = 25,
    target_neg_charger_current = -22,

    postfil_maxregul = 0.05,
    postfil_tgt = 1.0,

    feedback_end_delay = 200,
    pumps_startup_settling = 2000,
    charger_off_to_postfilter_off_delay = 2000,
    postfilter_on_to_charger_on_delay = 2500,
    feedback_start_delay = 1000,
    additional_settling = 4500,
    discharger_feedback_change_settling = 2000,

    pumps_off = false,

    target_sampleflow = 54,
    target_pos_sheathflow = 60,
    target_neg_sheathflow = 60,
    target_pos_sampleflow = 27,
    target_neg_sampleflow = 27,

    auto_postfilter = true,

    has_analyer_9 = false,
    has_internal_temperature = false
}

M.known_settings = {
    "required_opmode_parameters",
    "apply_opmode_bits",
    "known_opmode_parameters",
    "current_opmode",
    "name",
    "has_discharger_control",
    "default_settings",
    "known_settings",
    "opmodes",
    "board_version",

    "target_pos_charger_current",
    "target_neg_charger_current",
    "postfil_maxregul",
    "postfil_tgt",
    "feedback_end_delay",
    "pumps_startup_settling",
    "charger_off_to_postfilter_off_delay",
    "postfilter_on_to_charger_on_delay",
    "feedback_start_delay",
    "additional_settling",
    "discharger_feedback_change_settling",
    "pumps_off",
    "target_pos_sheathflow",
    "target_neg_sheathflow",
    "pos_sheathflow_to_sens",
    "sens_to_pos_sheathflow",
    "neg_sheathflow_to_sens",
    "sens_to_neg_sheathflow",
    "sens_to_temperature",
    "auto_postfilter",
    "single_sampleflow"
}

M.known_settings_single_sampleflow = {
    "target_sampleflow",
    "sampleflow_to_sens",
    "sens_to_sampleflow",
}

M.known_settings_double_sampleflow = {
    "target_pos_sampleflow",
    "target_neg_sampleflow",
    "pos_sampleflow_to_sens",
    "neg_sampleflow_to_sens",
    "sens_to_pos_sampleflow",
    "sens_to_neg_sampleflow"
}

M.known_opmode_parameters = {
    "pumps_on",
    "bgfilter_on",
    "discharger_on",
    "prefilter_on",
    "charger_on",
    "charger_modulator_on",
    "postfilter_on",
    "pos_discharger_current",
    "neg_discharger_current",
    "led0", "led1", "led2"
}

M.required_opmode_parameters = {
    "pumps_on",
    "bgfilter_on",
    "discharger_on",
    "prefilter_on",
    "charger_on",
    "charger_modulator_on",
    "postfilter_on",
}

M.opmodes = {
    particles = {
        pumps_on = true,
        bgfilter_on = false,
        discharger_on = false,
        prefilter_on = false,
        charger_on = true,
        charger_modulator_on = true,
        postfilter_on = true,
        led2 = true},
    alterch = {
        pumps_on = true,
        bgfilter_on = false,
        discharger_on = true,
        prefilter_on = false,
        charger_on = true,
        charger_modulator_on = true,
        postfilter_on = true,
        pos_discharger_current = -20/30,
        neg_discharger_current = 20/30
        },
    chargerbg = {
        pumps_on = true,
        bgfilter_on = true,
        discharger_on = false,
        prefilter_on = false,
        charger_on = true,
        charger_modulator_on = true,
        postfilter_on = true },
    offset = {
        pumps_on = true,
        bgfilter_on = false,
        discharger_on = true,
        prefilter_on = true,
        charger_on = false,
        charger_modulator_on = false,
        postfilter_on = false,
        led0 = true,
        pos_discharger_current = -20/30,
        neg_discharger_current = 20/30
        },
    ions = {
        pumps_on = true,
        bgfilter_on = false,
        discharger_on = false,
        prefilter_on = false,
        charger_on = false,
        charger_modulator_on = false,
        postfilter_on = false,
        led1 = true},
    ionbcg = {
        pumps_on = true,
        bgfilter_on = true,
        discharger_on = false,
        prefilter_on = false,
        charger_on = false,
        charger_modulator_on = false,
        postfilter_on = false },
    shutdown = {
        pumps_on = false,
        bgfilter_on = false,
        discharger_on = false,
        prefilter_on = false,
        charger_on = false,
        charger_modulator_on = false,
        postfilter_on = false },
    }

return M
