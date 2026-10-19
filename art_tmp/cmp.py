
from PIL import Image
a=Image.open(r"E:\godot_game_by_fable\art_tmp\shots\final_cu.png").convert("RGB")
b=Image.open(r"E:\godot_game_by_fable\art_tmp\preview\v2_front.png").convert("RGB")
c=Image.open(r"E:\godot_game_by_fable\art_tmp\preview\v2_q34.png").convert("RGB")
h=760
def fit(im):
    w=int(im.width*h/im.height); return im.resize((w,h), Image.LANCZOS)
ims=[fit(x) for x in (a,b,c)]
W=sum(i.width for i in ims)+20
out=Image.new("RGB",(W,h),(20,22,26)); x=0
for i in ims:
    out.paste(i,(x,0)); x+=i.width+10
out.save(r"E:\godot_game_by_fable\art_tmp\preview\compare_v2.png")
print("ok", out.size)
