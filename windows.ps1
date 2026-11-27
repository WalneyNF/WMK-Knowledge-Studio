param([switch]$Setup, [switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:UV_PYTHON_PREFERENCE = 'only-managed'
function Check($name) { if (!(Get-Command $name -ErrorAction SilentlyContinue)) { throw "Dependencia ausente: $name. Consulte WMK-WINDOWS.md." } }
function Run($exe, $arguments) { & $exe @arguments; if ($LASTEXITCODE -ne 0) { throw "$exe falhou: $LASTEXITCODE" } }
Check uv
Check node
Check npm.cmd
$surrealCommand = Get-Command surreal -ErrorAction SilentlyContinue
if ($surrealCommand) {
  $surrealExe = $surrealCommand.Source
} else {
  $surrealExe = 'D:\Ferramentas\surrealdb\surreal-v2.7.0.windows-amd64.exe'
  if (!(Test-Path $surrealExe)) { throw 'SurrealDB nao localizado. Consulte WMK-WINDOWS.md.' }
}
if ([version]((node --version).TrimStart('v')) -lt [version]'20.9') { throw 'Node >= 20.9 necessario' }
$sv = (& $surrealExe version | Out-String)
if ($sv -notmatch '\b2\.\d+\.\d+') { throw 'Use SurrealDB 2.x, como no docker-compose original.' }
if (!(Test-Path .env)) {
  $bytes = New-Object byte[] 32
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  $key = [BitConverter]::ToString($bytes).Replace('-','').ToLower()
  $config = (Get-Content .env.example -Raw).Replace('change-me-to-a-secret-string',$key).Replace('ws://surrealdb:8000/rpc','ws://127.0.0.1:8000/rpc')
  [IO.File]::WriteAllText((Join-Path $PWD '.env'),$config)
}
if ($Setup) {
  Run uv @('python','install','3.12')
  Run uv @('sync','--managed-python','--python','3.12','--locked')
  Push-Location frontend
  try { Run npm.cmd @('ci') } finally { Pop-Location }
}
if (!(Test-Path '.venv\Scripts\python.exe') -or !(Test-Path 'frontend\node_modules\.bin\next.cmd')) { throw 'Execute primeiro windows.ps1 -Setup' }
# Read the original environment via uv/python; do not print credentials.
$config = & uv run --no-sync --env-file .env python -c "import os,json; print(json.dumps({k:os.getenv(k) for k in ['SURREAL_URL','SURREAL_USER','SURREAL_PASSWORD','API_PORT']}))"
if ($LASTEXITCODE -ne 0) { throw 'Falha lendo .env' }
$c = $config | ConvertFrom-Json
if ($c.SURREAL_URL -ne 'ws://127.0.0.1:8000/rpc') { throw 'SURREAL_URL deve ser ws://127.0.0.1:8000/rpc neste launcher.' }
if ($c.API_PORT -and $c.API_PORT -ne '5055') { throw 'Este launcher exige API_PORT=5055.' }
foreach ($port in 8000,5055,3000) {
  if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw "Porta $port ocupada. Encerre o servico correspondente antes de iniciar." }
}
New-Item -ItemType Directory -Force surreal_data,wmk-logs | Out-Null
$env:SURREAL_EXPERIMENTAL_GRAPHQL='true'
$env:SURREAL_USER=$c.SURREAL_USER
$env:SURREAL_PASS=$c.SURREAL_PASSWORD
$env:API_HOST='127.0.0.1'
$env:API_PORT='5055'
$env:API_RELOAD='false'
$env:CORS_ORIGINS='http://127.0.0.1:3000,http://localhost:3000'
$env:OPEN_NOTEBOOK_WORKER_MAX_TASKS='1'
$env:API_URL='http://127.0.0.1:5055'
$env:INTERNAL_API_URL=$env:API_URL
$env:NEXT_PUBLIC_API_URL=$env:API_URL
$children = @()
function Start-ServiceProcess($name,$exe,$argsList,$dir) {
  Write-Host "Iniciando $name..."
  $p = Start-Process -FilePath $exe -ArgumentList $argsList -WorkingDirectory $dir -RedirectStandardOutput "$PSScriptRoot\wmk-logs\$name.out.log" -RedirectStandardError "$PSScriptRoot\wmk-logs\$name.err.log" -PassThru -NoNewWindow
  $script:children += $p
  return $p
}
function Wait-Http($url,$p,$name) {
  for ($i=0;$i -lt 120;$i++) {
    if ($p.HasExited) { throw "$name encerrou. Consulte wmk-logs\$name.err.log" }
    try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { return } } catch {}
    Start-Sleep -Seconds 1
  }
  throw "$name nao respondeu: $url"
}
try {
  $db = Start-ServiceProcess db $surrealExe @('start','--bind','127.0.0.1:8000','--log','info','rocksdb:surreal_data/notebook.db') $PSScriptRoot
  Wait-Http 'http://127.0.0.1:8000/health' $db db
  $api = Start-ServiceProcess api (Get-Command uv).Source @('run','--no-sync','--env-file','.env','run_api.py') $PSScriptRoot
  Wait-Http 'http://127.0.0.1:5055/docs' $api api
  $worker = Start-ServiceProcess worker (Get-Command uv).Source @('run','--no-sync','--env-file','.env','surreal-commands-worker','--import-modules','commands','--max-tasks','1') $PSScriptRoot
  $front = Start-ServiceProcess frontend (Get-Command node).Source @('node_modules/next/dist/bin/next','dev','--hostname','127.0.0.1','--port','3000') (Join-Path $PSScriptRoot frontend)
  Wait-Http 'http://127.0.0.1:3000' $front frontend
  if ($worker.HasExited) { throw 'Worker encerrou. Consulte wmk-logs.' }
  Write-Host 'Interface HTTP disponivel. Teste importacao e chat antes de considerar homologado.'
  if ($SmokeTest) {
    $null = Invoke-RestMethod 'http://127.0.0.1:5055/openapi.json' -TimeoutSec 15
    Write-Host 'SMOKE PASS: DB, API e frontend responderam; worker vivo. Chat/RAG ainda nao testados.'
    return
  }
  Start-Process 'http://127.0.0.1:3000'
  while ($true) {
    foreach ($p in $children) { if ($p.HasExited) { throw "Processo $($p.Id) encerrou. Consulte wmk-logs." } }
    Start-Sleep -Seconds 2
  }
} finally {
  foreach ($p in $children) { if (!$p.HasExited) { & taskkill.exe /PID $p.Id /T /F 2>$null | Out-Null } }
}
