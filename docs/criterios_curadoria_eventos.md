# Critérios de Curadoria de Eventos

Este documento define as regras objetivas usadas para selecionar os eventos incluídos no estudo, evitando escolha arbitrária. Cada evento incluído deve atender a pelo menos uma regra da sua categoria, com fonte pública e verificável.

## Critério 1 — Desastres naturais

**Definição**: eventos de origem natural (terremoto, furacão/ciclone, incêndio florestal, enchente) de grande magnitude.

**Regras de inclusão** (atender pelo menos uma):
- Terremoto com magnitude ≥ 6.5 Mw (fonte: USGS)
- Furacão/ciclone categoria ≥ 3 na escala Saffir-Simpson (fonte: NOAA/NHC)
- Incêndio florestal ou enchente com declaração oficial de emergência nacional

**Janela temporal**: 01/01/2020 a 30/06/2025.

## Critério 2 — Eventos políticos

**Definição**: eleições nacionais de chefe de governo/estado, ou cúpulas diplomáticas de primeiro escalão.

**Regras de inclusão**:
- Eleição presidencial/geral em país do G20, 2020-2025
- OU cúpula oficial do G7, G20, Assembleia Geral da ONU, ou Conferência do Clima da ONU (COP), 2020-2025

## Critério 3 — Morte de figura pública

**Definição**: falecimento de pessoa pública com repercussão jornalística objetivamente ampla e alcance verdadeiramente global.

**Regras de inclusão** (atender ambas):
- Presente na lista "Deaths in [ano]" da Wikipedia, categorias política, entretenimento ou esporte
- Quantidade de fontes distintas que publicaram sobre o óbito nos 7 dias seguintes ≥ 50 (Media Cloud API v4, soma das 10 coleções nacionais validadas — ver seção "Composição das coleções Media Cloud"; critério recalibrado após substituição da GDELT DOC 2.0 pela Media Cloud; validação final pendente de execução em lote da extração)

## Critério 4 — Lançamento de produto/tecnologia

**Definição**: lançamento de produto por empresa de grande relevância global, com repercussão imediata.

**Regras de inclusão** (atender ambas):
- Empresa entre as 100 maiores por valor de marca (ranking Interbrand, ano do lançamento)
- Artigo da Wikipedia sobre o produto criado em até 30 dias do lançamento oficial

## Critério 5 — Descobertas científicas de alcance global

**Definição**: divulgações científicas oficiais, feitas por agências internacionais, sobre descobertas de relevância mundial, sem viés geográfico regional.

**Regras de inclusão** (atender pelo menos uma):
- Divulgação oficial e coordenada de agência(s) espacial(is) internacional(is) sobre marco científico inédito
- Pouso/lançamento de missão espacial com transmissão ao vivo internacional

**Janela temporal**: 2020-2025.

## Regra de priorização por cobertura midiática

Dentre os eventos que atendem à regra de cada critério, os eventos são ordenados pela cobertura midiática obtida via Media Cloud API v4 (soma do campo `count` das 10 coleções nacionais validadas — United States, Brazil, United Kingdom, Germany, India, China, Japan, South Africa, Australia, Turkey —, agregado nos 7 dias seguintes ao evento). Havendo empate ou impossibilidade de consulta prévia à API, usa-se como proxy provisório uma métrica objetiva equivalente (ex: número de mortes para desastres), até a extração real recalcular o ranking com dado de cobertura efetivo.

**Nota metodológica**: a fonte de dados deste critério foi originalmente planejada como GDELT DOC 2.0, descontinuada por rate limiting severo e persistente da API pública, verificado em múltiplas redes (Wi-Fi residencial, rede móvel) e em ambiente de nuvem (Google Colab), consistente desde a primeira requisição. Substituída pela Media Cloud API v4 em setembro de 2026, sem alteração na lógica do critério em si — apenas no instrumento de medição.

## Validação pendente

