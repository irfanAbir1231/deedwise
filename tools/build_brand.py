"""Generate the same original D/check vector mark for Flutter, Android and web.

No generated AI bitmap: all geometry is owned, editable and deterministic.
Run with Python + Pillow. PNGs are supersampled from the canonical vector paths.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GREEN, CREAM, GOLD = '#234E40', '#FFFCF4', '#DBB96F'
PATHS = [
    (CREAM, 14, [('M', 72, 62), ('L', 119, 62),
      ('C', 164, 62, 192, 89, 192, 128),
      ('C', 192, 167, 164, 194, 119, 194), ('L', 72, 194), ('L', 72, 62)]),
    (GOLD, 16, [('M', 84, 125), ('L', 109, 150), ('L', 153, 105)]),
]

def path_string(commands):
    return ' '.join(c[0] + ' ' + ' '.join(map(str, c[1:])) for c in commands)

def samples(commands):
    points = []
    for command, *v in commands:
        if command in ('M', 'L'):
            points.append(tuple(v))
        else:
            p0 = points[-1]
            for i in range(1, 81):
                t, u = i / 80, 1 - i / 80
                points.append((u**3*p0[0] + 3*u*u*t*v[0] + 3*u*t*t*v[2] + t**3*v[4],
                               u**3*p0[1] + 3*u*u*t*v[1] + 3*u*t*t*v[3] + t**3*v[5]))
    return points

def render(size):
    scale = size * 4 / 256
    image = Image.new('RGBA', (size*4, size*4))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, size*4-1, size*4-1), radius=60*scale, fill=GREEN)
    for color, width, commands in PATHS:
        points = [(x*scale, y*scale) for x, y in samples(commands)]
        draw.line(points, fill=color, width=round(width*scale), joint='curve')
        for x, y in points:
            r = width*scale/2
            draw.ellipse((x-r, y-r, x+r, y+r), fill=color)
    return image.resize((size, size), Image.Resampling.LANCZOS)

brand = ROOT/'assets/brand'
brand.mkdir(parents=True, exist_ok=True)
svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><title>DeedWise</title><rect width="256" height="256" rx="60" fill="'+GREEN+'"/>'
for color, width, commands in PATHS:
    svg += f'<path d="{path_string(commands)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'
svg += '</svg>\n'
(brand/'deedwise-mark.svg').write_text(svg, encoding='utf-8')
render(512).save(brand/'deedwise-mark.png')
res = ROOT/'android/app/src/main/res'
vector = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="256" android:viewportHeight="256">\n'
vector += f'<path android:fillColor="{GREEN}" android:pathData="M60,0 H196 Q256,0 256,60 V196 Q256,256 196,256 H60 Q0,256 0,196 V60 Q0,0 60,0 Z"/>\n'
for color, width, commands in PATHS:
    vector += f'<path android:pathData="{path_string(commands)}" android:fillColor="@android:color/transparent" android:strokeColor="{color}" android:strokeWidth="{width}" android:strokeLineCap="round" android:strokeLineJoin="round"/>\n'
vector += '</vector>\n'
(res/'drawable/deedwise_logo.xml').write_text(vector, encoding='utf-8')
for folder, size in [('mdpi',48), ('hdpi',72), ('xhdpi',96), ('xxhdpi',144), ('xxxhdpi',192)]:
    render(size).save(res/f'mipmap-{folder}/ic_launcher.png')
adaptive = res/'mipmap-anydpi-v26'
adaptive.mkdir(exist_ok=True)
(adaptive/'ic_launcher.xml').write_text('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/brand_green"/><foreground android:drawable="@drawable/deedwise_logo"/></adaptive-icon>\n')
(res/'values/brand_colors.xml').write_text(f'<resources><color name="brand_green">{GREEN}</color><color name="brand_cream">{CREAM}</color></resources>\n')
render(32).save(ROOT/'web/favicon.png')
for size in (192,512):
    for name in ('Icon', 'Icon-maskable'):
        render(size).save(ROOT/f'web/icons/{name}-{size}.png')
(ROOT/'web/deedwise-mark.svg').write_text(svg, encoding='utf-8')

launch = '<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:drawable="@color/brand_cream"/><item android:gravity="center" android:width="108dp" android:height="108dp" android:drawable="@drawable/deedwise_logo"/></layer-list>\n'
for folder in ('drawable','drawable-v21'):
    (res/folder/'launch_background.xml').write_text(launch)
for folder in ('values','values-night','values-v31','values-night-v31'):
    (res/folder).mkdir(exist_ok=True)
    extra = '' if 'v31' not in folder else '<item name="android:windowSplashScreenBackground">@color/brand_cream</item><item name="android:windowSplashScreenAnimatedIcon">@drawable/deedwise_logo</item><item name="android:windowSplashScreenIconBackgroundColor">@color/brand_cream</item>'
    styles = '<resources><style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowBackground">@drawable/launch_background</item><item name="android:statusBarColor">@color/brand_cream</item><item name="android:navigationBarColor">@color/brand_cream</item><item name="android:windowLightStatusBar">true</item>'+extra+'</style><style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowBackground">@color/brand_cream</item><item name="android:statusBarColor">@color/brand_cream</item><item name="android:navigationBarColor">@color/brand_cream</item><item name="android:windowLightStatusBar">true</item></style></resources>\n'
    (res/folder/'styles.xml').write_text(styles)
print('Generated DeedWise vector, Flutter mark, Android launch/launcher assets and web icons.')
