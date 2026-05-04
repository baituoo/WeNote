# Custom Fonts

Drop `.ttf` files here, then uncomment the `fonts:` section in `pubspec.yaml`.

## Recommended: Noto Sans SC

Noto Sans SC (Simplified Chinese) covers Latin + CJK with consistent weight
rendering, eliminating the Chinese/English weight mismatch on Windows.

### Quick download (PowerShell)

```powershell
# Run this from the project root:
mkdir fonts -Force
$urls = @(
  @{Url='https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'; Name='NotoSansSC[wght].ttf'}
)
foreach ($f in $urls) {
  Invoke-WebRequest -Uri $f.Url -OutFile "fonts\$($f.Name)"
}
```

Note: Noto Sans SC is a variable font (~12 MB) and covers weights 100-900
in a single file.

### After downloading

1. Uncomment the `fonts:` block in `pubspec.yaml`
2. Change `_fontFamily` in `lib/theme/app_theme.dart` to `'NotoSansSC'`
3. Run `flutter pub get` and restart

## Fallback (built-in)

Without custom fonts, the app uses **Microsoft YaHei** (微软雅黑) which is
pre-installed on all Windows 10/11 systems. It provides:
- Full CJK character coverage
- Good Latin/English glyphs
- Consistent weight rendering across scripts
