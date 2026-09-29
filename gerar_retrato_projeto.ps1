# =====================================================================
# GERAR RETRATO DO PROJETO PARA CONTEXTUALIZAR UM CHAT NOVO
#
# Uso, no PowerShell:
#   cd "C:\Users\olavo\OneDrive\Desktop\TG 2026"
#   powershell -ExecutionPolicy Bypass -File .\gerar_retrato_projeto.ps1
#
# Gera tudo em tmp\retrato\ (pasta ignorada pelo Git). So le dados:
# nao altera banco, pipelines nem arquivos do projeto.
# =====================================================================

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raiz  = "C:\Users\olavo\OneDrive\Desktop\TG 2026"
$saida = Join-Path $raiz "tmp\retrato"
Set-Location $raiz
New-Item -ItemType Directory -Force $saida | Out-Null
Write-Host "Gerando retrato em $saida ..."

# 1. Git: historico e situacao
git log --oneline -60 | Out-File -Encoding utf8 "$saida\01_git_log.txt"
git status --short --untracked-files=all | Out-File -Encoding utf8 "$saida\02_git_status.txt"
Write-Host "  git ok"

# 2. Arvore de arquivos do projeto (sem .git, sem tmp)
Get-ChildItem -Path $raiz -Recurse -File |
  Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\tmp\*" } |
  Select-Object @{n="arquivo";e={$_.FullName.Replace("$raiz\","")}}, Length, LastWriteTime |
  Export-Csv -Encoding utf8 -NoTypeInformation "$saida\03_arvore_arquivos.csv"
Write-Host "  arvore ok"

# 3. Estrutura do banco (gerada dentro do container, sem problema de acento)
docker exec tcc_postgres pg_dump -U tcc -d tcc_wikipedia --schema-only -f /tmp/estrutura.sql
docker cp tcc_postgres:/tmp/estrutura.sql "$saida\04_estrutura_banco.sql" | Out-Null
Write-Host "  estrutura ok"

# 4. Contagens e amostras de todas as tabelas
$sqlContagens = @"
\qecho '=== CONTAGENS ==='
SELECT 'bronze.eventos_bruto' AS tabela, COUNT(*) FROM bronze.eventos_bruto
UNION ALL SELECT 'bronze.cobertura_midia_bruto', COUNT(*) FROM bronze.cobertura_midia_bruto
UNION ALL SELECT 'bronze.pageviews_bruto', COUNT(*) FROM bronze.pageviews_bruto
UNION ALL SELECT 'silver.eventos', COUNT(*) FROM silver.eventos
UNION ALL SELECT 'silver.artigos', COUNT(*) FROM silver.artigos
UNION ALL SELECT 'silver.pageviews_diario_artigo', COUNT(*) FROM silver.pageviews_diario_artigo
UNION ALL SELECT 'silver.pageviews_diario_evento', COUNT(*) FROM silver.pageviews_diario_evento
UNION ALL SELECT 'silver.cobertura_diaria_pais', COUNT(*) FROM silver.cobertura_diaria_pais
UNION ALL SELECT 'silver.cobertura_diaria', COUNT(*) FROM silver.cobertura_diaria;
\qecho '=== EVENTOS DA SILVER (ids) ==='
SELECT id_evento, categoria, nome_evento, data_evento, artigo_principal FROM silver.eventos ORDER BY id_evento;
\qecho '=== ORIGEM DOS VALORES NA GRADE ==='
SELECT origem_valor, COUNT(*) FROM silver.pageviews_diario_artigo GROUP BY 1 ORDER BY 2 DESC;
\qecho '=== ALIASES DO PRINCIPAL ==='
SELECT e.nome_evento, a.artigo, a.alias_de FROM silver.artigos a JOIN silver.eventos e USING (id_evento) WHERE a.alias_de IS NOT NULL ORDER BY 1, 2;
\qecho '=== AMOSTRA: silver.pageviews_diario_evento ==='
SELECT * FROM silver.pageviews_diario_evento WHERE id_evento = 1 AND tipo_agente = 'user' AND tipo_acesso = 'desktop' ORDER BY dia LIMIT 15;
\qecho '=== AMOSTRA: silver.cobertura_diaria ==='
SELECT * FROM silver.cobertura_diaria WHERE id_evento = 1 ORDER BY dia LIMIT 15;
\qecho '=== AMOSTRA: silver.artigos (5 por evento, do evento 1) ==='
SELECT * FROM silver.artigos WHERE id_evento = 1 ORDER BY posicao_ranking LIMIT 5;
"@
$sqlContagens | Out-File -Encoding utf8 "$saida\_retrato.sql"
docker cp "$saida\_retrato.sql" tcc_postgres:/tmp/retrato.sql | Out-Null
docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/retrato.sql -o /tmp/retrato.txt
docker cp tcc_postgres:/tmp/retrato.txt "$saida\05_contagens_e_amostras.txt" | Out-Null
Remove-Item "$saida\_retrato.sql"
Write-Host "  contagens ok"

# 5. Os dois gates (resultado atual)
docker cp "hop\dados_referencia\artigos_metadados.csv" tcc_postgres:/tmp/artigos_metadados.csv | Out-Null
docker cp "sql\auditoria\gate_bronze_40_eventos.sql" tcc_postgres:/tmp/gate_bronze.sql | Out-Null
docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/gate_bronze.sql -o /tmp/gate_bronze.txt
docker cp tcc_postgres:/tmp/gate_bronze.txt "$saida\06_gate_bronze.txt" | Out-Null
Write-Host "  gate da Bronze ok"

docker cp "sql\auditoria\gate_silver_40_eventos.sql" tcc_postgres:/tmp/gate_silver.sql | Out-Null
docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/gate_silver.sql -o /tmp/gate_silver.txt
docker cp tcc_postgres:/tmp/gate_silver.txt "$saida\07_gate_silver.txt" | Out-Null
Write-Host "  gate da Silver ok"

Write-Host ""
Write-Host "Pronto. Arquivos gerados:"
Get-ChildItem $saida | Select-Object Name, Length
