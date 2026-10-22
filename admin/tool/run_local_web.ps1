param()

$debugToken = [Environment]::GetEnvironmentVariable('COMPY_APPCHECK_DEBUG_TOKEN', 'Process')
if ([string]::IsNullOrWhiteSpace($debugToken)) {
  throw 'Defina COMPY_APPCHECK_DEBUG_TOKEN externamente. Use "generate" uma vez para emitir um token local.'
}
$siteKey = [Environment]::GetEnvironmentVariable('COMPY_RECAPTCHA_V3_SITE_KEY', 'Process')
if ([string]::IsNullOrWhiteSpace($siteKey)) {
  throw 'Defina COMPY_RECAPTCHA_V3_SITE_KEY externamente com a site key pública reCAPTCHA v3 do App Check.'
}

$adminRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$exitCode = 0
Push-Location $adminRoot
try {
  & flutter run -d chrome "--dart-define=COMPY_RECAPTCHA_V3_SITE_KEY=$siteKey" "--dart-define=COMPY_APPCHECK_DEBUG_TOKEN=$debugToken"
  $exitCode = $LASTEXITCODE
}
finally {
  Pop-Location
}

exit $exitCode
