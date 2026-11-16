#include "../dj_internal.hpp"
#include <algorithm>
#include <cmath>

extern "C" {

void dj_state_push_card(dj_engine_t* engine, dj_card_kind_t kind, uint32_t target_id, const char* badge) {
    if (!engine) return;
    dj::OwnedZCard card;
    card.stack_id = engine->next_stack_id++;
    card.kind = kind;
    card.target_id = target_id;
    card.title_badge = badge ? badge : "";
    engine->z_stack.push_back(std::move(card));
    engine->zoomed_out = false;
}

void dj_state_focus_depth(dj_engine_t* engine, int32_t z_depth) {
    if (!engine || engine->z_stack.empty()) return;
    if (z_depth >= 0) {
        engine->zoomed_out = false;
        return;
    }
    size_t back_steps = static_cast<size_t>(-z_depth);
    if (back_steps >= engine->z_stack.size()) {
        back_steps = engine->z_stack.size() - 1;
    }
    size_t target_idx = engine->z_stack.size() - 1 - back_steps;
    dj::OwnedZCard chosen = std::move(engine->z_stack[target_idx]);
    engine->z_stack.erase(engine->z_stack.begin() + static_cast<ptrdiff_t>(target_idx));
    engine->z_stack.push_back(std::move(chosen));
    engine->zoomed_out = false;
}

void dj_state_set_zoomed_out(dj_engine_t* engine, bool zoomed_out) {
    if (engine) engine->zoomed_out = zoomed_out;
}

bool dj_state_is_zoomed_out(dj_engine_t* engine) {
    return engine ? engine->zoomed_out : false;
}

size_t dj_state_get_zstack(dj_engine_t* engine, const dj_zcard_t** out_cards) {
    if (!engine || !out_cards) return 0;
    engine->arena_zstack_c.clear();
    engine->arena_zstack_c.reserve(engine->z_stack.size());

    size_t n = engine->z_stack.size();
    for (size_t i = 0; i < n; ++i) {
        // Return front-to-back (z_depth = 0 at index 0, -1 at index 1, ...)
        size_t rev_idx = n - 1 - i;
        int32_t z = -static_cast<int32_t>(i);
        const auto& src = engine->z_stack[rev_idx];

        dj_zcard_t c{};
        c.stack_id = src.stack_id;
        c.kind = src.kind;
        c.target_id = src.target_id;
        c.title_badge = src.title_badge.c_str();
        c.z_depth = z;
        c.blur_radius = (z == 0) ? 0.0f : std::min(24.0f, static_cast<float>(-z) * 6.5f);
        c.scale = std::pow(0.94f, static_cast<float>(-z));
        engine->arena_zstack_c.push_back(c);
    }

    *out_cards = engine->arena_zstack_c.data();
    return engine->arena_zstack_c.size();
}

void dj_state_push_recent_kanji(dj_engine_t* engine, uint32_t codepoint) {
    if (!engine || codepoint == 0) return;
    auto& rk = engine->recent_kanji;
    rk.erase(std::remove(rk.begin(), rk.end(), codepoint), rk.end());
    rk.insert(rk.begin(), codepoint);
    if (rk.size() > 6) {
        rk.resize(6);
    }
}

size_t dj_state_get_recent_kanji(dj_engine_t* engine, uint32_t out_codepoints[6]) {
    if (!engine || !out_codepoints) return 0;
    for (size_t i = 0; i < 6; ++i) {
        out_codepoints[i] = (i < engine->recent_kanji.size()) ? engine->recent_kanji[i] : 0;
    }
    return engine->recent_kanji.size();
}

} // extern "C"
