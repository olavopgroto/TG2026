# TG 2026 — Ciclo de vida da atenção digital

Repositório do Trabalho de Graduação de Maria Fernanda Vila Pestilo e Olavo Pilotto Groto, orientado pela professora Lucimar Sasso Vieira, no curso de Tecnologia em Informática para Negócios da Fatec São José do Rio Preto.

**Título**: Análise Comparativa do Ciclo de Vida da Atenção Pública e da Cobertura Midiática em Eventos de Repercussão Global.

## O que o projeto faz

Compara duas curvas de atenção em torno de 40 eventos reais: a atenção do público, medida pelas visitas a artigos da Wikipédia em inglês, e a atenção da imprensa, medida pelo volume de matérias em 10 coleções nacionais da Media Cloud. A pergunta central é quem se move primeiro e quem perde o interesse mais rápido, em cada tipo de evento.

Cada evento é observado numa janela de 91 dias: 30 antes e 60 depois. Os eventos são 8 em cada uma das 5 categorias: desastre natural, evento político, morte de figura pública, lançamento de produto e ciência global.

## Arquitetura

O projeto segue a arquitetura medalhão, com PostgreSQL e Apache Hop rodando em Docker.

```
Wikimedia REST API ─┐
                    ├─> Bronze ─> Silver ─> Gold ─> Power BI
Media Cloud API ────┘
```

| Camada | O que guarda | Volume |
|---|---|---|
| Bronze | o dado como a fonte entregou, sem alteração | 1.136.070 linhas de visitas, 400 registros de cobertura, 40 eventos |
| Silver | dado organizado, com a grade de dias completa e as séries por evento | 1.166.256 linhas na grade, 32.760 na série por evento, 36.400 de cobertura por país |
| Gold | métricas de análise: decaimento, meia-vida, defasagem e correlação | em construção |

## Estrutura do repositório

```
docker/                     compose do PostgreSQL e do Hop
docs/                       documentação de método e de modelagem
hop/
  dados_referencia/         entradas das pipelines (CSV e JSON) e scripts de curadoria
  pipelines/bronze/         extração das três fontes
  pipelines/silver/         carga da camada Silver
  workflows/                orquestração por camada
sql/
  ddl/bronze/               definição das tabelas da Bronze
  ddl/silver/               definição das tabelas da Silver
  auditoria/                gates executados entre camadas
```

## Como rodar

Subir o ambiente:

```bash
cd docker
docker compose up -d
```

O Hop Web fica disponível na porta configurada no `.env`, e o PostgreSQL na porta do mesmo arquivo. As variáveis de ambiente não são versionadas.

Criar as tabelas, na ordem:

```
sql/ddl/bronze/01_pageviews_bruto.sql
sql/ddl/bronze/02_eventos_bruto.sql
sql/ddl/bronze/03_cobertura_midia_bruto.sql
sql/ddl/silver/01_silver.sql
```

Carregar a Bronze, executando os workflows de `hop/workflows/bronze/` nesta ordem: eventos, cobertura e pageviews. A extração de visitas faz 12.816 chamadas à API e leva de 2 a 3 horas.

Carregar a Silver com o workflow `hop/workflows/silver/wf_carga_silver.hwf`, que chama as cinco pipelines em sequência.

## Auditoria

Nenhuma camada avança sem passar pelo gate da anterior. Os arquivos estão em `sql/auditoria/` e verificam alinhamento de chaves, continuidade das séries, ausência de dupla contagem, granularidade real e fidelidade à camada anterior.

```bash
docker cp sql/auditoria/gate_bronze_40_eventos.sql tcc_postgres:/tmp/gate.sql
docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/gate.sql -o /tmp/resultado.txt
docker cp tcc_postgres:/tmp/resultado.txt tmp/resultado.txt
```

## Exceção de arquitetura: Media Cloud

A Media Cloud não publica um endpoint REST documentado para uso direto, apenas uma biblioteca Python. Por isso a extração dessa fonte é feita em um notebook no Google Colab (`hop/dados_referencia/scripts/media_cloud_40_eventos_colab.py`), que grava os 400 arquivos JSON. A partir daí o fluxo volta ao Hop, que lê os arquivos e carrega a Bronze. É a única fonte que não é extraída dentro do Hop, e a decisão está justificada em `docs/criterios_curadoria_eventos.md`.

## Documentação

- `docs/criterios_curadoria_eventos.md`: como os eventos e os artigos foram escolhidos, as regras de tratamento das séries e os resultados das auditorias
- `docs/modelagem_silver.md`: o desenho da camada Silver, tabela por tabela

## Convenções

Commits seguem o padrão Conventional Commits (`feat`, `fix`, `docs`, `chore`, `refactor`), com escopo indicando a camada ou a ferramenta.
