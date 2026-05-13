
from PIL import Image, ImageDraw, ImageFilter

def make_transparent_advanced(src_path, dst_path):
    img = Image.open(src_path).convert("RGBA")
    width, height = img.size
    
    # 1. Create a coarse mask via flood fill from corners
    # This identifies the "exterior" white space
    mask = Image.new('L', (width, height), 0)
    draw = ImageDraw.Draw(mask)
    
    # We use a temp image to flood fill the background
    temp_img = img.copy()
    # Replace background with a unique color (e.g. green) to find it
    unique_bg = (0, 255, 0, 255)
    for x, y in [(0,0), (width-1, 0), (0, height-1), (width-1, height-1)]:
        ImageDraw.floodfill(temp_img, (x, y), unique_bg, thresh=30)
    
    # Extract mask from temp_img where color is unique_bg
    temp_data = temp_img.getdata()
    mask_data = []
    for item in temp_data:
        if item == unique_bg:
            mask_data.append(255) # background
        else:
            mask_data.append(0) # foreground
    mask.putdata(mask_data)
    
    # 2. Refine the mask (expand it slightly to catch hair edges)
    # We blur it to create a soft edge
    refined_mask = mask.filter(ImageFilter.GaussianBlur(radius=1))
    
    # 3. Apply transparency based on mask and color
    # Any pixel that is highly white AND in the background mask becomes transparent
    data = img.getdata()
    newData = []
    refined_mask_data = refined_mask.getdata()
    
    for i, item in enumerate(data):
        m = refined_mask_data[i]
        if m > 0: # If it's part of the background or edge
            # Calculate how "white" it is
            brightness = (item[0] + item[1] + item[2]) / 3
            if brightness > 200:
                # Interpolate alpha based on brightness and mask strength
                # Pixels that are whiter get more transparent
                alpha = int(255 - (brightness - 200) * (255/55) * (m/255))
                alpha = max(0, min(255, alpha))
                # For background proper (m=255 and white), force 0
                if m == 255 and brightness > 240:
                    alpha = 0
                newData.append((item[0], item[1], item[2], alpha))
            else:
                newData.append(item)
        else:
            newData.append(item)
            
    img.putdata(newData)
    img.save(dst_path)
    print(f"Saved advanced transparent image to {dst_path}")

src = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\plawie_icon_foreground_white_bg_1778658919704.png'
dst = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\plawie_icon_foreground_v2_ultra_clean.png'
make_transparent_advanced(src, dst)
