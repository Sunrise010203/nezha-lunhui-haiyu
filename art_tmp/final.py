from PIL import Image
import numpy as np
D="E:/godot_game_by_fable/art_tmp/shots/"
def far(n): return Image.open(D+n+".png").convert("RGB").crop((520,330,780,700)).resize((380,540),Image.LANCZOS)
def cu(n):
    im=Image.open(D+n+".png").convert("RGB"); a=np.asarray(im)
    red=(a[:,:,0].astype(int)>150)&(a[:,:,0].astype(int)-a[:,:,2].astype(int)>80)
    red[:300,:]=False; red[1050:,:]=False; red[:,:200]=False; red[:,1800:]=False
    ys,xs=np.nonzero(red); cx,cy=int(np.median(xs)),int(np.median(ys))
    x0=max(0,min(im.width-420,cx-210)); y0=max(0,min(im.height-540,cy-330))
    return im.crop((x0,y0,x0+420,y0+540))
g=8
sheet=Image.new("RGB",(380*2+420+g*2,540),(8,8,8))
sheet.paste(far("before"),(0,0)); sheet.paste(far("final_far"),(388,0)); sheet.paste(cu("final_cu"),(776,0))
sheet.save(D+"final_compare.png"); print("ok",sheet.size)