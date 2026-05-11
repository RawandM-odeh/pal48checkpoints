"""
Parse Arabic checkpoint lines: match name/aliases, direction (default both), status.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Literal

DirectionMode = Literal["both", "entrance", "exit"]

_CANON = frozenset(
    {"open", "closed", "crowded", "army_present", "settlers_present"}
)

# Longest Arabic keys first for greedy match
_STATUS_AR: list[tuple[str, str]] = [
    ("مستوطنون", "settlers_present"),
    ("مستوطنين", "settlers_present"),
    ("مستوطن", "settlers_present"),
    ("جيش", "army_present"),
    ("أزمة", "crowded"),
    ("ازمة", "crowded"),
    ("زحمة", "crowded"),
    ("مغلق", "closed"),
    ("مسكر", "closed"),
    ("مفتوح", "open"),
    ("سالكة", "open"),
    ("سالكه", "open"),
    ("سالك", "open"),
]

# Explicit both directions
_BOTH_PHRASES = [
    "الداخل والخارج",
    "الداخل والطالع",
    "داخل وطالع",
    "داخل والطالع",
    "الدخول والخروج",
    "الجهتين",
    "دخول وخروج",
]

_ENTRANCE_PHRASES = [
    "عالدخال",
    "على الدخول",
    "على الداخل",
    "للداخل الى",
    "للداخل إلى",
    "للداخل",
    "الاتجاه الداخل",
    "جهة الدخول",
    "اتجاه الدخول",
    "على جهة الدخول",
    "بالدخول",
    " للداخل ",
]

_EXIT_PHRASES = [
    "عالخروج",
    "على الخروج",
    "للخروج",
    "للخارج منها",
    "للخارج",
    "الاتجاه الخارج",
    "جهة الخروج",
    "اتجاه الخروج",
    "على جهة الخروج",
    "بالخروج",
    "الخارج منها",
    " للخارج ",
    "الطالع",
    " طالع ",
]


def normalize_ar(text: str) -> str:
    """NFC, strip tatweel/diacritics, unify alef/ta marbuta heuristics, collapse spaces."""
    s = unicodedata.normalize("NFC", text or "")
    s = re.sub(r"[\u0640\u064B-\u065F\u0670]", "", s)
    # Alef variants → ا
    for a, b in (
        ("\u0622", "ا"),
        ("\u0623", "ا"),
        ("\u0625", "ا"),
        ("\u0671", "ا"),
    ):
        s = s.replace(a, b)
    # Ta marbuta ↔ heh for fuzzy name match (optional light touch)
    s = s.replace("\u0629", "ه")  # ة → ه
    s = re.sub(r"\s+", " ", s).strip()
    return s.casefold() if hasattr(str, "casefold") else s.lower()


def normalize_status_token(raw: str) -> str:
    v = (raw or "").strip().lower()
    return v if v in _CANON else "open"


@dataclass(frozen=True)
class ParsedLine:
    checkpoint_id: str
    direction: DirectionMode
    status: str


def _strip_noise_for_match(s: str) -> str:
    """Remove common emoji / punctuation that appears around status words."""
    s = re.sub(r"[\u2700-\u27BF\u2600-\u26FF✅✔️✓❌·•]+", " ", s)
    return s


def _detect_direction(remainder_norm: str) -> DirectionMode:
    r = remainder_norm
    if any(normalize_ar(p) in r for p in _BOTH_PHRASES):
        return "both"
    has_in = any(normalize_ar(p) in r for p in _ENTRANCE_PHRASES)
    has_out = any(normalize_ar(p) in r for p in _EXIT_PHRASES)
    if has_in and not has_out:
        return "entrance"
    if has_out and not has_in:
        return "exit"
    if has_in and has_out:
        return "both"
    return "both"


def _detect_status(remainder_norm: str) -> str | None:
    r = _strip_noise_for_match(remainder_norm)
    r = normalize_ar(r)
    for ar, canon in _STATUS_AR:
        if normalize_ar(ar) in r:
            return canon
    # English tokens
    for token, canon in (
        ("army_present", "army_present"),
        ("settlers_present", "settlers_present"),
        ("crowded", "crowded"),
        ("closed", "closed"),
        ("open", "open"),
    ):
        if token in r.replace(" ", ""):
            return canon
    return None


def match_checkpoint_id(message_norm: str, sorted_variants: list[tuple[str, str]]) -> str | None:
    """First (doc_id, variant) where normalized variant appears in message (longest variants first)."""
    mn = message_norm
    for doc_id, variant in sorted_variants:
        vn = normalize_ar(variant)
        if len(vn) < 2:
            continue
        if vn in mn:
            return doc_id
    return None


def parse_line(
    line: str,
    sorted_variants: list[tuple[str, str]],
) -> ParsedLine | None:
    """
    [sorted_variants] = list of (doc_id, alias_or_name) sorted by len(normalize(alias)) descending.
    """
    raw = (line or "").strip()
    if not raw:
        return None
    cleaned = _strip_noise_for_match(raw)
    msg_norm = normalize_ar(cleaned)
    cid = match_checkpoint_id(msg_norm, sorted_variants)
    if cid is None:
        return None

    # Remove first occurrence of matched variant (longest match for this doc)
    remainder = msg_norm
    for doc_id, variant in sorted_variants:
        if doc_id != cid:
            continue
        vn = normalize_ar(variant)
        if vn in remainder:
            remainder = remainder.replace(vn, " ", 1)
            break
    remainder = re.sub(r"\s+", " ", remainder).strip()

    status = _detect_status(remainder)
    if status is None:
        return None

    direction = _detect_direction(remainder)
    return ParsedLine(checkpoint_id=cid, direction=direction, status=status)


def parse_message(text: str, sorted_variants: list[tuple[str, str]]) -> list[ParsedLine]:
    out: list[ParsedLine] = []
    for part in re.split(r"[\r\n]+", text or ""):
        p = parse_line(part, sorted_variants)
        if p is not None:
            out.append(p)
    return out
