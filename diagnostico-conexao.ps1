# Diagnostico de conexao do Painel UHE-Segredo com o servidor (Supabase). Nao envia senha nem dados: so testes de rede.
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File .\diagnostico-conexao.ps1
# ou (uma linha, sem baixar nada):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/juanpvh/painel-uhe-segredo-desktop/main/diagnostico-conexao.ps1)))
# Texto ASCII de proposito (funciona igual no Windows PowerShell 5.1).
$ErrorActionPreference = 'Continue'
$base = 'https://ltuherivetujfzpfgxve.supabase.co'
$key = 'sb_publishable_4hF7qVW8o795EYN6HLIPWA_2BFEPe0e'   # chave PUBLICA do projeto
$hostName = ([uri]$base).Host
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
function Ok($m) { Write-Host ("[ok]    " + $m) -ForegroundColor Green }
function Falha($m) { Write-Host ("[FALHA] " + $m) -ForegroundColor Red }
function Info($m) { Write-Host ("[info]  " + $m) }

Info ("Data/hora: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "   Windows: " + [Environment]::OSVersion.VersionString + "   PowerShell: " + $PSVersionTable.PSVersion)
Info ("Usuario: " + $env:USERNAME + "   Computador: " + $env:COMPUTERNAME + "   Dominio: " + $env:USERDOMAIN)

# 1) proxy do sistema
try {
    $px = [Net.WebRequest]::GetSystemWebProxy().GetProxy([uri]$base)
    if ($px.Host -eq $hostName) { Info "Proxy do sistema: nenhum (conexao direta)" } else { Info ("Proxy do sistema: " + $px) }
} catch { Info ("Nao foi possivel ler o proxy: " + $_.Exception.Message) }
$pac = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue)
if ($pac) { Info ("Internet Settings: ProxyEnable=" + $pac.ProxyEnable + " ProxyServer=" + $pac.ProxyServer + " AutoConfigURL=" + $pac.AutoConfigURL) }
Info ("Variaveis de proxy: HTTPS_PROXY=" + $env:HTTPS_PROXY + " HTTP_PROXY=" + $env:HTTP_PROXY + " NO_PROXY=" + $env:NO_PROXY)

# 2) DNS
try { $ips = [Net.Dns]::GetHostAddresses($hostName); Ok ("DNS de ${hostName} -> " + ($ips -join ', ')) } catch { Falha ("DNS de ${hostName}: " + $_.Exception.Message) }

# 3) TCP 443
$tcp = New-Object Net.Sockets.TcpClient
try { $iar = $tcp.BeginConnect($hostName, 443, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(8000)) { $tcp.EndConnect($iar); Ok "TCP 443 conectou" } else { Falha "TCP 443: sem resposta em 8 s (firewall/VPN/proxy?)" } } catch { Falha ("TCP 443: " + $_.Exception.Message) } finally { $tcp.Close() }

# 4) HTTPS + certificado (inspecao TLS da empresa aparece aqui como emissor diferente)
try {
    $req = [Net.HttpWebRequest]::Create($base + '/auth/v1/health'); $req.Headers.Add('apikey', $key); $req.Timeout = 15000
    $resp = $req.GetResponse(); Ok ("GET /auth/v1/health -> HTTP " + [int]$resp.StatusCode); $resp.Close()
    $sp = $req.ServicePoint; if ($sp.Certificate) { Info ("Certificado: emissor = " + $sp.Certificate.Issuer) }
} catch {
    Falha ("GET /auth/v1/health: " + $_.Exception.Message)
    if ($_.Exception.InnerException) { Falha ("   causa: " + $_.Exception.InnerException.Message) }
    $sp = $req.ServicePoint; if ($sp -and $sp.Certificate) { Info ("Certificado recebido: emissor = " + $sp.Certificate.Issuer) }
}

# 5) o mesmo tipo de chamada que o app faz ao gerar o numero (POST em /rest/v1/rpc): sem login deve responder 401/403, o que prova que o caminho esta livre
try {
    $r = Invoke-WebRequest -Uri ($base + '/rest/v1/rpc/proxima_sequencia') -Method Post -Headers @{ apikey = $key } -Body '{"p_prefixo":"TESTE"}' -ContentType 'application/json' -UseBasicParsing
    Ok ("POST /rest/v1/rpc/proxima_sequencia -> HTTP " + $r.StatusCode)
} catch {
    $resp = $_.Exception.Response
    if ($resp) { Ok ("POST /rest/v1/rpc/proxima_sequencia -> HTTP " + [int]$resp.StatusCode + " (resposta do servidor: o caminho esta livre)") }
    else { Falha ("POST /rest/v1/rpc/proxima_sequencia: " + $_.Exception.Message); if ($_.Exception.InnerException) { Falha ("   causa: " + $_.Exception.InnerException.Message) } }
}

# 6) o proxy exige login do Windows? repete com as credenciais do usuario
try {
    $wc = New-Object Net.WebClient; $wc.Proxy = [Net.WebRequest]::GetSystemWebProxy(); $wc.Proxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials; $wc.Headers.Add('apikey', $key)
    $null = $wc.DownloadString($base + '/auth/v1/health'); Ok "Com credenciais do Windows no proxy: ok"
} catch { Falha ("Com credenciais do Windows no proxy: " + $_.Exception.Message) }

# 7) GitHub (usado so pelo botao Atualizar)
try { $req = [Net.HttpWebRequest]::Create('https://github.com/juanpvh/painel-uhe-segredo-desktop/releases/latest'); $req.AllowAutoRedirect = $false; $req.Timeout = 15000; $resp = $req.GetResponse(); Ok ("github.com -> HTTP " + [int]$resp.StatusCode); $resp.Close() } catch { Falha ("github.com: " + $_.Exception.Message) }

Write-Host ""
Write-Host "Copie tudo acima e envie para quem esta ajudando." -ForegroundColor Cyan
