# Licences and corresponding source

Lilt’s original source code is [MIT-licensed](../LICENSE). The app also bundles third-party software and model weights under their own licences. The downloadable app is not an MIT-only distribution.

The Swift app starts a separate Python speech process. That helper uses these components, among others:

| Component | Licence |
| --- | --- |
| Kokoro model weights | Apache-2.0 |
| phonemizer-fork 3.3.2 | GPL-3.0-or-later |
| eSpeak NG shared library and data | GPL-3.0-or-later, with individual exceptions identified upstream |
| num2words 0.5.14 | LGPL-2.1-or-later |
| espeakng-loader 0.2.4 wrapper | MIT; the bundled eSpeak NG library retains its GPL terms |

The GPL/LGPL terms apply to the covered speech components and their combined distribution. Lilt’s original MIT files retain their notices and permissions; the MIT licence does not replace third-party terms. Other bundled packages retain their own licences, including their copyright notices and any exceptions.

Open **About → Open all third-party notices** in Lilt for the collected texts. They are also in `Lilt.app/Contents/Resources/ThirdPartyNotices.txt` and `Licenses/`. Package versions are recorded in the release’s CycloneDX SBOM and [speech dependency lock](../Speech/requirements.lock).

## Source supplied with releases

Every binary release includes `lilt_VERSION_corresponding-source.tar.gz` beside the app download. It contains:

- `upstream/`: the exact phonemizer-fork and num2words source distributions, espeakng-loader source, and its eSpeak NG submodule source.
- `lilt/`: Lilt’s speech helper, build and packaging scripts, dependency and runtime pins, and licences.
- `SOURCE_MANIFEST.json`: source URLs, revisions and checksums.

The archive is assembled by [collect-sources.py](../scripts/collect-sources.py) from [source-lock.json](../Resources/source-lock.json). It includes the scripts needed to build and install the covered components. It contains no signing keys, API keys, or user readings. Lilt’s full source is also available at each release’s Git tag.

The eSpeak NG loader source is pinned to `146599e29be31bf17d99f0bcb7dbb2f92aef3d95`, including eSpeak NG at `4870adfa25b1a32b4361592f1be8a40337c58d6c`. The wrapper’s [MIT licence](https://github.com/thewh1teagle/espeakng-loader/blob/0ddc87adf77e5850d7eeb542ac8a87d421b64daa/LICENSE) was added in the immediately following commit, with no code changes; that licence accompanies the pinned source.

## Modify or replace the speech helper

Follow the [development setup](development.md#develop), then edit `Speech/` or install a modified dependency into `.venv` before building. For example:

```sh
./scripts/setup.sh
uv pip install --python .venv/bin/python --no-deps /path/to/modified-num2words
./scripts/build.sh --install
```

For native eSpeak NG changes, use the included upstream build instructions and replace its shared library and data in the development Python environment. The helper’s request/response protocol is implemented in `Speech/worker.py` and `Sources/Lilt/SpeechService.swift`.

Build modified apps with your own persistent code-signing identity, as described in the development notes. No publisher signing key is needed. Changing an installed app’s signed contents invalidates its signature; rebuild a development copy to use your changes. If redistributing it, retain the applicable notices and supply corresponding source for the covered components, including your modifications and build scripts.
