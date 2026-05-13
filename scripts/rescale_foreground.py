
from PIL import Image

def rescale_foreground(src_path, dst_path, target_size=650):
    fg = Image.open(src_path).convert("RGBA")
    # Original is 1024x1024
    
    # Scale down the character
    # We maintain aspect ratio (it's 1:1 anyway)
    fg_resized = fg.resize((target_size, target_size), Image.Resampling.LANCZOS)
    
    # Create a new transparent 1024x1024 canvas
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    
    # Center the resized foreground on the canvas
    offset = ((1024 - target_size) // 2, (1024 - target_size) // 2)
    canvas.paste(fg_resized, offset, fg_resized)
    
    canvas.save(dst_path)
    print(f"Saved rescaled foreground to {dst_path}")

src = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\plawie_icon_foreground_v2_ultra_clean.png'
dst = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\plawie_icon_foreground_v2_rescaled.png'
rescale_foreground(src, dst)
