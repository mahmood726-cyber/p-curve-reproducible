# Figure capture: Microsoft Edge headless screenshot of the archived fixed page with the worked example
# (metadat dat.lehmann2018, z family) restored via the page's own url-state hash. Run from the archive root.
param([string]$Out = 'figures/fig1_raw.png', [string]$InputId ='metadat::dat.lehmann2018', [int]$Width = 1280, [int]$Height = 1500)
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$url = & node figures/make_url.cjs app/fixed corpus $InputId
$prof = Join-Path (Resolve-Path '.').Path '.edge-profile'
$outAbs = Join-Path (Resolve-Path '.').Path $Out
& $edge --headless=new --disable-gpu --no-first-run --no-default-browser-check --user-data-dir="$prof" `
  --hide-scrollbars --force-device-scale-factor=2.5 --window-size="$Width,$Height" --virtual-time-budget=8000 `
  --force-color-profile=srgb --blink-settings=preferredColorScheme=1 --screenshot="$outAbs" "$url" | Out-Null
Start-Sleep -Seconds 2
if (Test-Path $outAbs) { "captured $Out ($((Get-Item $outAbs).Length) bytes); Edge $((Get-Item $edge).VersionInfo.ProductVersion)" } else { "CAPTURE FAILED" ; exit 1 }
