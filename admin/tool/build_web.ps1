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
}
finally {
  Pop-Location
}

exit $exitCode
