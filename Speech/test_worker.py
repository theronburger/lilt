import unittest

from worker import chunks
from speech_renderer import align_tokens, apply_pronunciations, utf16_length
from types import SimpleNamespace


class WordMappingTests(unittest.TestCase):
    def test_phoneme_overrides_keep_repeated_word_text_and_utf16_spans(self):
        text = '👋 read read.'
        tokens = [SimpleNamespace(text='👋', phonemes=''), SimpleNamespace(text='read', phonemes='ɹˈid'),
                  SimpleNamespace(text='read', phonemes='ɹˈid'), SimpleNamespace(text='.', phonemes='.')]
        apply_pronunciations(text, tokens, [{'charIndex': 8, 'charLength': 4, 'phonemes': 'ɹˈɛd'}])
        self.assertEqual([t.text for t in tokens], ['👋', 'read', 'read', '.'])
        self.assertEqual(tokens[1].phonemes, 'ɹˈid')
        self.assertEqual(tokens[2].phonemes, 'ɹˈɛd')

    def test_chunks_preserve_character_offsets(self):
        text = "Hello 👋. " + "The same word repeats. " * 50 + "\n\nThe final café."
        pieces = list(chunks(text))
        self.assertGreater(len(pieces), 1)
        raw = text.encode("utf-16-le")
        for piece, offset in pieces:
            restored = raw[offset * 2:(offset + utf16_length(piece)) * 2].decode("utf-16-le")
            self.assertEqual(restored, piece)
        self.assertEqual(" ".join(piece for piece, _ in pieces).split(), text.split())

    def test_repeated_words_map_to_distinct_occurrences(self):
        tokens = [SimpleNamespace(text="hello", start_ts=0, end_ts=0.2),
                  SimpleNamespace(text="hello", start_ts=0.3, end_ts=0.5)]
        words, cursor = align_tokens("hello hello", tokens, 0, 1000, 600)
        self.assertEqual([word["charIndex"] for word in words], [0, 6])
        self.assertEqual(words[1]["startMs"], 1300)
        self.assertEqual(cursor, 11)

    def test_alignment_rejects_missing_spoken_content(self):
        tokens = [SimpleNamespace(text="world", start_ts=0, end_ts=0.2)]
        with self.assertRaises(ValueError):
            align_tokens("hello world", tokens, 0, 0, 500)


if __name__ == "__main__":
    unittest.main()
