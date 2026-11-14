"""Sizes and grades the large Valebound paintings from their full-size
Firefly originals (ASSETS.md section 7).

    python3 tool/art/large_pieces.py <originals> <repo>/assets/art

<originals> is the unpacked valebound-art-large.zip: story/, discoveries/
and scenes/ folders of PNGs named by piece. Needs Pillow, NumPy and SciPy.
Nothing here repaints anything: it resizes, grades the sleeping pictures
toward the app's own "asleep" grey, and makes the valley's four lights
from the one dawn painting. Run again, it writes the same files.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SRC = sys.argv[1].rstrip('/') + '/'
OUT = sys.argv[2].rstrip('/') + '/'

ASLEEP=np.array([[.330,.608,.062],[.181,.757,.062],[.181,.608,.211]])
def load(p): return np.asarray(Image.open(SRC+p+'.png').convert('RGB')).astype(np.float32)
def img(a): return Image.fromarray(np.clip(a+0.5,0,255).astype(np.uint8))
def asleep(a,s):
    f=a@ASLEEP.T+14.0
    return (1-s)*a+s*f
def warm_mask(a,t0=95,t1=140,blur=2.0):
    """1 where a pixel is lamp-gold (much more red than blue, and bright)."""
    r,g,b=a[...,0],a[...,1],a[...,2]
    m=np.clip((r-b-t0)/(t1-t0),0,1)*np.clip((r-150)/50,0,1)
    m=Image.fromarray((m*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m).astype(np.float32)[...,None]/255.0
def save(a,path,size=None,q=85):
    im=img(a) if not isinstance(a,Image.Image) else a
    if size: im=im.resize(size,Image.LANCZOS)
    im.save(OUT+path,'JPEG',quality=q,optimize=True,progressive=True)


# ---- Story pictures: as painted, the sleeping ones drawn toward grey ------
GREY = {
    'lastHill': None, 'sleepingVale': 0.55, 'gateLantern': 0.5,
    'stillness': 0.6, 'road': None,
    'hearthmere_asleep': 0.7, 'larkdown_asleep': 0.45,
    'silverrun_asleep': 0.6, 'highcairn_asleep': 0.3,
    'lanternhall_asleep': 0.5,
    'hearthmere_awake': None, 'larkdown_awake': None,
    'silverrun_awake': None, 'highcairn_awake': None,
    'lanternhall_awake': None,
}
os.makedirs(OUT + 'story', exist_ok=True)
for k, s in GREY.items():
    a = load('story/' + k)
    if s is not None:
        g = asleep(a, s)
        if k == 'gateLantern':
            # The one lantern keeps its flame.
            m = warm_mask(a)
            g = m * a + (1 - m) * g
        a = g
    save(a, 'story/' + k + '.jpg')

# ---- Discovery cards: scaled to the size they are shown at ---------------
os.makedirs(OUT + 'discoveries', exist_ok=True)
for f in sorted(os.listdir(SRC + 'discoveries')):
    k = f[:-4]
    save(load('discoveries/' + k), 'discoveries/' + k + '.jpg', size=(960, 747))

# ---- The camp, as painted -------------------------------------------------
os.makedirs(OUT + 'scenes', exist_ok=True)
save(load('scenes/campfire'), 'scenes/campfire.jpg', q=86)

# ---- The valley in four lights, from the one dawn painting ----------------
a=load('scenes/dawn_header'); H,W,_=a.shape
r,g,b=a[...,0],a[...,1],a[...,2]
yy=(np.arange(H)[:,None]/H)*np.ones((1,W))
xx=(np.arange(W)[None,:]/W)*np.ones((H,1))
# The sky: bright warm flat fills, joined to the top edge.
cand=(r>205)&(g>170)&(b>95)&(b<215)&(r-b>30)&(yy<0.5)
lab,n=ndimage.label(cand)
top=set(np.unique(lab[0]))-{0}
sky=np.isin(lab,list(top))
sky=ndimage.binary_fill_holes(sky)&(yy<0.5)
skyf=np.asarray(Image.fromarray((sky*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32)[...,None]/255
# The sun: the brightest disc inside the sky.
sunc=(r>248)&(g>225)&(b>120)&sky
lab2,n2=ndimage.label(sunc)
if n2:
    sizes=ndimage.sum(sunc,lab2,range(1,n2+1)); big=1+int(np.argmax(sizes))
    ys,xs=np.where(lab2==big); print('sun at',xs.mean()/W,ys.mean()/H,'px',len(xs), 'bbox',xs.min(),xs.max(),ys.min(),ys.max())
    sun=(lab2==big)
else:
    sun=np.zeros_like(sky)
sunf=np.asarray(Image.fromarray((sun*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32)[...,None]/255
lamp=warm_mask(a,t0=100,t1=135,blur=1.5)*(1-skyf)   # lit windows and lanterns on the ground
print('lamp share',float(lamp.mean()))
def grad(top,bottom,y0=0.0,y1=0.36):
    t=np.clip((yy-y0)/(y1-y0),0,1)[...,None]
    return (1-t)*np.array(top,np.float32)+t*np.array(bottom,np.float32)
def bloom(mask,color,radius,gain):
    m=Image.fromarray((mask[...,0]*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
    return (np.asarray(m).astype(np.float32)[...,None]/255)*np.array(color,np.float32)*gain
def stars(seed=7,count=150):
    rng=np.random.default_rng(seed); layer=np.zeros((H,W),np.float32)
    im=Image.new('L',(W,H),0); d=ImageDraw.Draw(im)
    made=0
    while made<count:
        x=int(rng.uniform(0,W)); y=int(rng.uniform(0,H*0.33))
        if not sky[y,x]: continue
        rad=rng.choice([0.7,0.9,1.2,1.6],p=[.4,.3,.2,.1]); v=int(rng.uniform(130,255))
        d.ellipse([x-rad,y-rad,x+rad,y+rad],fill=v); made+=1
    return np.asarray(im.filter(ImageFilter.GaussianBlur(0.5))).astype(np.float32)[...,None]/255
def variant(name):
    if name=='morning': return a
    if name=='afternoon':
        s=grad((112,176,222),(204,229,238))
        land=a*np.array([0.97,1.01,1.05],np.float32)+6
        land=lamp*(a*0.92+8)+(1-lamp)*land
        return skyf*s+(1-skyf)*land
    if name=='evening':
        s=grad((92,84,138),(252,172,112),y1=0.34)
        s=sunf*np.array([255,222,150],np.float32)+(1-sunf)*s
        land=a*np.array([0.84,0.70,0.80],np.float32)
        land=lamp*a+(1-lamp)*land
        land=land+bloom(lamp,(255,190,90),14,0.35)*(1-skyf)
        return skyf*s+(1-skyf)*land
    if name=='night':
        s=grad((13,22,50),(40,62,104),y1=0.36)
        s=s+stars()*np.array([225,232,255],np.float32)
        s=sunf*np.array([236,238,224],np.float32)+(1-sunf)*s
        halo=bloom(sunf,(170,190,230),26,0.55)
        s=s+halo
        lum=(0.3*r+0.59*g+0.11*b)[...,None]
        land=(0.55*a+0.45*lum)*np.array([0.30,0.42,0.70],np.float32)
        land=lamp*a+(1-lamp)*land
        land=land+bloom(lamp,(255,180,80),18,0.5)
        return skyf*s+(1-skyf)*land
for nme in ['morning','afternoon','evening','night']:
    save(variant(nme),'scenes/dawn_'+nme+'.jpg',q=86)
    print(nme, os.path.getsize(OUT+'scenes/dawn_'+nme+'.jpg')//1024,'KB')
