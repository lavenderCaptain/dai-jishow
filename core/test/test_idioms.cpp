#include "dj_test.hpp"
#include "dj_internal.hpp"

TEST(anchor_lemmas_exact_tokens) {
    CHECK(dj::anchor_lemmas_contains("隣,芝,生,青", "隣"));
    CHECK(dj::anchor_lemmas_contains("隣,芝,生,青", "青"));
    CHECK(dj::anchor_lemmas_contains("隣, 芝, 生, 青", "芝"));
    CHECK(dj::anchor_lemmas_contains("担", "担"));
    CHECK(!dj::anchor_lemmas_contains("隣,芝,生,青", "木"));
    CHECK(!dj::anchor_lemmas_contains("", "隣"));
    CHECK(!dj::anchor_lemmas_contains("隣,芝", ""));
    // Multi-character token does not partially match single character token
    CHECK(!dj::anchor_lemmas_contains("木馬,川", "木"));
    CHECK(dj::anchor_lemmas_contains("木馬,川", "木馬"));
}

TEST(encode_utf8_kanji_and_invalid) {
    char buf[8];
    dj::encode_utf8(0x6728, buf); // 木
    CHECK_EQ_STR(std::string(buf), "木");
    dj::encode_utf8(0x2000B, buf); // Extension B
    CHECK_EQ_STR(std::string(buf), "\xF0\xA0\x80\x8B");
    dj::encode_utf8(0x110000, buf); // Out of range
    CHECK_EQ_STR(std::string(buf), "");
}
