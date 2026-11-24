# Dump the DOM that Edge renders for the figure URL (same page, same input as capture.ps1). Run from the archive root.
param([string]$Out = 'figures/fig1_dom.html', [string]$InputId = 'metadat::dat.lehmann2018')
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$url = & node figures/make_url.cjs app/fixed corpus $InputId
$root = (Resolve-Path '.').Path
$prof = Join-Path $root '.edge-profile'
$outAbs = Join-Path $root $Out
$p = Start-Process -FilePath $edge -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outAbs -RedirectStandardError (Join-Path $root 'figures/dump_dom.err') `
  -ArgumentList '--headless=new', '--disable-gpu', '--no-first-run', "--user-data-dir=`"$prof`"", '--virtual-time-budget=8000', '--dump-dom', "`"$url`""
"dumped $Out ($((Get-Item $outAbs).Length) bytes), exit $($p.ExitCode)"
