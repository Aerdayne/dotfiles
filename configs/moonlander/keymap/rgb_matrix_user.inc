// Warm lighting for the layers without Oryx colours: Molten gold and Embers, each in a Sunset and an Amber
// palette. Next animation reaches them along with the built-in animations ticked in Oryx; the speed and
// brightness keys work as usual.
RGB_MATRIX_EFFECT(molten_gold_sunset)
RGB_MATRIX_EFFECT(molten_gold_amber)
RGB_MATRIX_EFFECT(embers_sunset)
RGB_MATRIX_EFFECT(embers_amber)

#ifdef RGB_MATRIX_CUSTOM_EFFECT_IMPLS
#    include <math.h>

#    define WARM_TAU 6.2831853f

// Palettes from dark to bright, as values sent to the LEDs. They have no blue, so reds stay red rather than
// pink, and orange and yellow take much less green than on a screen, as the LEDs' green is very bright.
typedef struct {
    uint8_t r, g;
} warm_color_t;
#    define WARM_STOPS 5
static const warm_color_t warm_sunset[WARM_STOPS] = {{40, 0}, {130, 0}, {230, 10}, {255, 62}, {255, 150}};
static const warm_color_t warm_amber[WARM_STOPS]  = {{60, 2}, {150, 12}, {255, 50}, {255, 110}, {255, 175}};

static void warm_set_color(uint8_t i, const warm_color_t *palette, float p) {
    if (p < 0) p = 0;
    if (p > 1) p = 1;
    float   at    = p * (WARM_STOPS - 1);
    uint8_t below = at >= WARM_STOPS - 1 ? WARM_STOPS - 2 : (uint8_t)at;
    float   mix   = at - below;
    uint8_t r     = palette[below].r + (palette[below + 1].r - palette[below].r) * mix;
    uint8_t g     = palette[below].g + (palette[below + 1].g - palette[below].g) * mix;
    rgb_matrix_set_color(i, scale8(r, rgb_matrix_config.hsv.v), scale8(g, rgb_matrix_config.hsv.v), 0);
}

// Animation time in seconds. It follows the speed setting (64 is the speed of the preview) and wraps every
// 10 minutes. Every motion below repeats a whole number of times in that, so the wrap doesn't show, and the
// maths stays precise however long the keyboard stays on.
#    define WARM_LOOP_MS 600000
static uint32_t warm_ms, warm_last_tick, warm_remainder;

static float warm_time(effect_params_t *params) {
    if (params->init) warm_last_tick = g_rgb_timer;
    if (params->iter == 0) {
        uint32_t elapsed = MIN(g_rgb_timer - warm_last_tick, 1000);
        uint32_t scaled  = elapsed * rgb_matrix_config.speed + warm_remainder;
        warm_last_tick   = g_rgb_timer;
        warm_ms          = (warm_ms + scaled / 64) % WARM_LOOP_MS;
        warm_remainder   = scaled % 64;
    }
    return warm_ms / 1000.0f;
}

// A sine wave that repeats `times` times per loop, shifted by `offset` turns
static float warm_wave(float t, uint16_t times, float offset) {
    float turns = t * times / (WARM_LOOP_MS / 1000) + offset;
    return sinf(WARM_TAU * (turns - floorf(turns)));
}

// Gives each key its own fixed randomness
static uint32_t warm_hash(uint32_t x) {
    x ^= x >> 16;
    x *= 0x7feb352d;
    x ^= x >> 15;
    x *= 0x846ca68b;
    return x ^ (x >> 16);
}

// Amber keys, darker toward the thumbs, with a soft highlight sweeping left to right every 6.25 seconds
static float molten_gold(uint8_t i, float t) {
    float x = g_led_config.point[i].x / 16.0f, y = g_led_config.point[i].y / 16.0f;
    float sweeps = t * 96 / (WARM_LOOP_MS / 1000);
    float from   = x + 0.55f * y - (-4 + (sweeps - floorf(sweeps)) * 26);
    return 0.6f - 0.05f * y + 0.05f * warm_wave(t, 43, x * 0.35f / WARM_TAU) + 0.45f * expf(-from * from / 2.4f);
}

// Deep red coals. Each key glows up to orange and yellow every 8 to 21 seconds, then cools back down.
static float embers(uint8_t i, float t) {
    float    x      = g_led_config.point[i].x / 16.0f;
    uint32_t random = warm_hash(i + 1);
    float    offset = (random & 0xffff) / 65536.0f;
    float    coal   = 0.3f + 0.07f * warm_wave(t, 53, x * 0.4f / WARM_TAU) + 0.05f * warm_wave(t, 162, offset);
    float    glow   = warm_wave(t, 29 + (random >> 16) % 44, offset);
    if (glow < 0) glow = 0;
    float squared = glow * glow, eighth = squared * squared * squared * squared;
    return coal + 0.66f * eighth * squared;
}

static bool warm_run(effect_params_t *params, float (*shape)(uint8_t, float), const warm_color_t *palette) {
    RGB_MATRIX_USE_LIMITS(led_min, led_max);
    float t = warm_time(params);
    for (uint8_t i = led_min; i < led_max; i++) {
        RGB_MATRIX_TEST_LED_FLAGS();
        warm_set_color(i, palette, shape(i, t));
    }
    return rgb_matrix_check_finished_leds(led_max);
}

static bool molten_gold_sunset(effect_params_t *params) {
    return warm_run(params, molten_gold, warm_sunset);
}
static bool molten_gold_amber(effect_params_t *params) {
    return warm_run(params, molten_gold, warm_amber);
}
static bool embers_sunset(effect_params_t *params) {
    return warm_run(params, embers, warm_sunset);
}
static bool embers_amber(effect_params_t *params) {
    return warm_run(params, embers, warm_amber);
}
#endif
