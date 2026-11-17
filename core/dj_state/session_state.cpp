/**
 * @file session_state.cpp
 * @brief `dj_state` — session-state module.
 *
 * The session state (including the 6-slot recent-kanji ring) is currently
 * managed directly in `core/dj_capi.cpp`. This translation unit exists to
 * give the `dj_state` module a home; as state grows (Z-stack, search
 * history, SRS progress, active-recall masks) it should be moved here.
 */
#include "../dj_internal.hpp"
