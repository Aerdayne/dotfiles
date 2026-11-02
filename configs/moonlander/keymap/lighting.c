#include QMK_KEYBOARD_H

// Set to a new number by `moonlander --reset-lighting`
#ifndef LIGHTING_RESET
#    define LIGHTING_RESET 0
#endif

// The EEPROM word QMK leaves to user code holds this marker, how many effects the firmware had and the number
// of the last reset
#define LIGHTING_MARKER 0x57

// Runs once at startup. The saved effect is a position in the firmware's list of effects, so when that list
// changes (Oryx's LED Animations, or rgb_matrix_user.inc) it would point at another one: start on the default
// effect then. The first time, and when asked to, put all the lighting settings back to the defaults in
// config.h, with layer colours and the lights on.
void housekeeping_task_user(void) {
    static bool done = false;
    if (done) return;
    done = true;

    uint32_t saved   = eeconfig_read_user();
    bool     reset   = (saved >> 24) != LIGHTING_MARKER || (LIGHTING_RESET && (saved & 0xffff) != LIGHTING_RESET);
    bool     changed = ((saved >> 16) & 0xff) != RGB_MATRIX_EFFECT_MAX;
    if (!reset && !changed) return;

    if (reset) {
        eeconfig_update_rgb_matrix_default();
        keyboard_config.disable_layer_led = false;
        keyboard_config.rgb_matrix_enable = true;
        eeconfig_update_kb(keyboard_config.raw);
    } else {
        rgb_matrix_mode(RGB_MATRIX_DEFAULT_MODE);
    }
    eeconfig_update_user(((uint32_t)LIGHTING_MARKER << 24) | ((uint32_t)RGB_MATRIX_EFFECT_MAX << 16) | (LIGHTING_RESET ? LIGHTING_RESET : (saved & 0xffff)));
}
