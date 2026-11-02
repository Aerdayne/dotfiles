// Added to the end of the Oryx layout's config.h by the moonlander script. Which built-in animations exist is
// set in Oryx (LED Animations in its RGB settings); the warm effects in rgb_matrix_user.inc are always there.

// The lighting a reset goes back to (see lighting.c): Molten gold at full brightness and the preview's speed,
// red for the built-in animations
#undef RGB_MATRIX_DEFAULT_MODE
#define RGB_MATRIX_DEFAULT_MODE RGB_MATRIX_CUSTOM_molten_gold_sunset
#undef RGB_MATRIX_DEFAULT_SPD
#define RGB_MATRIX_DEFAULT_SPD 64
