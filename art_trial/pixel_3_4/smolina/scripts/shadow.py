import sys
from PIL import Image, ImageDraw
O=sys.argv[1]
SAND={(0xd6,0xc3,0x8c),(0xe6,0xd6,0xa4),(0xc4,0xa6,0x79),(0xa8,0x86,0x5a)}
for kind,n in (("pine",3),("birch",2)):
    for k in range(1,n+1):
        im=Image.open(f"{O}/tree_{kind}_{k}.png").convert("RGBA"); W,H=im.size
        # drop ground blobs (sand-coloured pixels) in the bottom rows
        for y in range(H-10,H):
            for x in range(W):
                p=im.getpixel((x,y))
                if p[3] and p[:3] in SAND: im.putpixel((x,y),(0,0,0,0))
        bb=im.getbbox()
        # trunk foot: lowest opaque row, its mean x
        fy=bb[3]-1; xs=[x for x in range(W) if im.getpixel((x,fy))[3]]
        fx=sum(xs)//len(xs)
        sh=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(sh)
        d.ellipse((fx-3,fy-4,min(W-1,fx+20),fy+1),fill=(20,24,12,110))
        out=Image.alpha_composite(sh,im)
        out.save(f"{O}/tree_{kind}_shadow_{k}.png")
        print(kind,k,"foot",fx,fy)
