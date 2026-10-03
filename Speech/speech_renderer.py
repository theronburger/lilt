from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import uuid

VOICES = {v["id"]: v["name"] for v in json.loads((Path(__file__).with_name("voices.json")).read_text())}
VERSION = "kokoro-0.9.4-timings-2"
RATE = 24_000
PHONES = set('AIWYbdfhijklmnpstuvwzðŋɑɔəɛɜɡɪɹʃʊʌʒʤʧˈˌθᵊOæɾᵻQaɒː ')


def utf16_length(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def align_tokens(text, tokens, cursor, offset_ms, duration_ms):
    words = []
    for token in tokens:
        if not token.text:
            continue
        start = text.find(token.text, cursor)
        if start < 0 or text[cursor:start].strip():
            raise ValueError(f"Cannot align narration at {token.text!r}; use plain spoken text.")
        end = start + len(token.text)
        cursor = end
        if token.start_ts is None or token.end_ts is None:
            continue
        left = max(0, float(token.start_ts) * 1000)
        right = min(duration_ms, float(token.end_ts) * 1000)
        if not 0 <= left <= right <= duration_ms:
            raise ValueError("Kokoro returned invalid token timestamps.")
        words.append({"charIndex": utf16_length(text[:start]), "charLength": utf16_length(token.text), "startMs": offset_ms + left, "endMs": offset_ms + right})
    return words, cursor


def apply_pronunciations(text, tokens, hints):
    """Override sounds only; token text stays intact for Kokoro's real timestamps."""
    spans = {(h['charIndex'], h['charLength']): h['phonemes'] for h in hints}
    cursor = 0
    for token in tokens:
        if not token.text:
            continue
        start = text.find(token.text, cursor)
        if start < 0 or text[cursor:start].strip():
            raise ValueError('Cannot align pronunciation hints to Kokoro tokens.')
        cursor = start + len(token.text)
        phones = spans.get((utf16_length(text[:start]), utf16_length(token.text)))
        if phones:
            # Kokoro v0.9.4's model uses T for the American flap sound.
            token.phonemes = phones.replace('ɾ', 'T')


class Renderer:
    def __init__(self, directory: Path):
        self.directory = directory
        directory.mkdir(parents=True, exist_ok=True)
        self.pipelines = {}

    def render(self, text: str, voice: str, pronunciations=None):
        if voice not in VOICES:
            raise ValueError("Unknown Kokoro voice.")
        if not isinstance(text, str) or not text.strip() or len(text) > 6000:
            raise ValueError("Narration must contain 1–6000 characters.")
        hints = []
        for hint in (pronunciations or [])[:32]:
            if not isinstance(hint, dict):
                continue
            start, length, phones = hint.get('charIndex'), hint.get('charLength'), hint.get('phonemes')
            if (type(start) is int and type(length) is int and start >= 0 and length > 0
                    and start + length <= utf16_length(text) and isinstance(phones, str)
                    and 0 < len(phones) <= 64 and set(phones) <= PHONES):
                hints.append({'charIndex': start, 'charLength': length, 'phonemes': phones})
        cache_parts = [VERSION, voice, text]
        if hints:
            cache_parts += ['pronunciation-hints-1', hints]
        key = hashlib.sha256(json.dumps(cache_parts, ensure_ascii=False).encode()).hexdigest()
        manifest_path = self.directory / f"{key}.json"
        audio_path = self.directory / f"{key}.wav"
        if manifest_path.exists() and audio_path.exists():
            return {**json.loads(manifest_path.read_text()), "cached": True}
        import numpy as np
        import soundfile as sf
        from kokoro import KPipeline, KModel

        language = voice[0]
        if language not in self.pipelines:
            model = next(iter(self.pipelines.values())).model if self.pipelines else True
            if model is True and os.environ.get("LILT_MODEL_DIRECTORY"):
                assets = Path(os.environ["LILT_MODEL_DIRECTORY"])
                model = KModel(repo_id="hexgrad/Kokoro-82M", config=str(assets / "config.json"), model=str(assets / "kokoro-v1_0.pth")).to("cpu").eval()
            self.pipelines[language] = KPipeline(lang_code=language, repo_id="hexgrad/Kokoro-82M", model=model, device="cpu")
        pipeline = self.pipelines[language]
        speech_voice = str(Path(os.environ["LILT_MODEL_DIRECTORY"]) / "voices" / f"{voice}.pt") if os.environ.get("LILT_MODEL_DIRECTORY") else voice
        _, tokens = pipeline.g2p(text, preprocess=False)
        if hints:
            apply_pronunciations(text, tokens, hints)
        pieces, words = [], []
        cursor, samples = 0, 0
        for result in pipeline.generate_from_tokens(tokens, voice=speech_voice, speed=1):
            audio = result.audio.detach().cpu().numpy()
            if not np.isfinite(audio).all():
                raise ValueError("Kokoro returned invalid audio samples.")
            aligned, cursor = align_tokens(text, result.tokens or [], cursor, samples * 1000 / RATE, len(audio) * 1000 / RATE)
            words.extend(aligned)
            pieces.append(audio)
            samples += len(audio)
        if not pieces or not words or text[cursor:].strip():
            raise ValueError("Kokoro did not align the complete narration.")
        result = {"key": key, "voice": voice, "durationMs": samples * 1000 / RATE, "words": words}
        temporary = self.directory / f"{key}.{uuid.uuid4().hex}"
        try:
            sf.write(str(temporary) + ".wav", np.concatenate(pieces), RATE, subtype="PCM_16")
            Path(str(temporary) + ".json").write_text(json.dumps(result))
            os.replace(str(temporary) + ".wav", audio_path)
            os.replace(str(temporary) + ".json", manifest_path)
        finally:
            Path(str(temporary) + ".wav").unlink(missing_ok=True)
            Path(str(temporary) + ".json").unlink(missing_ok=True)
        return {**result, "cached": False}