Os 4 nomes do Critério 3 foram pré-selecionados por relevância global reconhecida (cobertura contínua multi-continental). A validação final pelo filtro de quantidade de fontes ≥ 50 será feita em lote assim que a extração Media Cloud (20 eventos × 10 países) estiver completa e carregada na camada Bronze.

## Composição das coleções Media Cloud

A cobertura midiática global é operacionalizada como a soma de 10 coleções nacionais curadas e ativamente mantidas pela Media Cloud, obtidas via consulta programática ao Directory API (não por documentação estática), garantindo que a composição reflete a curadoria mais atual disponível na plataforma:

| País | ID da coleção | Fontes | Validação |
|---|---|---|---|
| United States | 34412234 | 246 | Exemplo oficial documentado no client Python |
| Brazil | 34412257 | 171 | Confirmado via `collection_list`, `monitored: True` |
| United Kingdom | 34412476 | 90 | Confirmado via `collection()`, `monitored: True` |
| Germany | 34412409 | 61 | Confirmado via `collection()`, `monitored: True` |
| India | 34412118 | 142 | Exemplo oficial documentado no client Python |
| China | 34412193 | 234 | Confirmado via `collection()`, `monitored: True` |
| Japan | 34412056 | 427 | Confirmado via `collection()`, `monitored: True` |
| South Africa | 34412238 | 344 | Confirmado via `collection()`, `monitored: True` |
| Australia | 34412282 | 69 | Confirmado via `collection()`, `monitored: True` |
| Turkey | 34412131 | 113 | Confirmado via `collection()`, `monitored: True` |

Total: ~1.897 fontes agregadas. Critério de seleção dos 10 países: diversidade continental (América do Norte, América do Sul, Europa, Ásia, África, Oceania) combinada com disponibilidade de coleção nacional oficialmente curada e monitorada (`monitored: True`) na plataforma.

**Limitação documentada**: para eventos cujo país-sede está entre os 10 (ex.: terremoto na Turquia, G20 no Brasil, COP30 em Belém), a cobertura agregada é naturalmente inflada por reportagem doméstica desproporcional ao restante do conjunto. A extração é feita de forma granular (uma chamada por país, não agregada em uma única chamada), permitindo isolar e quantificar esse viés na camada Silver antes de qualquer agregação analítica.

**Ruído de query conhecido e quantificado** (validação por amostra manual, `story_sample`):
- Google Gemini (`"Google Gemini" AND AI`): ~30% de menções comparativas (artigos sobre ChatGPT/GPT-4 que citam o Gemini de passagem), sem ruído fora do domínio de IA generativa.
- Perseverance Mars (`"Perseverance rover"`): 3,36% do volume (medido via `source_ids` isolado) originário de páginas-compilado de vídeo de uma única fonte (abcnews.go.com, `source_id 19260`), artefato estrutural de template daquela fonte, não de má formulação da query.

## Mudança de eixo comparativo central (setembro de 2026)

O projeto previa originalmente uma comparação entre Wikipédia em português e em inglês (PT vs. EN), refletida no título formal do TCC. Essa comparação foi **descontinuada** após verificação em `bronze.pageviews_bruto` (`GROUP BY projeto`) confirmar que a camada de pageviews já extraída (~1.041.148 linhas) contempla exclusivamente `en.wikipedia` — não há dado de `pt.wikipedia` na extração realizada.

O eixo comparativo central do projeto foi redefinido para **atenção pública (Wikipedia, en.wikipedia) vs. atenção midiática (Media Cloud, agregado de 10 países)**, por categoria de evento, preservando a categorização por tipo de evento como variável estrutural da análise e a técnica de correlação cruzada com defasagem temporal (lagged cross-correlation) como método de resposta à pergunta de pesquisa.

**Pendente**: atualização formal do título do TCC e da pergunta de pesquisa no documento de proposta, ainda não realizada nesta revisão.

## Regra da data do evento (setembro de 2026)

