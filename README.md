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
