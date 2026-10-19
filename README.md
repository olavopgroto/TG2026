# TG 2026: ciclo de vida da atenção digital

Repositório do Trabalho de Graduação de Maria Fernanda Vila Pestilo e Olavo Pilotto Groto, sob orientação de Lucimar Sasso Vieira, no curso de Tecnologia em Informática para Negócios da Fatec São José do Rio Preto.

**Título**: Análise Comparativa do Ciclo de Vida da Atenção Pública e da Cobertura Midiática em Eventos de Repercussão Global.

## O que o projeto faz

Compara duas curvas de atenção em torno de 40 eventos reais: a atenção do público, medida pelas visitas a artigos da Wikipédia em inglês, e a atenção da imprensa, medida pelo volume de matérias em 10 coleções nacionais da Media Cloud. A pergunta central é quem se move primeiro e quem perde o interesse mais rápido, em cada tipo de evento.

Cada evento é observado numa janela de 91 dias: 30 antes e 60 depois. São 8 eventos em cada uma das 5 categorias: desastre natural, evento político, morte de figura pública, lançamento de produto ou tecnologia, e descoberta científica.

## Resultados

- Na escala de dias, público e imprensa reagiram juntos em 31 dos 40 eventos. A imprensa veio na frente em 1 (o Furacão Ian), o público em nenhum, e 8 eventos ficaram sem conclusão.
- A atenção cai à metade em 2 a 3 dias nas duas fontes, com uma queda rápida nos primeiros dias e uma cauda lenta depois.
- O tipo de evento quase não muda a ordem entre as fontes, mas muda o quanto a atenção se espalha para assuntos relacionados: nos desastres, quase todos os artigos ligados ao evento crescem; nos lançamentos de produto, quase nenhum.

## Arquitetura

O projeto segue a arquitetura medalhão, com PostgreSQL e Apache Hop rodando em Docker, e um painel no Power BI ligado à camada Gold.

```
API de pageviews da Wikimedia (Hop) ──┐
                                      ├─> Bronze ─> Silver ─> Gold ─> Power BI
Media Cloud (Colab, em Python) ───────┘
```

| Camada | O que guarda | Volume |
|---|---|---|
| Bronze | o dado como a fonte entregou, sem alteração | 40 eventos, 1.136.070 linhas de visitas e 400 pacotes da imprensa |
| Silver | séries diárias completas, com cada dia sem dado marcado com o motivo | 1.166.256 linhas na grade por artigo, 32.760 na série por evento e 36.400 de cobertura por país |
| Gold | esquema estrela com as métricas: meia-vida, defasagem e correlação | 9 tabelas (3 dimensões e 6 fatos), entre elas 1.680 correlações e a leitura dos 40 eventos |
| Power BI | painel com 5 páginas | Visão geral, Subida e queda, Quem veio primeiro, Assuntos relacionados e Qualidade dos dados |

## Estrutura do repositório

```
docker/                       compose do PostgreSQL e do Hop, e o script que cria os esquemas
docs/                         documentação de método, de modelagem e das decisões da Gold
hop/
  dados_referencia/           entradas dos pipelines (CSV e os 400 JSON da Media Cloud) e scripts de curadoria
  pipelines/bronze/           extração das três fontes
  pipelines/silver/           carga da camada Silver
  pipelines/gold/             os nove pipelines da Gold, um por tabela
  workflows/                  a orquestração de cada camada: bronze, silver e gold
sql/
  ddl/                        a criação das tabelas de cada camada
  auditoria/                  as verificações entre as camadas e a auditoria profunda da Gold
  conferencia/                as consultas que conferem os números do painel
powerbi/                      o projeto do painel, no formato PBIP
estrutura_banco.sql           um retrato da estrutura do banco, gerado pelo pg_dump
gerar_retrato_projeto.ps1     gera um resumo do estado do projeto, só lendo os dados
verificar_titulos.ps1         confere títulos de artigos na Wikimedia, como apoio à curadoria
```

## Como rodar

**1. Subir o ambiente.** Copie `docker/.env.example` para `docker/.env`, preencha as variáveis e suba os contêineres:

```bash
cd docker
docker compose up -d
```

O Hop Web fica em `http://localhost:<HOP_PORT>/ui`, e o PostgreSQL na porta `POSTGRES_PORT` do `.env`. Quando o banco nasce, o script de `docker/postgres/init` cria os esquemas `bronze`, `silver` e `gold`. As variáveis de ambiente não são versionadas.

