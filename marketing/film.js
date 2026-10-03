const canvas = document.querySelector('#film');
const ctx = canvas.getContext('2d', {alpha: false});
const audio = document.querySelector('#audio');
const slider = document.querySelector('#position');
const status = document.querySelector('#status');
const manifest = await (await fetch('assets/narration.json')).json();
const duration = manifest.durationMs / 1000;
const ink = '#1D232C', blue = '#2763E7', paper = '#FAFAF8';
const font = '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
const logo = new Image(); logo.src = 'assets/lilt-mark.svg';
try { await logo.decode(); } catch {}
slider.max = String(duration);
let playing = false, current = 0;
const clamp = x => Math.max(0, Math.min(1, x));
const ease = x => 1 - Math.pow(1-clamp(x), 3);
const lerp = (a,b,x) => a+(b-a)*x;
const phase = (t,a,b) => clamp((t-a)/(b-a));

function rounded(x,y,w,h,r,fill,shadow=0) {
  ctx.save();
  if (shadow) {ctx.shadowColor='#17272724';ctx.shadowBlur=shadow;ctx.shadowOffsetY=shadow*.35;}
  ctx.fillStyle=fill;ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.fill();ctx.restore();
}
function text(value,x,y,size=32,color=ink,weight=400) {
  ctx.font=`${weight} ${size}px ${font}`;ctx.fillStyle=color;ctx.fillText(value,x,y);
}
function paragraph(value,x,y,w,size=30,line=45,color=ink,limit=Infinity) {
  ctx.font=`400 ${size}px ${font}`;
  let lineText='',row=0;
  for(const word of value.split(' ')) {
    const next=lineText?`${lineText} ${word}`:word;
    if(ctx.measureText(next).width>w&&lineText) {
      if(row>=limit)return row; text(lineText,x,y+row*line,size,color);row++;lineText=word;
    } else lineText=next;
  }
  if(row<limit)text(lineText,x,y+row*line,size,color);
  return row+1;
}
function brand(x,y,size=44) {
  if(logo.complete&&logo.naturalWidth)ctx.drawImage(logo,x,y-size*.8,size,size);
  else {ctx.strokeStyle=blue;ctx.lineWidth=5;ctx.lineCap='round';[.4,.75,1,.65,.3].forEach((h,i)=>{ctx.beginPath();ctx.moveTo(x+i*9,y-h*size*.75);ctx.lineTo(x+i*9,y);ctx.stroke();});}
  text('Lilt',x+size+14,y,size,ink,650);
}
function cursor(x,y,opacity=1,cross=false,click=0) {
  ctx.save();ctx.globalAlpha=opacity;ctx.translate(x,y);
  if(click>0){ctx.strokeStyle=`rgba(0,122,255,${(1-click)*.7})`;ctx.lineWidth=3;ctx.beginPath();ctx.arc(0,0,12+click*38,0,Math.PI*2);ctx.stroke();}
  ctx.strokeStyle='white';ctx.lineWidth=4;ctx.lineJoin='round';ctx.fillStyle='#202526';
  if(cross){ctx.strokeStyle='#202526';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(-15,0);ctx.lineTo(15,0);ctx.moveTo(0,-15);ctx.lineTo(0,15);ctx.stroke();}
  else {ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(0,29);ctx.lineTo(8,22);ctx.lineTo(15,38);ctx.lineTo(22,35);ctx.lineTo(14,19);ctx.lineTo(27,19);ctx.closePath();ctx.stroke();ctx.fill();}
  ctx.restore();
}
const documents = [
  ['A little more context', 'There are a few things to consider before deciding on an approach. The first is how the information fits together. Each change looks simple on its own, but the details matter once you put them next to one another. Let’s go through the examples, then look at what happens in practice. The notes below cover the original question, a few alternatives, and the reasons for the final choice.'],
  ['Notes from Monday', 'The small details\nWe went through the feedback and collected the outstanding questions. There are three changes to make before the next version. First, make the settings easier to find. Then check how the layout behaves with longer text. Finally, go back through the examples and make sure the explanations still match what happens on screen.'],
  ['One more thing to read', 'How the pieces fit together\nThis is the longer explanation. It starts with a straightforward idea and follows it through a few different situations. The first example is deliberately small. The second adds a few more moving parts, including the bits that are easy to miss the first time around. There is a summary at the end, followed by notes on the remaining questions.'],
  ['Here’s the full answer', 'A closer look\nThe answer depends on which part of the problem you are trying to solve. It helps to start with the simple case, then consider what changes when the inputs are less predictable. The following sections go through that process step by step, with examples for the most common situations. There are a few tradeoffs worth keeping in mind.'],
  ['While we’re here…', 'A few follow-up notes\nWe can take the same approach to the rest of the document. Start with the parts that are already working, check the assumptions, and then fill in the gaps. The next section covers the details. After that, there is a longer discussion of the alternatives and some examples of how they would work.']
];
function documentCard(i,t) {
  const arrival=ease(phase(t,i*.64, i*.64+.95));
  const positions=[[270,195,-.018],[795,295,.035],[95,445,-.045],[1060,80,.055],[575,470,-.012]];
  const [x,y,angle]=positions[i];
  const collapse=ease(phase(t,4.2,5.1));
  ctx.save();ctx.translate(lerp(x,810+i*3,collapse),lerp(y-350*(1-arrival),450+i*4,collapse));
  ctx.rotate(angle*(1-collapse));ctx.scale(lerp(.95,.25,collapse),lerp(.95,.25,collapse));
  ctx.globalAlpha=arrival*(1-phase(t,5.0,5.6));
  rounded(0,0,790,620,20,'white',32);
  text(documents[i][0],42,70,31,ink,650);
  ctx.fillStyle='#e8eae5';ctx.fillRect(42,101,706,1);
  const reveal=Math.floor(documents[i][1].length*phase(t,i*.64+.2,i*.64+1.65));
  const parts=documents[i][1].slice(0,reveal).split('\n');
  let yy=153;
  for(const part of parts)yy+=paragraph(part,42,yy,704,27,40,'#5a6260')*40+12;
  ctx.restore();
}
function intro(t) {
  const fade=1-phase(t,10.3,10.9);
  ctx.save();ctx.globalAlpha=fade;
  if(t<5.6)for(let i=0;i<documents.length;i++)documentCard(i,t);
  if(t>5.0){
    const a=ease(phase(t,5,5.55));ctx.globalAlpha=fade*a;
    const value=manifest.prompt.slice(0,Math.floor(manifest.prompt.length*phase(t,5.35,7.9)));
    rounded(558,303+(1-a)*35,1058,232,36,'#edeeea');
    paragraph(value,609,379,942,44,61,ink);
    const r=ease(phase(t,8.65,9.05));
    ctx.globalAlpha=fade*r;brand(320,679,50);text('Try Lilt.',441,770,67,ink,500);
  }
  ctx.restore();
}
const crop={x:340,y:386,w:1240,h:278};
const floating={x:300,y:350,w:1320,h:296};
function wordLayout() {
  ctx.font=`400 36px ${font}`;
  let x=0,y=0;
  return [...manifest.text.matchAll(/\S+/g)].map(match=>{
    const width=ctx.measureText(match[0]).width;
    if(x+width>1160){x=0;y+=59;}
    const word={text:match[0],index:match.index,x,y,width};x+=width+ctx.measureText(' ').width;return word;
  });
}
const layout=wordLayout();
function cropText(x,y,scale,audioPosition=-1){
  ctx.save();ctx.translate(x,y);ctx.scale(scale,scale);
  const active=manifest.clips.text.words.find(w=>audioPosition>=w.startMs&&audioPosition<w.endMs);
  for(const word of layout){
    if(active&&active.charIndex>=word.index&&active.charIndex<word.index+word.text.length){
      rounded(38+word.x-3,24+word.y,word.width+7,45,7,'#007aff29');
      ctx.strokeStyle='#007aff8c';ctx.lineWidth=1.3;ctx.beginPath();ctx.roundRect(38+word.x-3,24+word.y,word.width+7,45,7);ctx.stroke();
    }
    text(word.text,38+word.x,60+word.y,36,ink);
  }
  ctx.restore();
}
function readingPosition(t) {
  const ms=t*1000;
  for(const s of manifest.segments)if(s.clip==='text'&&ms>=s.at&&ms<s.at+s.to-s.from)return s.from+ms-s.at;
  return -1;
}
function controls(x,y,w,position,opacity){
  ctx.save();ctx.globalAlpha=opacity;
  rounded(x,y,w,66,33,'#ffffffd9',18);
  ctx.strokeStyle='#ffffffc9';ctx.lineWidth=1;ctx.beginPath();ctx.roundRect(x+.5,y+.5,w-1,65,33);ctx.stroke();
  rounded(x+27,y+23,6,22,2,'#303838');rounded(x+38,y+23,6,22,2,'#303838');
  rounded(x+79,y+29,w-190,7,4,'#d6d9d7');const progress=clamp(Math.max(0,position)/manifest.clips.text.durationMs);
  rounded(x+79,y+29,(w-190)*progress,7,4,blue);
  rounded(x+72+(w-190)*progress,y+20,17,26,7,'white',4);
  text('1×',x+w-70,y+44,27,'#303838',500);ctx.restore();
}
function demo(t){
  const visible=ease(phase(t,10.55,11.1));
  if(!visible)return;
  const lift=ease(phase(t,13.05,13.9));
  const finish=1-ease(phase(t,manifest.endStart/1000-.1,manifest.endStart/1000+.45));
  ctx.save();ctx.globalAlpha=visible*finish;
  ctx.save();ctx.globalAlpha=1-lift;
  rounded(240,166,1440,727,22,'white',28);
  rounded(240,166,1440,61,22,'#f0f1ee');ctx.fillStyle='#f0f1ee';ctx.fillRect(240,196,1440,32);
  ['#ff6058','#ffbd2d','#28c840'].forEach((color,i)=>rounded(269+i*27,190,14,14,7,color));
  text('Notes',875,205,22,'#6d7470');
  text(manifest.title,378,322,48,ink,600);
  text('A short example for the demo',380,361,23,'#919791');
  cropText(crop.x,crop.y,1);
  text('Your text stays in its original layout.',378,811,27,'#b1b6b0');
  ctx.restore();
  if(t>=11.6&&t<13.2){
    const drag=ease(phase(t,11.8,12.85));
    const x=crop.x-1,y=crop.y-1,w=Math.max(4,crop.w*drag),h=Math.max(4,crop.h*drag);
    ctx.fillStyle='#17292524';ctx.fillRect(240,227,1440,666);
    ctx.save();ctx.beginPath();ctx.rect(x,y,w,h);ctx.clip();ctx.fillStyle='white';ctx.fillRect(crop.x,crop.y,crop.w,crop.h);cropText(crop.x,crop.y,1);ctx.restore();
    ctx.strokeStyle=blue;ctx.lineWidth=2;ctx.strokeRect(x,y,w,h);
    cursor(x+w,y+h,1,true);
    rounded(776,909,368,58,29,'#252d2b');text('Drag over some text',811,947,27,'white');
  }
  if(t>=13.05){
    const x=lerp(crop.x,floating.x,lift),y=lerp(crop.y,floating.y,lift);
    const w=lerp(crop.w,floating.w,lift),h=lerp(crop.h,floating.h,lift),scale=w/crop.w;
    const position=readingPosition(t);
    rounded(x,y,w,h,18,'white',25*lift);cropText(x,y,scale,position);
    const seeking=phase(t,manifest.seekAt/1000-1.0,manifest.seekAt/1000-.15);
    const leaving=phase(t,manifest.seekAt/1000+.8,manifest.seekAt/1000+1.4);
    const hover=Math.max(1-phase(t,15.35,15.55),phase(t,manifest.seekAt/1000-1.1,manifest.seekAt/1000-.9)*(1-leaving));
    controls(627,674,666,position,hover*lift);
    ctx.save();ctx.globalAlpha=hover;rounded(x+w-48,y+12,29,29,14,'#f2f3f0');text('×',x+w-42,y+34,26,'#4b534f');ctx.restore();
    const first=layout.find(word=>word.text==='The');
    const target={x:x+(first.x+48)*scale,y:y+(first.y+58)*scale};
    if(t<16)cursor(1600+phase(t,14.8,15.5)*230,740+phase(t,14.8,15.5)*150,1-phase(t,15.5,15.9));
    if(t>manifest.seekAt/1000-1.1&&t<manifest.seekAt/1000+1.5){
      cursor(lerp(1720,target.x,ease(seeking))+leaving*550,lerp(880,target.y,ease(seeking))+leaving*340,1-leaving,false,phase(t,manifest.seekAt/1000,manifest.seekAt/1000+.4));
    }
    const caption=t<manifest.seekAt/1000-1.2?'The same text, read aloud.':'Click a word to jump to it.';
    ctx.globalAlpha=visible*finish*lift;ctx.textAlign='center';text(caption,960,934,34,'#656d68');ctx.textAlign='left';
  }
  ctx.restore();
}
function ending(t){
  const a=ease(phase(t,manifest.endStart/1000,manifest.endStart/1000+.55));
  if(!a)return;
  ctx.save();ctx.globalAlpha=a;
  brand(798,400+(1-a)*24,100);
  ctx.textAlign='center';text(manifest.endTitle,960,570+(1-a)*24,61,ink,500);
  text(manifest.endDetail,960,648+(1-a)*24,31,'#717a72');
  text('github.com/theronburger/lilt',960,835,28,'#657c8b');ctx.textAlign='left';ctx.restore();
}
function draw(t){
  ctx.fillStyle=paper;ctx.fillRect(0,0,1920,1080);
  if(t<manifest.endStart/1000){brand(65,87,39);text('Select. Listen. Follow along.',1380,85,25,'#7a837b');}
  if(t<10.9)intro(t);demo(t);ending(t);
}
function update(t){current=clamp(t/duration)*duration;draw(current);slider.value=String(current);document.querySelector('#time').textContent=`${Math.floor(current/60)}:${String(Math.floor(current%60)).padStart(2,'0')} / ${Math.ceil(duration)}s`;}
function pause(){playing=false;audio.pause();document.querySelector('#play').textContent='Play';}
function tick(now){if(!playing)return;update(audio.currentTime);if(current>=duration){pause();return;}requestAnimationFrame(tick);}
document.querySelector('#play').onclick=async()=>{if(playing){pause();return;}if(current>=duration)current=0;audio.currentTime=current;await audio.play();playing=true;document.querySelector('#play').textContent='Pause';requestAnimationFrame(tick);};
document.querySelector('#restart').onclick=()=>{pause();audio.currentTime=0;update(0);};
slider.oninput=()=>{pause();audio.currentTime=Number(slider.value);update(Number(slider.value));};
function download(blob,name){const link=document.querySelector('#download');if(link.href.startsWith('blob:'))URL.revokeObjectURL(link.href);link.href=URL.createObjectURL(blob);link.download=name;link.textContent=`Download ${name}`;link.hidden=false;}
document.querySelector('#poster').onclick=()=>{pause();update(17.25);canvas.toBlob(blob=>download(blob,'lilt-demo-poster.png'),'image/png');};
document.querySelector('#export').onclick=async()=>{
  pause();const controls=[...document.querySelectorAll('button,input')];controls.forEach(control=>control.disabled=true);const chunks=[];let failure;
  try{
    const config={codec:'avc1.640028',width:1920,height:1080,bitrate:7_000_000,framerate:30,avc:{format:'annexb'},hardwareAcceleration:'prefer-hardware'};
    if(!globalThis.VideoEncoder||!(await VideoEncoder.isConfigSupported(config)).supported)throw Error('This browser does not support H.264 export. Open this page in a current Chromium browser.');
    const encoder=new VideoEncoder({output:chunk=>{const bytes=new Uint8Array(chunk.byteLength);chunk.copyTo(bytes);chunks.push(bytes);},error:error=>failure=error});
    encoder.configure(config);const frames=Math.ceil(duration*30);
    for(let i=0;i<frames;i++){
      if(failure)throw failure;
      while(encoder.encodeQueueSize>8)await new Promise(resolve=>setTimeout(resolve,4));
      draw(i/30);const frame=new VideoFrame(canvas,{timestamp:Math.round(i*1e6/30),duration:Math.round(1e6/30)});
      encoder.encode(frame,{keyFrame:i%60===0});frame.close();
      if(i%15===0){status.textContent=`Rendering ${Math.round(i/frames*100)}% · ${i} / ${frames} frames`;await new Promise(resolve=>setTimeout(resolve,0));}
    }
    await encoder.flush();encoder.close();download(new Blob(chunks,{type:'video/h264'}),'lilt-demo.h264');
    status.textContent='Rendered. Download the H.264 file, then run scripts/encode.sh to add the soundtrack and make the MP4.';
  }catch(error){status.textContent=error.message;}
  finally{controls.forEach(control=>control.disabled=false);update(17.25);}
};
status.textContent='All text is original demo content. Playback uses the same Kokoro audio and word timings as Lilt.';
update(0);
