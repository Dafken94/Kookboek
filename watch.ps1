# Kookboek — automatische git push bij elke bestandswijziging
$folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$debounce = $null

Write-Host "Kookboek watcher gestart. Wijzigingen worden automatisch gepusht naar GitHub." -ForegroundColor Green
Write-Host "Map: $folder" -ForegroundColor Cyan
Write-Host "Druk Ctrl+C om te stoppen.`n" -ForegroundColor Yellow

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path   = $folder
$watcher.Filter = "*.html"
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite

$action = {
    $file = $Event.SourceEventArgs.Name
    if ($debounce) { $debounce.Dispose() }
    $debounce = [System.Threading.Timer]::new({
        $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        Write-Host "[$timestamp] Wijziging in $file — pushen naar GitHub..." -ForegroundColor Cyan
        Push-Location $folder
        git add index.html 2>&1 | Out-Null
        $status = git status --short 2>&1
        if ($status) {
            git commit -m "Auto-update: $timestamp" 2>&1 | Out-Null
            $result = git push 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Gepusht!" -ForegroundColor Green
            } else {
                Write-Host "  Push mislukt: $result" -ForegroundColor Red
            }
        } else {
            Write-Host "  Geen wijzigingen om te committen." -ForegroundColor DarkGray
        }
        Pop-Location
    }, $null, 1500, [System.Threading.Timeout]::Infinite)
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
$watcher.EnableRaisingEvents = $true

try { while ($true) { Start-Sleep -Seconds 1 } }
finally { $watcher.Dispose(); Write-Host "Watcher gestopt." -ForegroundColor Yellow }