A data do evento é o primeiro dia em que o público pode reagir ao fato. Para desastres naturais, mortes e eleições, é o dia do acontecimento. Para descobertas científicas, é o dia da divulgação oficial, como já exige o Critério 5. Para lançamentos de produto, é o dia do anúncio oficial quando a chegada às lojas acontece dentro do mesmo ciclo de notícias (poucas semanas depois). Quando anúncio e lançamento comercial estão separados por meses ou anos, como no Apple Vision Pro e no Tesla Cybertruck, cada um forma um ciclo de atenção próprio, e o evento curado é o lançamento comercial.

A data importa porque define a janela de extração (30 dias antes e 60 depois) e as janelas usadas no cálculo de amplificação dos artigos relacionados (linha de base antes da data, pico nos 15 dias seguintes). Uma data posterior ao pico real joga o pico para dentro da linha de base, o que subestima a amplificação e faz a atenção parecer anterior ao próprio evento.

Correções aplicadas:

| Evento | Data anterior | Data corrigida | Justificativa |
|---|---|---|---|
| iPhone 15 | 22/09/2023 (chegada às lojas) | 12/09/2023 (anúncio) | artigo principal sem visitas até 11/09 e pico de 19.111 visitas em 13/09 |
| Ignição fusão nuclear | 05/12/2022 (experimento) | 13/12/2022 (anúncio oficial) | o resultado só se tornou público em 13/12, e o Critério 5 exige divulgação oficial |

Nos dois eventos, a janela de extração foi recalculada e o ranking de artigos relacionados foi refeito com as novas datas.

**Pendente**: Enchentes do Rio Grande do Sul. O artigo principal não tem visitas até 07/05/2024, e o evento está registrado em 29/04/2024. Falta verificar se a página foi criada nessa data ou se existia antes com outro título.

## Outras decisões de arquitetura documentadas nesta revisão

- Coluna `palavra_chave_gdelt` (`eventos_curados.csv`) renomeada para `palavra_chave_busca`, refletindo uso atual como query booleana para a Media Cloud API, não mais para GDELT.
- Tabela `bronze.eventos_bruto` recriada via DDL em setembro de 2026 (estava vazia, sem risco de perda de dado), removendo colunas do desenho antigo pensado para métricas de volume via GDELT (`volume_artigos`, `tom_medio`, `timestamp_cobertura`), passando a conter apenas o espelho de metadado dos 20 eventos curados. Dados de volume residem em tabelas próprias (`bronze.pageviews_bruto`, `bronze.cobertura_midia_bruto`), relacionadas por `nome_evento`.
- Arquivo `artigos_teste.csv` (subconjunto de teste, evento Kobe Bryant, janela temporal divergente do arquivo de produção) descontinuado — não é mais utilizado em nenhuma pipeline ativa.
- **Em aberto, aguardando confirmação**: divergência entre a janela temporal de `bronze.pageviews_bruto` (via `artigos_relacionados.csv`, ~2 a 2,5 anos por evento) e a janela da extração Media Cloud (91 dias por evento) ainda não teve confirmação se é decisão proposital ou pendência a corrigir.

---

## Histórico de revisão
- 26/08/2026: versão consolidada, 5 critérios, 20 eventos curados.
- 09/09/2026: substituição da fonte de cobertura midiática (GDELT DOC 2.0 → Media Cloud API v4) em todos os critérios que dependiam dela, após descontinuação da GDELT por rate limiting. Escopo de coleções definido (10 países, curadoria nacional validada via Directory API). Documentada a mudança de eixo comparativo central (PT vs. EN → Wikipedia vs. Media Cloud), a recriação de `bronze.eventos_bruto`, a renomeação de `palavra_chave_gdelt` e a descontinuação de `artigos_teste.csv`.
- 21/09/2026: definida a regra da data do evento; corrigidas as datas do iPhone 15 e da ignição de fusão nuclear.
