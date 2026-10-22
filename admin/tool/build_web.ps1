param()

$siteKey = [Environment]::GetEnvironmentVariable('COMPY_RECAPTCHA_V3_SITE_KEY', 'Process')
if ([string]::IsNullOrWhiteSpace($siteKey)) {
  throw 'Defina COMPY_RECAPTCHA_V3_SITE_KEY externamente com a site key pública reCAPTCHA v3 do App Check.'
}

$debugToken = [Environment]::GetEnvironmentVariable('COMPY_APPCHECK_DEBUG_TOKEN', 'Process')
if (-not [string]::IsNullOrWhiteSpace($debugToken)) {
  throw 'Remova COMPY_APPCHECK_DEBUG_TOKEN do ambiente antes do build de release.'
}

$adminRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$exitCode = 0
Push-Location $adminRoot
try {
  & flutter build web --release "--dart-define=COMPY_RECAPTCHA_V3_SITE_KEY=$siteKey"
  $exitCode = $LASTEXITCODE
  if ($exitCode -eq 0) {
    $placesSource = Join-Path $adminRoot 'web/places'
    if (Test-Path $placesSource) {
      $placesOutput = Join-Path $adminRoot 'build/web/places'
      New-Item -ItemType Directory -Path $placesOutput -Force | Out-Null
      Copy-Item -Path (Join-Path $placesSource '*') -Destination $placesOutput -Recurse -Force
    }

    $buildRoot = Join-Path $adminRoot 'build/web'
    $releaseId = (Get-FileHash -Algorithm SHA256 (Join-Path $buildRoot 'main.dart.js')).Hash.Substring(0, 12).ToLowerInvariant()
    $utf8 = [System.Text.UTF8Encoding]::new($false)

    $indexPath = Join-Path $buildRoot 'index.html'
    $index = [System.IO.File]::ReadAllText($indexPath)
    if (-not $index.Contains('flutter_bootstrap.js"')) {
      throw 'O index.html do Flutter não contém a referência esperada ao bootstrap.'
    }
    $index = $index.Replace('flutter_bootstrap.js"', "flutter_bootstrap.js?release=$releaseId`"")
    [System.IO.File]::WriteAllText($indexPath, $index, $utf8)

    $bootstrapPath = Join-Path $buildRoot 'flutter_bootstrap.js'
    $bootstrap = [System.IO.File]::ReadAllText($bootstrapPath)
    if (-not $bootstrap.Contains('"mainJsPath":"main.dart.js"')) {
      throw 'O bootstrap do Flutter não contém a referência esperada ao aplicativo.'
    }
    $bootstrap = $bootstrap.Replace('"mainJsPath":"main.dart.js"', "`"mainJsPath`":`"main.dart.js?release=$releaseId`"")
    [System.IO.File]::WriteAllText($bootstrapPath, $bootstrap, $utf8)
  }
}
finally {
  Pop-Location
}

exit $exitCode
