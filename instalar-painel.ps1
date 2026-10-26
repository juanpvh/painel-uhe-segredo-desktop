<#
  Instala ou atualiza o Painel UHE-Segredo (desktop) para o usuario atual. Nao precisa de administrador.

  Instalar ou atualizar (PowerShell, uma linha):
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/juanpvh/painel-uhe-segredo-desktop/main/instalar-painel.ps1))) -Abrir

  (Nao use "irm ... | iex": nesse modo o bloco param() nao recebe os valores padrao.)
  Opcoes: [-Destino <pasta>] [-SemAtalho] [-Abrir] [-Forcar] [-Desinstalar]; tambem da para baixar o arquivo e rodar .\instalar-painel.ps1

  O que faz: baixa a ultima versao publicada (GitHub Releases), confere o SHA-256 publicado junto, instala em
  %LOCALAPPDATA%\PainelUHE\app, cria os atalhos (menu Iniciar e area de trabalho, com o icone da logo) e guarda o numero da versao. Baixar pelo PowerShell
  nao marca o arquivo como "veio da internet", entao o Windows nao mostra o aviso do SmartScreen.
  Texto ASCII de proposito: funciona igual no Windows PowerShell 5.1 ao baixar pela internet.
#>
param(
    [string]$Destino = (Join-Path $env:LOCALAPPDATA 'PainelUHE\app'),
    [switch]$SemAtalho,
    [switch]$Abrir,
    [switch]$Forcar,
    [switch]$Desinstalar
)
$ErrorActionPreference = 'Stop'
[Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials   # proxy da empresa, se existir
$ProgressPreference = 'SilentlyContinue'   # no PowerShell 5.1 a barra de progresso deixa o download muito mais lento
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = 'juanpvh/painel-uhe-segredo-desktop'
$ExeNome = 'PainelDesktop.App.exe'
$Exe = Join-Path $Destino $ExeNome
$VersaoArq = Join-Path $Destino 'versao.txt'
$NomeAtalho = 'Painel UHE-Segredo.lnk'
$AtalhoMenu = Join-Path ([Environment]::GetFolderPath('Programs')) $NomeAtalho
$AtalhoDesktop = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) $NomeAtalho

function Parar-App {
    $rodando = Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($ExeNome)) -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $Exe }
    if ($rodando) {
        if (-not $Forcar) { throw 'O Painel esta aberto. Feche o programa e rode de novo (ou use -Forcar para fecha-lo).' }
        $rodando | Stop-Process -Force
        Start-Sleep -Milliseconds 600
    }
}

if ($Desinstalar) {
    Parar-App
    if (Test-Path $Destino) { Remove-Item $Destino -Recurse -Force }
    foreach ($a in $AtalhoMenu, $AtalhoDesktop) { if (Test-Path $a) { Remove-Item $a -Force } }
    Write-Host 'Painel desinstalado. Suas preferencias e logs ficam em %AppData%\PainelUHE (apague a pasta se quiser).'
    return
}

Write-Host 'Procurando a ultima versao...'
# Sem a API do GitHub (api.github.com): sem login ela permite so 60 consultas por hora por IP, e na rede de uma empresa muita
# gente divide o mesmo IP. O endereco "releases/latest" responde com um redirecionamento para ".../releases/tag/vX.Y.Z",
# que nao tem esse limite; os arquivos ficam em ".../releases/download/vX.Y.Z/<arquivo>".
function Get-UltimaTag {
    $req = [Net.HttpWebRequest]::Create("https://github.com/$Repo/releases/latest")
    $req.AllowAutoRedirect = $false
    $req.UserAgent = 'instalar-painel'
    $req.Timeout = 30000
    $resp = $req.GetResponse()
    try { $loc = [string]$resp.Headers['Location'] } finally { $resp.Close() }
    if ($loc -notmatch '^https://github\.com/.+/releases/tag/(v?\d+\.\d+\.\d+)\s*$') {
        throw 'Nao foi possivel descobrir a ultima versao (resposta inesperada do GitHub). Tente de novo em instantes.'
    }
    return $Matches[1]
}
$tag = Get-UltimaTag
$versao = $tag.TrimStart('v')
$urlExe = "https://github.com/$Repo/releases/download/$tag/$ExeNome"
$urlSha = "https://github.com/$Repo/releases/download/$tag/$ExeNome.sha256"

$instalada = if (Test-Path $VersaoArq) { (Get-Content $VersaoArq -Raw).Trim() } else { '' }
if ($instalada -eq $versao -and (Test-Path $Exe) -and -not $Forcar) {
    Write-Host "O Painel ja esta na versao mais recente ($versao)."
    if ($Abrir) { Start-Process $Exe }
    return
}
if ($instalada) { Write-Host "Atualizando de $instalada para $versao..." } else { Write-Host "Instalando a versao $versao..." }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("painel-" + [Guid]::NewGuid().ToString('N') + '.exe')
try {
    Invoke-WebRequest -Uri $urlExe -OutFile $tmp -UseBasicParsing
    # O GitHub entrega o .sha256 como application/octet-stream: o Content chega como bytes, nao como texto.
    $respSha = Invoke-WebRequest -Uri $urlSha -UseBasicParsing
    $txtSha = if ($respSha.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($respSha.Content) } else { [string]$respSha.Content }
    $esperado = $txtSha.Trim().Split()[0].ToLowerInvariant()
    if ($esperado -notmatch '^[0-9a-f]{64}$') { throw 'O arquivo .sha256 publicado esta invalido.' }
    $obtido = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($obtido -ne $esperado) { throw "Falha na verificacao: o SHA-256 do arquivo baixado ($obtido) nao confere com o publicado ($esperado). Nada foi instalado." }
    Write-Host 'Verificacao SHA-256 ok.'

    Parar-App
    New-Item -ItemType Directory -Force $Destino | Out-Null
    Move-Item -Path $tmp -Destination $Exe -Force
    Unblock-File -Path $Exe -ErrorAction SilentlyContinue
    Set-Content -Path $VersaoArq -Value $versao -Encoding ASCII
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

if (-not $SemAtalho) {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($a in $AtalhoMenu, $AtalhoDesktop) {
        $lnk = $ws.CreateShortcut($a)
        $lnk.TargetPath = $Exe
        $lnk.WorkingDirectory = $Destino
        $lnk.IconLocation = "$Exe,0"        # o icone (logo CONSAG) esta embutido no .exe
        $lnk.Description = 'Painel UHE-Segredo - gestao de documentos tecnicos'
        $lnk.Save()
    }
    Write-Host 'Atalhos criados: menu Iniciar e area de trabalho (Painel UHE-Segredo).'
}
Write-Host "Pronto. Painel $versao instalado em $Destino"
if ($Abrir) { Start-Process $Exe }
