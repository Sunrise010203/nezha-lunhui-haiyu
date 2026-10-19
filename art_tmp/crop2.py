from PIL import Image
box=(520,330,780,700)
im=Image.open("E:/godot_game_by_fable/art_tmp/shots/after2.png").convert("RGB").crop(box)
im=im.resize((im.width*3,im.height*3),Image.LANCZOS)
im.save("E:/godot_game_by_fable/art_tmp/shots/after2_crop.png")
print("ok")