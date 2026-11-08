import os
from PIL import Image

def slice_wow_map(input_path, output_dir, prefix, floor=1, bottom_crop_px=0):
    try:
        img = Image.open(input_path)
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    # 1. Crop the bottom banner
    width, height = img.size
    if bottom_crop_px > 0:
        crop_box = (0, 0, width, height - bottom_crop_px)
        img = img.crop(crop_box)
        print(f"Cropped {bottom_crop_px} pixels from the bottom.")

    img = img.convert("RGB")

    # 2. Resize to WoW's exact map content area (1002x668)
    img = img.resize((1002, 668), Image.Resampling.LANCZOS)
    print("Resized map content to 1002x668.")

    # 3. Create the 1024x768 padded canvas (black background)
    canvas = Image.new("RGB", (1024, 768), (0, 0, 0))
    canvas.paste(img, (0, 0))

    # 4. Create the specific dungeon subfolder (e.g., Textures/Dungeons/CityOfDalaran)
    dungeon_dir = os.path.join(output_dir, prefix)
    os.makedirs(dungeon_dir, exist_ok=True)

    # 5. Slice into a 4x3 grid of 256x256 tiles
    tile_number = 1
    for row in range(3):
        for col in range(4):
            left = col * 256
            top = row * 256
            right = left + 256
            bottom = top + 256
            
            tile = canvas.crop((left, top, right, bottom))
            
            # New Format: 1_1.tga
            file_name = f"{floor}_{tile_number}.tga"
            save_path = os.path.join(dungeon_dir, file_name)
            
            tile.save(save_path, format="TGA")
            print(f"Saved {file_name}")
            
            tile_number += 1

    print(f"\nSuccess! 12 tiles saved to {dungeon_dir}")

# ==========================================
# Script Execution
# ==========================================
if __name__ == "__main__":
    INPUT_IMAGE = "santiago-reyes-dalaran-f.webp"
    MAP_PREFIX = "CityOfDalaran"  # This becomes the folder name!
    
    # Base output folder
    OUTPUT_FOLDER = "Dungeons"
    
    BANNER_HEIGHT_PIXELS = 145 

    slice_wow_map(INPUT_IMAGE, OUTPUT_FOLDER, MAP_PREFIX, floor=1, bottom_crop_px=BANNER_HEIGHT_PIXELS)