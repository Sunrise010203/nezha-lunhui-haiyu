from PIL import Image
import numpy as np
outs=[]
for n in ["cu_before","cu_after"]:
    im=Image.open("E:/godot_game_by_fable/art_tmp/shots/%s.png"%n).convert("RGB")
    a=np.asarray(im)
    # 找角色：红色像素质心
    red=(a[:,:,0].astype(int)>120)&(a[:,:,0].astype(int)-a[:,:,2].astype(int)>50)
    ys,xs=np.nonzero(red)
    print(n,"red px",len(xs),"bbox",xs.min(),xs.max(),ys.min(),ys.max())
    cx,cy=int(xs.mean()),int(ys.mean())
    box=(cx-260,cy-300,cx+200,cy+320)
    outs.append(im.crop(box))
w,h=outs[0].size
sheet=Image.new("RGB",(w*2+10,h),(10,10,10))
sheet.paste(outs[0],(0,0)); sheet.paste(outs[1],(w+10,0))
sheet=sheet.resize((int(sheet.width*1.6),int(sheet.height*1.6)),Image.LANCZOS)
sheet.save("E:/godot_game_by_fable/art_tmp/shots/cu_cmp.png")
print("ok",sheet.size)