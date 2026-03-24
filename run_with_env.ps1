# Lance l'app Flutter avec la config Supabase du fichier .env (même que l'app web)
# Utilise le .env à la racine du projet SOFCOM
#
# Usage:
#   .\run_with_env.ps1              → lance sur Chrome
#   .\run_with_env.ps1 windows      → lance sur Windows (app bureau)
#   .\run_with_env.ps1 emulator-5554 → lance sur l'émulateur Android
#   .\run_with_env.ps1 build        → génère l'APK Android (fasostock.apk)
#   .\run_with_env.ps1 build windows → génère l'exe Windows (nécessite Visual Studio avec C++)

$ErrorActionPreference = "Stop"
$envFile = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ".env"
$appDir = $PSScriptRoot

if (-not (Test-Path $envFile)) {
    Write-Host "Fichier .env introuvable: $envFile" -ForegroundColor Red
    Write-Host "Copiez .env.example vers .env et renseignez VITE_SUPABASE_URL et VITE_SUPABASE_ANON_KEY"
    exit 1
}

$url = $null
$key = $null
$deepseekKey = $null
$sentryDsn = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*VITE_SUPABASE_URL=(.+)$') { $url = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($_ -match '^\s*VITE_SUPABASE_ANON_KEY=(.+)$') { $key = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($_ -match '^\s*VITE_DEEPSEEK_API_KEY=(.+)$') { $deepseekKey = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($_ -match '^\s*VITE_SENTRY_DSN=(.+)$') { $sentryDsn = $Matches[1].Trim().Trim('"').Trim("'") }
}

if (-not $url -or -not $key) {
    Write-Host "VITE_SUPABASE_URL et VITE_SUPABASE_ANON_KEY doivent être définis dans .env" -ForegroundColor Red
    exit 1
}

Set-Location $appDir
$defineUrl = "--dart-define=SUPABASE_URL=$url"
$defineKey = "--dart-define=SUPABASE_ANON_KEY=$key"
$defineDeepseek = if ($deepseekKey) { "--dart-define=DEEPSEEK_API_KEY=$deepseekKey" } else { $null }
$defineSentry = if ($sentryDsn) { "--dart-define=SENTRY_DSN=$sentryDsn" } else { $null }

# build = construire un APK release avec la config du .env intégrée (Supabase + DeepSeek)
# build windows = construire l'exe Windows avec la config du .env
$firstArg = if ($args.Count -gt 0) { $args[0] } else { $null }
$secondArg = if ($args.Count -gt 1) { $args[1] } else { $null }

if ($firstArg -eq "build") {
    if ($secondArg -eq "windows") {
        Write-Host "Construction de l'app Windows avec la config du .env..." -ForegroundColor Cyan
        $buildArgs = @("build", "windows", $defineUrl, $defineKey)
        if ($defineDeepseek) { $buildArgs += $defineDeepseek }
        if ($defineSentry) { $buildArgs += $defineSentry }
        & flutter $buildArgs
        if ($LASTEXITCODE -eq 0) {
            $winDir = Join-Path $appDir "build\windows\x64\runner\Release"
            Write-Host "App Windows generee : $winDir" -ForegroundColor Green
            Write-Host "Lancez : $winDir\fasostock.exe" -ForegroundColor Green
        }
    } else {
        Write-Host "Construction de l'APK release avec la config du .env (Supabase + DeepSeek)..." -ForegroundColor Cyan
        $buildArgs = @("build", "apk", $defineUrl, $defineKey)
        if ($defineDeepseek) { $buildArgs += $defineDeepseek }
        if ($defineSentry) { $buildArgs += $defineSentry }
        & flutter $buildArgs
        if ($LASTEXITCODE -eq 0) {
            $apkDir = Join-Path $appDir "build\app\outputs\flutter-apk"
            $releaseApk = Join-Path $apkDir "app-release.apk"
            $fasostockApk = Join-Path $apkDir "fasostock.apk"
            Copy-Item $releaseApk $fasostockApk -Force
            Write-Host "APK genere : build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
            Write-Host "Copie pour usage reel : build\app\outputs\flutter-apk\fasostock.apk" -ForegroundColor Green
        }
    }
    exit $LASTEXITCODE
}

# windows = lancer l'app sur Windows (avec config .env)
# Device: premier argument ou "chrome" par défaut (ex: .\run_with_env.ps1 emulator-5554)
$device = if ($firstArg -eq "windows") { "windows" } elseif ($firstArg) { $firstArg } else { "chrome" }
$runArgs = @("run", "-d", $device, $defineUrl, $defineKey)
if ($defineDeepseek) { $runArgs += $defineDeepseek }
if ($defineSentry) { $runArgs += $defineSentry }
& flutter $runArgs
