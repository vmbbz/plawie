
from PIL import Image, ImageDraw

def make_transparent(src_path, dst_path):
    img = Image.open(src_path).convert("RGBA")
    data = img.load()
    
    width, height = img.size
    
    # Flood fill white (tolerance for slightly off-white)
    # We use (0,0,0,0) as the replacement for background white
    tolerance = 10
    
    # ImageDraw.floodfill thresh parameter handles tolerance
    for x, y in [(0,0), (width-1, 0), (0, height-1), (width-1, height-1)]:
        ImageDraw.floodfill(img, (x, y), (0, 0, 0, 0), thresh=tolerance)
            
    img.save(dst_path)
    print(f"Saved transparent image to {dst_path}")

src = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\plawie_icon_foreground_white_bg_1778658919704.png'
dst = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\plawie_icon_foreground_v2_final.png'
make_transparent(src, dst)
