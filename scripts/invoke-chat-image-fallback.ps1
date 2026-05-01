param(
  [string]$ApiKey,
  [string]$BaseUrl,
  [string]$Model = "gpt-image-2",
  [string]$Endpoint = "chat/completions",
  [Parameter(Mandatory = $true)]
  [string]$Prompt,
  [string]$Out = ".\output\imagegen\chat-image-fallback.png",
  [int]$TimeoutSec = 300
)

$ErrorActionPreference = "Stop"

if (-not $ApiKey) { $ApiKey = $env:OPENAI_API_KEY }
if (-not $ApiKey) { $ApiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
if (-not $ApiKey) { $ApiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Machine") }
if (-not $ApiKey) { throw "OPENAI_API_KEY is not set. Set it in the environment or pass -ApiKey." }

if (-not $BaseUrl) { $BaseUrl = $env:OPENAI_BASE_URL }
if (-not $BaseUrl) { $BaseUrl = [Environment]::GetEnvironmentVariable("OPENAI_BASE_URL", "User") }
if (-not $BaseUrl) { $BaseUrl = [Environment]::GetEnvironmentVariable("OPENAI_BASE_URL", "Machine") }
if (-not $BaseUrl) { throw "OPENAI_BASE_URL is not set. Pass -BaseUrl or set it in the environment." }

function Join-ApiUri {
  param(
    [string]$Base,
    [string]$Path
  )

  if ($Path -match "^https?://") {
    return $Path
  }

  $baseTrimmed = $Base.TrimEnd("/")
  $pathTrimmed = $Path.TrimStart("/")

  if ($pathTrimmed.StartsWith("v1/") -and $baseTrimmed.EndsWith("/v1")) {
    $pathTrimmed = $pathTrimmed.Substring(3)
  }

  return "$baseTrimmed/$pathTrimmed"
}

$outPath = [IO.Path]::GetFullPath($Out)
$outDir = Split-Path -Parent $outPath
if ($outDir) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$uri = Join-ApiUri -Base $BaseUrl -Path $Endpoint

$bodyObject = @{
  model = $Model
  messages = @(
    @{
      role = "user"
      content = $Prompt
    }
  )
}
$body = $bodyObject | ConvertTo-Json -Depth 10

$headers = @{
  Authorization = "Bearer $ApiKey"
  "Content-Type" = "application/json"
}

function Get-ErrorResponseText {
  param(
    [Parameter(Mandatory = $true)]
    $ErrorRecord
  )

  $message = $ErrorRecord.Exception.Message

  try {
    $response = $ErrorRecord.Exception.Response
    if (-not $response) {
      return $message
    }

    $stream = $response.GetResponseStream()
    if (-not $stream) {
      return $message
    }

    $reader = New-Object IO.StreamReader($stream)
    $body = $reader.ReadToEnd()
    if ($body) {
      return $body
    }
  } catch {
  }

  return $message
}

Write-Host "Calling $uri with model $Model ..."
try {
  $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -TimeoutSec $TimeoutSec
} catch {
  $errorText = Get-ErrorResponseText -ErrorRecord $_

  if ($errorText -match 'model_not_found' -and $errorText -match 'under group vip_2') {
    throw "Relay returned model_not_found under group vip_2. This usually means the current API key is on a text-oriented channel, not that the model name is wrong. Try a separate image key or image channel for image models. Raw error: $errorText"
  }

  throw "Request failed. Raw error: $errorText"
}

$stem = [IO.Path]::Combine($outDir, [IO.Path]::GetFileNameWithoutExtension($outPath))
$jsonPath = "$stem-response.json"
$contentPath = "$stem-content.txt"

$responseJson = $response | ConvertTo-Json -Depth 50
$responseJson | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$content = ""
try {
  $content = [string]$response.choices[0].message.content
} catch {
  $content = ""
}
$content | Set-Content -LiteralPath $contentPath -Encoding UTF8

$saved = $false
$dataUriPattern = 'data:image/(?<ext>png|jpeg|jpg|webp);base64,(?<b64>[A-Za-z0-9+/=\r\n]+)'
$urlPattern = '(?<url>https?://[^\s\)\]''"<>]+\.(png|jpg|jpeg|webp)(\?[^\s\)\]''"<>]+)?)'
$b64JsonPattern = '"b64_json"\s*:\s*"(?<b64>[A-Za-z0-9+/=\r\n]+)"'

if ($responseJson -match $dataUriPattern) {
  $bytes = [Convert]::FromBase64String(($Matches.b64 -replace "\s", ""))
  [IO.File]::WriteAllBytes($outPath, $bytes)
  $saved = $true
} elseif ($responseJson -match $b64JsonPattern) {
  $bytes = [Convert]::FromBase64String(($Matches.b64 -replace "\s", ""))
  [IO.File]::WriteAllBytes($outPath, $bytes)
  $saved = $true
} elseif ($responseJson -match $urlPattern) {
  Invoke-WebRequest -Uri $Matches.url -OutFile $outPath -TimeoutSec $TimeoutSec | Out-Null
  $saved = $true
}

if ($saved) {
  Write-Host "Saved image: $outPath"
  Write-Host "Saved raw response: $jsonPath"
  Write-Host "Saved message content: $contentPath"
} else {
  Write-Host "No direct image was parsed."
  Write-Host "Saved raw response: $jsonPath"
  Write-Host "Saved message content: $contentPath"
  exit 2
}
