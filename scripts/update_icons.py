
import os
from PIL import Image

# Paths
foreground_src = r'c:\dev-shared\openclaw-projects\openclaw_final\assets\ic_launcher_foreground_padded.png'
background_src = r'C:\Users\cosyc\.gemini\antigravity\brain\703741e9-f25d-4437-85e4-c53d4eff4ba4\dark_emerald_obsidian_background_1778673224237.png'
res_dir = r'c:\dev-shared\openclaw-projects\openclaw_final\android\app\src\main\res'
assets_dir = r'c:\dev-shared\openclaw-projects\openclaw_final\assets'

sizes = {
    'mipmap-xxxhdpi': 432,
    'mipmap-xxhdpi': 324,
    'mipmap-xhdpi': 216,
    'mipmap-hdpi': 162,
    'mipmap-mdpi': 108
}

def process_image(src, filename):
    img = Image.open(src)
    for folder, size in sizes.items():
        target_path = os.path.join(res_dir, folder, filename)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        # Use high-quality resampling
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target_path)
        print(f"Saved {target_path}")

# Process both adaptive layers
process_image(foreground_src, 'ic_launcher_foreground.png')
process_image(background_src, 'ic_launcher_background.png')

# Process flattened legacy icon
def process_flattened():
    bg = Image.open(background_src).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    fg = Image.open(foreground_src).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    # Composite
    flattened = Image.alpha_composite(bg, fg)
    for folder, size in sizes.items():
        # Legacy icons are smaller (48dp base, xxxhdpi is 192x192)
        # But for simplicity we use the same size logic as adaptive if we want it crisp
        # Actually legacy size is usually 192 for xxxhdpi
        legacy_size = int(size * 192 / 432) 
        target_path = os.path.join(res_dir, folder, 'ic_launcher.png')
        resized = flattened.resize((legacy_size, legacy_size), Image.Resampling.LANCZOS)
        resized.save(target_path)
        print(f"Saved legacy {target_path}")

process_flattened()

# Update assets directory
def update_assets():
    # 1. ic_launcher.png (Flattened)
    bg = Image.open(background_src).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    fg = Image.open(foreground_src).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    flattened = Image.alpha_composite(bg, fg)
    # Use a large size for assets (1024x1024)
    flattened.resize((1024, 1024), Image.Resampling.LANCZOS).save(os.path.join(assets_dir, 'ic_launcher.png'))
    print(f"Updated {assets_dir}/ic_launcher.png")
    
    # 2. ic_launcher_foreground_padded.png (Foreground only)
    # We DO NOT overwrite this as it is now our master source cleaned by the user.
    print(f"Skipping update of {assets_dir}/ic_launcher_foreground_padded.png (Master Source)")

update_assets()

print("All icon assets updated successfully.")
