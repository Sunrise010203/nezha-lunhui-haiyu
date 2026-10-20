from PIL import Image
import os
HERE=r"E:\godot_game_by_fable\art_refs"
files=[("ch1","ch1_corridor_20261020_130544_0.png"),("ch2","ch2_prison_20261020_130649_0.png"),("ch3","ch3_void_20261020_130658_0.png"),("ch4","ch4_hall_20261020_130705_0.png")]
for k,f in files:
    im=Image.open(os.path.join(HERE,f)).convert("RGB").resize((256,144))
    q=im.quantize(colors=12, method=Image.MEDIANCUT)
    pal=q.getpalette()
    counts=sorted(q.getcolors(), reverse=True)
    total=sum(c for c,_ in counts)
    lum=sum(0.299*r+0.587*g+0.114*b for r,g,b in im.getdata())/(256*144)
    print(k, "mean_lum=%.3f"%lum)
    for c,i in counts[:5]:
        r,g,b=pal[i*3:i*3+3]
        print("   #%02X%02X%02X  %5.1f%%"%(r,g,b,100*c/total))
