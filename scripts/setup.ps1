param(
    [string]$Platforms = 'android,ios,web'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter não encontrado no PATH. Instale o SDK: https://docs.flutter.dev/install'
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    # Gera os arquivos oficiais das plataformas sem sobrescrever o código existente.
    & flutter create --empty --no-overwrite --platforms=$Platforms --project-name=organiza_financas .
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar as plataformas Flutter.' }

    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependências.' }

    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'A análise do projeto encontrou problemas.' }
}
finally {
    Pop-Location
}
