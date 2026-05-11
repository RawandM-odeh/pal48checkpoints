"""Read allowed Telegram chat ids from environment."""

from __future__ import annotations

import os


def _env_strip(key: str) -> str:
    raw = os.environ.get(key, "") or ""
    raw = raw.strip()
    if "#" in raw:
        raw = raw.split("#", 1)[0].strip()
    return raw


def load_chat_ids() -> list[int]:
    """
    TELEGRAM_SOURCE_CHAT_IDS=-100111,-100222,...
    Or a single TELEGRAM_SOURCE_CHAT_ID=-100111
    """
    multi = _env_strip("TELEGRAM_SOURCE_CHAT_IDS")
    if multi:
        out: list[int] = []
        for part in multi.split(","):
            p = part.strip()
            if not p:
                continue
            out.append(int(p))
        if not out:
            raise ValueError("TELEGRAM_SOURCE_CHAT_IDS is empty after parsing")
        return out
    single = _env_strip("TELEGRAM_SOURCE_CHAT_ID")
    if single:
        return [int(single)]
    raise ValueError(
        "Set TELEGRAM_SOURCE_CHAT_IDS (comma-separated) or TELEGRAM_SOURCE_CHAT_ID"
    )
