<#
  Projeto MPD — Base de dados do navio-fábrica (sta_princesa)
  data/executar_tudo.ps1 — cria a base de dados do zero, pela ordem certa:

      schema.sql → seed.sql → views.sql → programmable_objects.sql

  Uso (PowerShell, na pasta do projeto, com o contentor MySQL a correr):

      .\data\executar_tudo.ps1            # cria a BD com os dados de teste
      .\data\executar_tudo.ps1 -Testes    # e corre os testes de data/testes/

  Também serve para repor os dados de teste depois de usar o protótipo.
  A palavra-passe de root não está neste ficheiro: é lida dentro do
  contentor (variável MYSQL_ROOT_PASSWORD, definida no docker-compose.yml).
  Os ficheiros são enviados ao MySQL tal como estão (UTF-8), sem passar
  pelo "<" do PowerShell, que estragava os acentos.
#>
param(
  [string]$Contentor = 'MPD_pesca',
  [switch]$Testes
)

$ErrorActionPreference = 'Stop'
$scripts = @('schema.sql', 'seed.sql', 'views.sql', 'programmable_objects.sql')
if ($Testes) {
  $scripts += 'testes\testes_triggers.sql', 'testes\testes_fechar_lote.sql', 'testes\testes_restricoes.sql'
}

$saida = Join-Path $env:TEMP 'sta_princesa_saida.txt'
$erros = Join-Path $env:TEMP 'sta_princesa_erros.txt'
$mysql = 'exec -i {0} sh -c "mysql -uroot -p$MYSQL_ROOT_PASSWORD --default-character-set=utf8mb4 --table"' -f $Contentor

foreach ($s in $scripts) {
  $ficheiro = Join-Path $PSScriptRoot $s
  Write-Host "`n=== $s" -ForegroundColor Cyan
  $p = Start-Process -FilePath 'docker' -ArgumentList $mysql -NoNewWindow -Wait -PassThru `
         -RedirectStandardInput $ficheiro -RedirectStandardOutput $saida -RedirectStandardError $erros
  Get-Content $saida -Encoding UTF8
  $avisos = Get-Content $erros -Encoding UTF8 | Where-Object { $_ -notmatch 'Using a password on the command line' }
  if ($p.ExitCode -ne 0 -or $avisos) {
    $avisos | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw "Falhou em $s (código $($p.ExitCode)). O contentor $Contentor está a correr?"
  }
}

Write-Host "`nConcluído: base de dados sta_princesa criada$(if ($Testes) { ' e testada' })." -ForegroundColor Green
