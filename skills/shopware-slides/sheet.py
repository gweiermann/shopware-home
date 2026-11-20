import glob, sys
from PIL import Image
fs = sorted(glob.glob(sys.argv[1] + '/*.png')); w, h, cols = 800, 450, 3
rows = (len(fs) + cols - 1) // cols
sheet = Image.new('RGB', (cols * w, rows * h), 'gray')
for i, f in enumerate(fs):
    sheet.paste(Image.open(f).convert('RGB').resize((w - 6, h - 6)), ((i % cols) * w + 3, (i // cols) * h + 3))
sheet.save(sys.argv[2])
