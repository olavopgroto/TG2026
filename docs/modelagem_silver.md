# Modelagem da camada Silver

Este documento descreve como a camada Silver foi desenhada, o que cada tabela guarda e por quê. A definição técnica está em `sql/ddl/silver/01_silver.sql` e a carga em `hop/pipelines/silver/`.

## O que a Silver faz, e o que ela não faz

A Bronze guarda o dado como a fonte entregou, sem alteração. A Gold responde às perguntas de pesquisa. A Silver fica no meio: organiza, padroniza e completa o que estava implícito, sem calcular nenhuma métrica de análise.

Três problemas foram resolvidos aqui:

1. **Os dias que a API não devolveu passaram a existir**, como linha explícita, com o motivo registrado.
2. **As séries de artigos renomeados foram unificadas**, somando os títulos anteriores ao artigo principal.
3. **O eixo de tempo relativo ao evento** (de -30 a +60 dias) ficou pronto, evitando que cada análise da Gold tenha que recalculá-lo.

Decaimento, meia-vida, correlação cruzada e defasagem não estão aqui: são da Gold.

## As seis tabelas

| Tabela | Linhas | Grão |
|---|---|---|
| `eventos` | 40 | um evento |
| `artigos` | 1.424 | um artigo dentro de um evento |
| `pageviews_diario_artigo` | 1.166.256 | artigo x dia x tipo de acesso x tipo de agente |
| `pageviews_diario_evento` | 32.760 | evento x dia x tipo de acesso x tipo de agente |
| `cobertura_diaria_pais` | 36.400 | evento x país x dia |
| `cobertura_diaria` | 3.640 | evento x dia |

### eventos

Espelho dos eventos curados, com um identificador próprio (`id_evento`) que as demais tabelas usam. A Bronze se relaciona por `nome_evento`, que é texto; a partir da Silver, a chave é numérica.

### artigos

Um registro por artigo dentro de um evento. Além do título, guarda o que a curadoria mediu:

- `eh_principal`: se é o artigo do evento em si
- `alias_de`: preenchido quando a linha é um título anterior do artigo principal
- `posicao_ranking`: a posição na ordenação por amplificação
- `media_base`, `media_pico` e `razao_amplificacao`: as métricas que embasaram a seleção
- `data_criacao`: a primeira revisão do artigo

A razão de amplificação estar aqui é o que permite, na Gold, refazer a análise considerando apenas artigos acima de um corte (2x, 3x, 5x) sem reextrair nada. Vira análise de sensibilidade em vez de decisão fixa.

### pageviews_diario_artigo

É a tabela central. Ela tem **todos** os 91 dias de **todos** os artigos, nas 9 combinações de acesso e agente, mesmo os dias em que a API não devolveu nada. A coluna `origem_valor` diz de onde veio cada célula:

| Valor | Significado | `visualizacoes` |
|---|---|---|
| `api` | a Wikimedia respondeu, podendo ser zero | preenchido |
| `ausente_antes_criacao` | o artigo ainda não existia naquele dia | nulo |
| `ausente_pos_criacao` | o artigo existia, mas não há dado: renomeação de título ou falha da API | nulo |

Uma restrição no banco impede incoerência entre as duas colunas: linha marcada como `api` tem que ter valor, e linha marcada como ausente tem que ser nula.

Distribuição na carga atual: 1.136.070 linhas com dado da API, 19.089 nulas por artigo inexistente e 11.097 nulas por renomeação ou ausência.

A coluna `dias_desde_evento` vai de -30 a +60 e é o eixo de todas as comparações entre eventos, já que as datas de calendário são diferentes em cada um.

### pageviews_diario_evento

Agrega a tabela anterior por evento e dia, com **duas curvas**:

- `views_principal`: o artigo principal somado com seus títulos anteriores. É a atenção ao evento em si.
- `views_conjunto`: todos os 35 artigos do evento. É a atenção ao evento mais o transbordamento para o campo semântico (as cidades atingidas, as pessoas envolvidas, os conceitos técnicos).

Ter as duas permite medir o transbordamento, que varia muito por categoria. A coluna `artigos_com_dado` diz quantos artigos tinham valor naquele dia, o que distingue uma queda de interesse de um artigo que ainda não existia.

A soma ignora nulos e devolve nulo quando nenhum artigo do grupo tem dado no dia. São 99 dias nessa situação a partir da data do evento, em três eventos: ChatGPT (5 dias), Enchentes do Rio Grande do Sul (5) e Incêndios em Maui (1).

### cobertura_diaria_pais e cobertura_diaria

Na Bronze, cada registro da Media Cloud guarda os 91 dias dentro de um campo JSON. Aqui o conteúdo é aberto em uma linha por dia.

A versão por país é mantida porque permite medir o viés de cobertura doméstica: em eventos cujo país-sede está entre os 10 da amostra (terremoto na Turquia, G20 no Rio, COP30 em Belém), a cobertura agregada é naturalmente inflada. Com a granularidade preservada, esse efeito pode ser isolado na análise.

A versão agregada soma os 10 países e é a série comparada com a atenção pública. A coluna `paises_com_materia` conta quantos publicaram naquele dia, servindo de medida simples de alcance geográfico.

## A ordem da carga

As cinco pipelines rodam em sequência, no workflow `hop/workflows/silver/wf_carga_silver.hwf`:

```
carga_silver_eventos           40 linhas
        v
carga_silver_artigos           1.424 linhas (precisa do id_evento)
        v
carga_silver_pageviews_artigo  1.166.256 linhas (precisa do id_artigo)
        v
carga_silver_pageviews_evento  32.760 linhas (agrega a anterior)
        v
carga_silver_cobertura         36.400 e 3.640 linhas
```

Para recarregar a camada inteira, é preciso limpar antes, com o bloco comentado no fim do `01_silver.sql`.

## Onde há SQL dentro das pipelines, e por quê

O projeto usa transforms do Hop sempre que possível, e a regra de negócio nunca fica escondida em SQL. Em dois pontos, porém, a consulta faz o trabalho pesado:

**A grade diária.** Cruzar 1,17 milhão de combinações esperadas com 1,1 milhão de linhas da Bronze é uma operação de junção em massa. No banco, com índice, leva minutos; em um lookup linha a linha no Hop, levaria horas. A classificação de `origem_valor`, que é a regra de negócio, continua em um transform visível na pipeline.

**A abertura do JSON da cobertura.** O Postgres abre um array JSON em linhas de forma nativa, o que seria custoso de reproduzir com transforms.

## Escolhas que ficaram para a Gold

- **A soma dos três tipos de acesso.** A Silver mantém desktop, mobile-app e mobile-web separados; a análise trabalha com a soma dos três no agente `user`.
- **Os agentes `spider` e `automated`** são preservados como controle: se a curva de usuários reage ao evento e a de robôs não, fica demonstrado que o que se mede é atenção humana.
- **O decaimento é medido a partir do pico da série**, não da data do evento. Dois eventos deixam isso evidente: a eleição brasileira tem pico no primeiro turno, 28 dias antes da data registrada (o segundo turno), e o ChatGPT tem pico 55 dias após o lançamento, quando o produto viralizou.
