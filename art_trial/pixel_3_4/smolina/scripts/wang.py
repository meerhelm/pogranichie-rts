import sys
from PIL import Image
def is_green(p):
    r,g,b=p[:3]; return g>r+15 and g>b+15 and g>90   # meadow grass is bright green
def classify(path, T=32, k=5):
    im=Image.open(path).convert('RGB'); W,H=im.size
    res={}
    for ty in range(H//T):
        for tx in range(W//T):
            x0,y0=tx*T,ty*T; corners=[]
            for cx,cy in [(0,0),(T-k,0),(0,T-k),(T-k,T-k)]:  # TL TR BL BR
                px=[im.getpixel((x0+cx+i,y0+cy+j)) for i in range(k) for j in range(k)]
                frac=sum(is_green(p) for p in px)/len(px)
                corners.append(0 if frac>0.5 else 1)  # 0=outside(meadow) 1=inside
            # also center
            px=[im.getpixel((x0+T//2-3+i,y0+T//2-3+j)) for i in range(6) for j in range(6)]
            c=sum(is_green(p) for p in px)/len(px)
            res[(tx,ty)]=(tuple(corners),round(c,2))
    return res
if __name__=="__main__":
    for (tx,ty),(c,cen) in sorted(classify(sys.argv[1]).items(),key=lambda x:(x[0][1],x[0][0])):
        print(ty,tx,c,'centerGreen',cen)
