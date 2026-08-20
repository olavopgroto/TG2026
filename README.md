# TCC — Wikipedia Pageviews x Atenção Pública em Eventos Reais

Projeto de engenharia e análise de dados que investiga a relação entre o volume de acessos a páginas da Wikipedia e eventos reais (desastres, lançamentos, mortes de figuras públicas, etc).

## Pergunta de pesquisa

- O pico de interesse por um tema decai em quantos dias, em média, e esse decaimento segue um padrão (ex: exponencial)?
- Eventos relacionados a desastres naturais geram picos mais agudos e curtos do que eventos políticos?

## Fontes de dados

- [Wikimedia REST API — Pageviews](https://wikimedia.org/api/rest_v1/)
- Fonte de eventos (a definir: GDELT, Google Trends ou curadoria própria)

## Arquitetura

- **Extração e transformação**: Apache Hop
- **Armazenamento**: PostgreSQL, em arquitetura medalhão (schemas `bronze`, `silver`, `gold`)
- **Modelagem**: Esquema estrela (tabela fato de pageviews + dimensões de tempo, página e categoria de evento)
- **Análise e visualização**: Power BI

## Estrutura do repositório
docker/ → docker-compose e configs dos containers (Postgres, Hop)
hop/ → transformações e workflows do Apache Hop
sql/ → scripts DDL (criação de schemas/tabelas) e DML
powerbi/ → dashboard final
docs/ → diagramas e documentação do projeto


## Como rodar o ambiente

*(a preencher no próximo passo, quando o docker-compose estiver pronto)*

## Status

🚧 Em desenvolvimento — TCC com entrega prevista para 01/11/2026