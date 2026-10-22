[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$jdkSearchRoot = 'C:\Java\temurin-21'

function Get-JavaVersionInfo {
  param([Parameter(Mandatory)][string]$JavaExe)

  # `java -version` escreve no stderr. Encaminhar por cmd.exe transforma o
  # resultado em saída normal sem o NativeCommandError do Windows PowerShell.
  $output = (& $env:ComSpec /d /c "`"$JavaExe`" -version 2>&1") -join "`n"
  $commandExitCode = $LASTEXITCODE
  $match = [regex]::Match($output, 'version\s+"?(?<major>\d+)(?:\.|"|\+|-)')

  [pscustomobject]@{
    Output   = $output
    ExitCode = $commandExitCode
    Major    = if ($match.Success) { [int]$match.Groups['major'].Value } else { $null }
  }
}

# Prefira JAVA_HOME quando apontar para um JDK 21 utilizável. Caso esteja
# ausente, inválido ou em outra versão, procure uma instalação JDK 21 no
# diretório convencional sem modificar configuração global do Windows.
$candidateRoots = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
  $candidateRoots.Add($env:JAVA_HOME.Trim().Trim('"'))
}
if (Test-Path -LiteralPath $jdkSearchRoot -PathType Container) {
  Get-ChildItem -LiteralPath $jdkSearchRoot -Directory -Filter 'jdk-21*' |
    Sort-Object Name -Descending |
    ForEach-Object { $candidateRoots.Add($_.FullName) }
}

$jdkRoot = $null
$javaExe = $null
$javaVersionInfo = $null
foreach ($candidateRoot in ($candidateRoots | Select-Object -Unique)) {
  $candidateJavaExe = Join-Path $candidateRoot 'bin\java.exe'
  if (-not (Test-Path -LiteralPath $candidateJavaExe -PathType Leaf)) {
    Write-Warning "Ignorando JAVA_HOME/JDK sem bin\java.exe: '$candidateRoot'."
    continue
  }

  $candidateVersion = Get-JavaVersionInfo -JavaExe $candidateJavaExe
  if ($candidateVersion.ExitCode -eq 0 -and $candidateVersion.Major -eq 21) {
    $jdkRoot = $candidateRoot
    $javaExe = $candidateJavaExe
    $javaVersionInfo = $candidateVersion
    break
  }

  Write-Warning "Ignorando JDK que não confirmou Java major 21: '$candidateRoot'."
  Write-Warning $candidateVersion.Output
}

if ($null -eq $javaExe) {
  throw "Não encontrei um JDK 21 válido em JAVA_HOME nem em '$jdkSearchRoot\jdk-21*'."
}

$previousJavaHome = $env:JAVA_HOME
$previousPath = $env:Path
$exitCode = 1

try {
  $env:JAVA_HOME = $jdkRoot
  $env:Path = "$(Join-Path $jdkRoot 'bin');$previousPath"

  Write-Host "JDK selecionado: $jdkRoot"
  Write-Host $javaVersionInfo.Output

  Push-Location $repoRoot
  try {
    & npm test --prefix (Join-Path $repoRoot 'tools\firestore-rules-tests')
    # Capture imediatamente: cleanup e restauração do ambiente não podem
    # sobrescrever o código real retornado pela suíte.
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }
}
finally {
  $env:JAVA_HOME = $previousJavaHome
  $env:Path = $previousPath
}

exit $exitCode
