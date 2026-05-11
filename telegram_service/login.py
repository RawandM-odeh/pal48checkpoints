"""
One-shot Telethon login: creates the session file next to this script (or path in .env).

Usage (from telegram_service/):
  python -m venv .venv
  .\\.venv\\Scripts\\Activate.ps1
  pip install -r requirements.txt
  copy .env.example .env   # then edit .env
  python login.py
"""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from dotenv import load_dotenv
from telethon import TelegramClient


def _session_path_for_telethon() -> str:
    """Normalize TELEGRAM_SESSION_PATH so Telethon gets a stem, not *.session."""
    raw = os.environ.get("TELEGRAM_SESSION_PATH", "telegram").strip()
    if not raw:
        return "telegram"
    p = Path(raw)
    if p.suffix.lower() == ".session":
        p = p.with_suffix("")
    return str(p)


async def _main() -> None:
    env_path = Path(__file__).resolve().parent / ".env"
    load_dotenv(env_path)

    api_id = int(os.environ["TELEGRAM_API_ID"])
    api_hash = os.environ["TELEGRAM_API_HASH"]
    session = _session_path_for_telethon()

    client = TelegramClient(session, api_id, api_hash)
    await client.start()
    me = await client.get_me()
    session_file = Path(session).resolve().with_suffix(".session")
    print("Login OK.")
    print("  User:", me.first_name, f"(@{me.username})" if me.username else "")
    print("  Session file:", session_file)
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(_main())
