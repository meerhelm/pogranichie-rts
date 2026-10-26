import sys, glob
from PIL import Image, ImageDraw
out, fs = sys.argv[1], sys.argv[2:]
cw,ch=200,220; cols=6
rows=(len(fs)+cols-1)//cols
sh=Image.new('RGB',(cols*cw,rows*ch),(200,200,190)); d=ImageDraw.Draw(sh)
for i,f in enumerate(fs):
  im=Image.open(f).convert('RGBA'); s=max(1,min(190//im.width,195//im.height)); im=im.resize((im.width*s,im.height*s),Image.NEAREST)
  x,y=(i%cols)*cw,(i//cols)*ch; sh.paste(im,(x+5,y+5),im); d.text((x+3,y+205),f.split('/')[-1][:-4],fill=(0,0,0))
sh.save(out)
