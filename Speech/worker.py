"""Persistent local Kokoro worker. Stdout is a newline-delimited JSON protocol."""
from __future__ import annotations

import contextlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from speech_renderer import Renderer, utf16_length


def chunks(text: str, limit: int = 360):
    cursor = 0
    while cursor < len(text):
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        if cursor == len(text):
            return
        end = min(cursor + limit, len(text))
        if end < len(text):
            candidates = list(re.finditer(r"[.!?](?:[\"'’”])?\s+|\n\n", text[cursor:end]))
            if candidates:
                end = cursor + candidates[-1].end()
            else:
                space = text.rfind(" ", cursor, end)
                if space > cursor:
                    end = space + 1
        value = text[cursor:end].rstrip()
        if value:
            yield value, utf16_length(text[:cursor])
        cursor = end


def emit(message):
    print(json.dumps(message, ensure_ascii=False), flush=True)


def main():
    import truststore
    truststore.inject_into_ssl()
    renderer = Renderer(Path(sys.argv[1]))
    for line in sys.stdin:
        request = {}
        try:
            request = json.loads(line)
            job = request["id"]
            for index, (text, offset) in enumerate(chunks(request["text"])):
                end = offset + utf16_length(text)
                hints = [{**hint, 'charIndex': hint['charIndex'] - offset}
                         for hint in request.get('pronunciations', [])
                         if offset <= hint['charIndex'] and hint['charIndex'] + hint['charLength'] <= end]
                with contextlib.redirect_stdout(sys.stderr):
                    clip = renderer.render(text, request["voice"], hints)
                for word in clip["words"]:
                    word["charIndex"] += offset
                emit({"id": job, "type": "chunk", "index": index,
                      "chunk": {"key": clip["key"], "durationMs": clip["durationMs"],
                                "words": clip["words"], "charOffset": offset}})
            emit({"id": job, "type": "complete"})
        except Exception as error:
            emit({"id": request.get("id", ""), "type": "error", "message": str(error)})


if __name__ == "__main__":
    main()
