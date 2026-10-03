"""Pre-render all supported, word-aligned Kokoro voices. No playback or history writes."""
import sys,json,shutil
from pathlib import Path
import truststore
truststore.inject_into_ssl()
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'Speech'))
from speech_renderer import Renderer
voices=json.loads((root/'Speech/voices.json').read_text())
out=root/'work/voice-previews';out.mkdir(parents=True,exist_ok=True)
renderer=Renderer(out/'cache')
for voice in voices:
    path=out/(voice['id']+'.wav')
    if path.exists():continue
    result=renderer.render("This is Lilt. A little space to listen, and take things at your own pace.",voice['id'])
    shutil.copyfile(out/'cache'/(result['key']+'.wav'),path)
    print(voice['id'],round(result['durationMs']/1000,2),flush=True)
print(f'Ready: {len(voices)} previews',flush=True)