**2. Criar a conexão do Hop.** A conexão `postgres_tcc` fica em `hop/metadata/rdbms`, pasta que não é versionada porque guarda a senha. No Hop, ela aponta para `host.docker.internal`, na porta do banco, com a opção `stringtype=unspecified`.

**3. Criar as tabelas**, nesta ordem:

```
sql/ddl/bronze/01_pageviews_bruto.sql
sql/ddl/bronze/02_eventos_bruto.sql
sql/ddl/bronze/03_cobertura_midia_bruto.sql
sql/ddl/silver/01_silver.sql
sql/ddl/gold/01_gold.sql
sql/ddl/gold/02_gold_ajustes.sql
```

O `02_gold_ajustes.sql` roda depois do `01_gold.sql`: ele registra o que mudou na Gold depois de criada, e por quê.

**4. Carregar a Bronze**, executando os workflows de `hop/workflows/bronze/` nesta ordem: eventos, cobertura e pageviews. A extração de visitas faz 12.816 chamadas à API e leva de 2 a 3 horas.

**5. Carregar a Silver** com `hop/workflows/silver/wf_carga_silver.hwf`, que chama os cinco pipelines em sequência.

**6. Carregar a Gold** com `hop/workflows/gold/wf_carga_gold.hwf`, que chama os nove pipelines em sequência.

**7. Abrir o painel.** Abra `powerbi/TCC_WIKIPEDIA.pbip` no Power BI Desktop e atualize. Ele lê o banco `tcc_wikipedia` em `localhost:5432`.

## Auditoria e conferência

Nenhuma camada avança sem passar pela verificação da anterior. Os arquivos estão em `sql/auditoria/` e conferem alinhamento de chaves, continuidade das séries, ausência de contagem dupla, granularidade real, fidelidade à camada anterior e, na Gold, cada conta refeita por outro caminho.

| Arquivo | Camada | Checagens | Resultado |
|---|---|---|---|
| `gate_bronze_40_eventos.sql` | Bronze | 29 | 26 aprovadas, 1 alerta explicado e 2 informativas |
| `gate_silver_40_eventos.sql` | Silver | 43 | 41 aprovadas e 2 alertas explicados |
| `gate_gold.sql` | Gold | 59 | 54 aprovadas e 5 informativas |
| `auditoria_gold_profunda.sql` | Gold, refazendo as contas | 53 | 53 aprovadas |

Para rodar uma delas (a pasta `tmp/` não é versionada; crie antes, se não existir):

```powershell
$arquivo = "gate_gold.sql"
docker cp sql/auditoria/$arquivo tcc_postgres:/tmp/gate.sql
docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/gate.sql -o /tmp/resultado.txt
docker cp tcc_postgres:/tmp/resultado.txt tmp/resultado.txt
```

Os números do painel foram conferidos de duas formas independentes: 28 consultas direto no banco, em `sql/conferencia/consultas_de_conferencia.sql`, e 10 consultas dentro do próprio Power BI. O painel também passou por um roteiro de testes com 172 casos.

## Exceção de arquitetura: Media Cloud

A Media Cloud não publica um endpoint REST documentado para uso direto, apenas uma biblioteca Python. Por isso a extração dessa fonte é feita em um notebook no Google Colab (`hop/dados_referencia/scripts/media_cloud_40_eventos_colab.py`), que grava os 400 arquivos JSON. A partir daí o fluxo volta ao Hop, que lê os arquivos e carrega a Bronze. É a única fonte que não é extraída dentro do Hop, e a decisão está justificada em `docs/criterios_curadoria_eventos.md`.

## Documentação

- `docs/criterios_curadoria_eventos.md`: como os eventos e os artigos foram escolhidos, as regras de tratamento das séries e os resultados das auditorias
- `docs/modelagem_silver.md`: o desenho da camada Silver, tabela por tabela
- `docs/pendencias_gold.md`: o registro da Gold, com o que foi verificado, os erros encontrados e corrigidos, as decisões de método e as limitações

## Convenções

Commits seguem o padrão Conventional Commits (`feat`, `fix`, `docs`, `chore`, `refactor`), com escopo indicando a camada ou a ferramenta.
