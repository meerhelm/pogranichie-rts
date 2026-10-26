import random, sys
from PIL import Image
O=sys.argv[1]; N=256
h=lambda s: tuple(int(s[i:i+2],16) for i in (0,2,4))
base,deep,mid,light=h("25555c"),h("1d3c46"),h("2f6c6a"),h("4a8a80")
r=random.Random(11)
im=Image.new('RGB',(N,N),base)
# low-frequency blotches of deep/base for depth variation (wrapping)
for _ in range(900):
    cx,cy,rad=r.randrange(N),r.randrange(N),r.randint(3,7)
    for dx in range(-rad,rad+1):
        for dy in range(-rad//2,rad//2+1):
            if dx*dx/(rad*rad)+dy*dy*4/(rad*rad)<=1 and r.random()<0.85:
                im.putpixel(((cx+dx)%N,(cy+dy)%N),deep)
# ripple dashes
for _ in range(1100):
    x,y,l=r.randrange(N),r.randrange(N),r.randint(2,5)
    for i in range(l): im.putpixel(((x+i)%N,y),mid)
for _ in range(200):
    x,y,l=r.randrange(N),r.randrange(N),r.randint(1,3)
    for i in range(l): im.putpixel(((x+i)%N,y),light)
im.save(O+"/fill_water_proc256.png")
im.crop((0,0,32,32)).save(O+"/fill_water_proc32.png")
t=Image.new('RGB',(N*2,N*2))
for i in range(2):
    for j in range(2): t.paste(im,(i*N,j*N))
t.resize((N*2*4,N*2*4),Image.NEAREST).save(sys.argv[2])
