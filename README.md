# Painel UHE-Segredo — Desktop (Windows)

Aplicativo de gestão de documentos técnicos, de uso interno. Este repositório publica **só o programa** (releases) e o instalador.
Para usar é preciso ter uma conta criada por um administrador.

## Instalar ou atualizar

Abra o **PowerShell** (não precisa de administrador) e cole **uma linha**:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/juanpvh/painel-uhe-segredo-desktop/main/instalar-painel.ps1))) -Abrir
```

O mesmo comando atualiza quando sair uma versão nova. Ele:

1. baixa a última versão publicada em *Releases*;
2. confere o **SHA-256** publicado junto com o programa e para se não bater;
3. instala em `%LOCALAPPDATA%\PainelUHE\app` e cria o atalho **Painel UHE-Segredo** no menu Iniciar.

Com o programa já instalado, basta o botão **Atualizar** (canto direito da barra de abas): ele verifica a cada 12 horas e **pisca em verde** quando há versão nova; ao clicar, o Painel baixa, confere o SHA-256, troca o próprio arquivo e reabre sozinho (sem PowerShell). Se algo impedir (pasta protegida, bloqueio de segurança), a mensagem traz o botão *Copiar comando do instalador* com a linha acima.

Opções: `-Abrir` (abre ao terminar), `-SemAtalho`, `-Forcar` (reinstala/fecha o app aberto), `-Desinstalar`, `-Destino <pasta>`.

## Sobre o aviso do Windows

O programa ainda **não tem assinatura digital**. Baixar pelo PowerShell (como acima) não marca o arquivo como "veio da internet",
então o SmartScreen normalmente não mostra aviso. Se baixar o `.exe` pelo navegador, o Windows poderá avisar: clique em
*Mais informações → Executar assim mesmo*, ou em *Propriedades → Desbloquear*.
Em computadores com **Smart App Control** ativo, programas sem assinatura podem ser bloqueados; fale com o TI.

## Conferir o arquivo manualmente

```powershell
(Get-FileHash .\PainelDesktop.App.exe -Algorithm SHA256).Hash   # deve ser igual ao conteúdo de PainelDesktop.App.exe.sha256
```

## Dados e privacidade

O programa só fala com o servidor do sistema (login e dados protegidos por conta). Preferências, tema e logs locais ficam em
`%AppData%\PainelUHE` (sem senhas nem tokens nos logs). Desinstalar não apaga essa pasta.

## Se der erro de conexão

Se aparecer "sem conexão com o servidor", abra **Configurações (engrenagem) > Preferências > Diagnóstico de conexão** e clique em **Testar conexão**; depois **Copiar resultado** e envie ao suporte. A opção *Como o aplicativo se conecta* permite forçar o transporte **WinHTTP** (usa o proxy/PAC do Windows). O diagnóstico também existe como script (não envia senhas nem dados), numa linha:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/juanpvh/painel-uhe-segredo-desktop/main/diagnostico-conexao.ps1)))
```

Cada falha de conexão também fica registrada em `%AppData%\PainelUHE\logs\rede-AAAA-MM-DD.log` (14 dias, sem senhas nem tokens).

## Ícone de conexão

No cabeçalho, ao lado da engrenagem, um ícone mostra se o sistema está **online** (verde), **lento** (âmbar), **verificando** ou **sem conexão** (vermelho); passe o mouse para ver o último teste, e clique para *Testar agora* ou abrir o *Diagnóstico de conexão*. O programa testa a conexão ao abrir e no máximo uma vez por hora enquanto está aberto (e só se não houve uso recente), mais uma vez após trocar de rede ou voltar da suspensão; quando está sem conexão, tenta de novo com intervalos crescentes (30 s a 5 min). O intervalo pode ser ajustado em `settings.json` com `connectivityProbeMinutes` (padrão 60, mínimo 15).
