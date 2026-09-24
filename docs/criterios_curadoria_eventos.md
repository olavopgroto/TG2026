# Critérios de Curadoria de Eventos

Este documento define as regras objetivas usadas para selecionar os eventos incluídos no estudo e para curar os artigos analisados em cada um deles, evitando escolha arbitrária. Cada evento incluído deve atender a pelo menos uma regra da sua categoria, com fonte pública e verificável.

**Amostra final**: 40 eventos, 8 por categoria, todos entre 2020 e 2025. Para cada evento são analisados 35 artigos da Wikipédia em inglês (o artigo principal e 34 relacionados), mais os títulos anteriores do artigo principal quando existem. Ao todo, 1.424 artigos.

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
- Quantidade de fontes distintas que publicaram sobre o óbito nos 7 dias seguintes ≥ 50 (Media Cloud API v4; critério recalibrado após a substituição da GDELT DOC 2.0 pela Media Cloud)

**Validação executada em 22/09/2026**: os 8 eventos da categoria foram verificados com o método `sources` da Media Cloud API v4, consultando apenas 3 das 10 coleções (Estados Unidos, Reino Unido e Índia) nos 7 dias seguintes a cada óbito. Todos retornaram 100 fontes distintas, que é o limite de listagem da API. Ou seja, os 8 cumprem o critério com folga, já que o mínimo exigido é 50 e a verificação usou menos de um terço das coleções disponíveis.

## Critério 4 — Lançamento de produto ou tecnologia (revisado em 21/09/2026)

**Definição**: lançamento ou anúncio oficial de produto ou tecnologia por empresa de alcance global, com repercussão imediata.

**Regras de inclusão** (atender ambas):
- Empresa entre as 100 marcas mais valiosas do ranking Interbrand no ano do lançamento. **Exceção documentada**: OpenAI (ChatGPT e GPT-4), que não consta no ranking, mas foi incluída porque o ChatGPT foi o produto de consumo com crescimento de usuários mais rápido registrado até então, e porque produtos de IA generativa são parte central do período analisado.
- Artigo próprio na Wikipédia em inglês com visitas registradas até 7 dias após a data do evento, considerando também títulos anteriores do mesmo artigo.

**Nota de revisão**: a regra original exigia artigo criado em até 30 dias do lançamento. Ela foi substituída após a verificação das datas de criação mostrar que ela media a novidade da página, e não a possibilidade de medir a atenção. Vários artigos de produto existem antes do lançamento, como rascunho ou desde o anúncio (Apple Vision Pro, Samsung Galaxy S24, iPhone 15, GPT-4 e Tesla Cybertruck não cumpririam a regra antiga). A nova regra exige o que a análise realmente depende: um artigo com visitas registradas no período do evento. Os 8 eventos da categoria cumprem as duas regras; o ChatGPT é o caso mais próximo do limite, com artigo criado 5 dias após o lançamento.

## Critério 5 — Descobertas científicas de alcance global

**Definição**: divulgações científicas oficiais, feitas por agências internacionais, sobre descobertas de relevância mundial, sem viés geográfico regional.

**Regras de inclusão** (atender pelo menos uma):
- Divulgação oficial e coordenada de agência(s) espacial(is) internacional(is) sobre marco científico inédito
- Pouso/lançamento de missão espacial com transmissão ao vivo internacional

**Janela temporal**: 2020-2025.

## Regra de priorização por cobertura midiática

Dentre os eventos que atendem à regra de cada critério, os eventos são ordenados pela cobertura midiática obtida via Media Cloud API v4 (soma do campo `count` das 10 coleções nacionais validadas — United States, Brazil, United Kingdom, Germany, India, China, Japan, South Africa, Australia, Turkey —, agregado nos 7 dias seguintes ao evento). Havendo empate ou impossibilidade de consulta prévia à API, usa-se como proxy provisório uma métrica objetiva equivalente (ex: número de mortes para desastres), até a extração real recalcular o ranking com dado de cobertura efetivo.

**Nota metodológica**: a fonte de dados deste critério foi originalmente planejada como GDELT DOC 2.0, descontinuada por rate limiting severo e persistente da API pública, verificado em múltiplas redes (Wi-Fi residencial, rede móvel) e em ambiente de nuvem (Google Colab), consistente desde a primeira requisição. Substituída pela Media Cloud API v4 em setembro de 2026, sem alteração na lógica do critério em si — apenas no instrumento de medição.

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

**Limitação de idioma das queries**: as queries são formuladas em inglês e aplicadas às 10 coleções nacionais. Em países cuja imprensa não escreve em inglês, isso restringe a medição aos veículos em língua inglesa daquela coleção, subestimando a cobertura local. O efeito aparece com clareza nas Enchentes do Rio Grande do Sul, com apenas 127 matérias nos 7 dias seguintes apesar da cobertura doméstica intensa, e nos 5 pares de evento e país sem nenhuma matéria na janela (China em quatro eventos e Alemanha no assassinato de Shinzo Abe). Formular queries por idioma aumentaria a cobertura, mas passaria a medir os 40 eventos com instrumentos diferentes, prejudicando a comparação entre eles. Optou-se por manter o instrumento único e registrar a limitação.

**Ruído de query conhecido e quantificado** (validação por amostra manual, `story_sample`):
- Google Gemini (`"Google Gemini" AND AI`): ~30% de menções comparativas (artigos sobre ChatGPT/GPT-4 que citam o Gemini de passagem), sem ruído fora do domínio de IA generativa.
- Perseverance Mars (`"Perseverance rover"`): 3,36% do volume (medido via `source_ids` isolado) originário de páginas-compilado de vídeo de uma única fonte (abcnews.go.com, `source_id 19260`), artefato estrutural de template daquela fonte, não de má formulação da query.

## Mudança de eixo comparativo central (setembro de 2026)

O projeto previa originalmente uma comparação entre Wikipédia em português e em inglês (PT vs. EN), refletida no título formal do TCC. Essa comparação foi **descontinuada** após verificação em `bronze.pageviews_bruto` (`GROUP BY projeto`) confirmar que a camada de pageviews já extraída (~1.041.148 linhas) contempla exclusivamente `en.wikipedia` — não há dado de `pt.wikipedia` na extração realizada.

O eixo comparativo central do projeto foi redefinido para **atenção pública (Wikipedia, en.wikipedia) vs. atenção midiática (Media Cloud, agregado de 10 países)**, por categoria de evento, preservando a categorização por tipo de evento como variável estrutural da análise e a técnica de correlação cruzada com defasagem temporal (lagged cross-correlation) como método de resposta à pergunta de pesquisa.

O título e a pergunta de pesquisa foram atualizados no documento da Fase 1, entregue como "Análise Comparativa do Ciclo de Vida da Atenção Pública e da Cobertura Midiática em Eventos de Repercussão Global".

## Regra da data do evento (setembro de 2026)

A data do evento é o primeiro dia em que o público pode reagir ao fato. Para desastres naturais, mortes e eleições, é o dia do acontecimento. Para descobertas científicas, é o dia da divulgação oficial, como já exige o Critério 5. Para lançamentos de produto, é o dia do anúncio oficial quando a chegada às lojas acontece dentro do mesmo ciclo de notícias (poucas semanas depois). Quando anúncio e lançamento comercial estão separados por meses ou anos, como no Apple Vision Pro e no Tesla Cybertruck, cada um forma um ciclo de atenção próprio, e o evento curado é o lançamento comercial.

A data importa porque define a janela de extração (30 dias antes e 60 depois) e as janelas usadas no cálculo de amplificação dos artigos relacionados (linha de base antes da data, pico nos 15 dias seguintes). Uma data posterior ao pico real joga o pico para dentro da linha de base, o que subestima a amplificação e faz a atenção parecer anterior ao próprio evento.

Correções aplicadas:

| Evento | Data anterior | Data corrigida | Justificativa |
|---|---|---|---|
| iPhone 15 | 22/09/2023 (chegada às lojas) | 12/09/2023 (anúncio) | artigo principal sem visitas até 11/09 e pico de 19.111 visitas em 13/09 |
| Ignição fusão nuclear | 05/12/2022 (experimento) | 13/12/2022 (anúncio oficial) | o resultado só se tornou público em 13/12, e o Critério 5 exige divulgação oficial |

Nos dois eventos, a janela de extração foi recalculada e o ranking de artigos relacionados foi refeito com as novas datas.

**Caso das Enchentes do Rio Grande do Sul**: a data foi mantida em 29/04/2024, quando a enchente começou e a imprensa passou a cobrir. O artigo da Wikipédia em inglês só foi criado em 04/05/2024, sob o título `2024 Brazil floods`, renomeado depois. Os cinco dias de diferença não são erro de curadoria: são a demora da Wikipédia em inglês em registrar um evento brasileiro, e entram na análise como resultado.

## Curadoria dos artigos relacionados (setembro de 2026)

Cada evento é medido por 35 artigos: o principal e 34 relacionados. A escolha dos 34 é automatizada, para não depender de julgamento pessoal.

**Como o ranking é montado** (script `02_gerar_artigos_relacionados.py`):

1. O script lê todos os artigos que o artigo principal referencia. Quando passam de 250, é sorteada uma amostra de 250 com semente fixa (42), para ser reproduzível.
2. Para cada candidato, mede a média diária de visitas na linha de base (do início da janela até a véspera do evento) e no pico (os 15 dias a partir do evento).
3. Calcula a razão de amplificação, que é a média do pico dividida pela média da base. Quando a base é zero, atribui 999 se o pico passa de 50 visitas por dia, e 0 caso contrário.
4. Ordena pela razão e guarda os 70 melhores em cache, dos quais os 34 primeiros entram na análise.

A razão de amplificação, a média de base e a média de pico de cada artigo são carregadas na camada Silver (`silver.artigos`). Isso permite, na camada Gold, refazer a análise com cortes diferentes (por exemplo, considerar apenas artigos acima de 2x, 3x ou 5x) sem reextrair nada, e reportar a sensibilidade do resultado a esse corte.

**Revisão manual**: a lista automática foi revisada evento por evento, com um critério único, o de remover apenas o que entrou por engano. São três tipos de engano:

- **Outro acontecimento**: o artigo subiu por causa de um evento diferente na mesma época. Exemplo: a tempestade `Storm Daniel`, que causou a enchente de Derna na Líbia, aparecia entre os candidatos do terremoto do Marrocos.
- **Duplicata**: dois títulos do mesmo artigo, ou um título que apenas redireciona para outro já selecionado.
- **Artefato técnico**: páginas de identificador bibliográfico da Wikipédia, como `ISSN (identifier)`, que aparecem por causa das referências.

Foram 45 remoções, registradas com motivo em `hop/dados_referencia/scripts/remocoes.csv`. Nos casos em que o título não bastava para decidir, a decisão foi tomada olhando a série diária de visitas do artigo: se o salto coincide com o dia do evento, o artigo fica; se cai em outro dia, sai. O `International Criminal Court`, por exemplo, foi removido da Cúpula do G20 do Rio porque seu pico ocorreu em 21/11/2024, dia dos mandados contra Netanyahu, sem qualquer reação nos dias 18 e 19, da cúpula.

Quando um artigo é removido, o próximo colocado do ranking entra em seu lugar, mantendo os 35 fixos e preservando o critério objetivo de seleção. Todas as substituições estão em `hop/dados_referencia/log_revisao_aplicada.csv`.

## Títulos anteriores do artigo principal (aliases)

A Wikimedia registra as visitas no título que o artigo tinha no dia do acesso. Quando um artigo é renomeado, as visitas anteriores permanecem no nome antigo. Ignorar isso distorce ou zera a curva de atenção de vários eventos.

O caso mais grave é o terremoto do Marrocos: o título atual (`2023_Al_Haouz_earthquake`) tem **zero** visitas na janela do evento, porque em setembro de 2023 o artigo se chamava `2023 Marrakesh–Safi earthquake`. Sem tratamento, o evento entraria na análise sem curva.

**Regra adotada**: para cada artigo principal, o script busca todos os títulos que hoje redirecionam para ele e mede as visitas de cada um na janela. Os que respondem por pelo menos 1% das visitas do evento entram como títulos alternativos. Na camada Bronze são extraídos como linhas próprias, e na Silver a série deles é somada à do principal.

Foram 24 títulos alternativos em 16 eventos. Alguns exemplos do impacto:

| Evento | Título atual | Título da época | Visitas na janela |
|---|---|---|---|
| Terremoto Turquia-Síria | 342.377 | `2023 Turkey–Syria earthquake` (singular) | 3.555.007 |
| Lançamento Artemis I | 14.938 | `Artemis 1` | 896.777 |
| Threads | 440.008 | `Threads (app)` | 859.336 |

Casos em que o título alternativo era, na época, um artigo separado depois fundido no principal (como `SpaceX Starship development`) também entram na soma, por representarem o mesmo assunto. O peso desses casos é pequeno, abaixo de 6% do total do evento.

A mesma lógica vale para os artigos relacionados: um título que hoje é redirecionamento pode ter sido o título real na época. A regra usada é comparar as visitas do redirecionamento com as do destino no período do evento: fica o que tiver mais visitas. Isso recuperou 71 artigos que seriam descartados por engano, entre eles `Kobe Bryant sexual assault case` (294.617 visitas por dia no pico) e `Sophie, Countess of Wessex`, renomeada em 2023.

## Regra de zero e nulo nas séries de visitas

A API de pageviews da Wikimedia devolve o dia com valor **zero** quando o título existe e ninguém o acessou. Quando não há linha para o dia, é porque não havia dado para aquele título naquela data. A verificação foi feita sobre 15.633 linhas de teste, das quais 5.118 vieram com valor zero explícito, em todos os tipos de agente.

A regra adotada na camada Silver é, portanto:

- linha presente na Bronze, inclusive com valor 0 → **zero**
- dia ausente na Bronze → **nulo**

A data de criação de cada artigo (primeira revisão, obtida via API do MediaWiki) é armazenada em `silver.artigos` e serve para **explicar** o nulo, não para decidi-lo: nulo antes da data de criação significa que o artigo não existia; nulo depois significa renomeação de título ou ausência de dado na API. Essa classificação fica registrada linha a linha na coluna `origem_valor` da tabela `silver.pageviews_diario_artigo`.

Uso das séries na camada Gold: o ajuste de decaimento exclui nulos e zeros, porque o logaritmo exige valores positivos; a correlação cruzada converte nulo em zero, porque a série precisa ser contínua para o alinhamento por data; e os gráficos mantêm o nulo como lacuna visível.

## Auditoria entre camadas

Antes de cada avanço de camada, um conjunto de consultas versionado em `sql/auditoria/` é executado sobre os dados carregados.

**Gate da Bronze** (`gate_bronze_40_eventos.sql`, 29 checagens): alinhamento de chaves entre as três tabelas, continuidade das séries, ausência de dupla contagem, granularidade real por tipo de acesso e agente, e conferência das janelas. Resultado em 22/09/2026: 26 aprovações, 2 informativos e 1 alerta, referente a 10.548 dias ausentes depois da data de criação dos artigos, equivalentes a 0,9% do total e explicados por renomeações de título.

**Gate da Silver** (`gate_silver_40_eventos.sql`, 43 checagens): contagem e integridade das seis tabelas, fidelidade à Bronze (somas e contagens idênticas), grade completa e coerência da regra de zero e nulo, recálculo das agregações linha a linha, consistência da cobertura e prontidão para a análise. Resultado em 23/09/2026: 41 aprovações e 2 alertas, ambos documentados.

Volumes obtidos ao fim da carga: 1.136.070 linhas de visitas na Bronze, 1.166.256 na grade completa da Silver (a diferença são os dias sem dado, preenchidos como nulo), 400 registros de cobertura correspondendo a 36.400 dias por país e 195.771 matérias somadas.

## Outras decisões de arquitetura documentadas

- Coluna `palavra_chave_gdelt` (`eventos_curados.csv`) renomeada para `palavra_chave_busca`, refletindo o uso atual como query booleana para a Media Cloud API.
- Tabela `bronze.eventos_bruto` recriada em setembro de 2026, sem as colunas do desenho antigo pensado para a GDELT (`volume_artigos`, `tom_medio`, `timestamp_cobertura`). Passou a conter apenas o espelho dos metadados dos eventos curados, com as métricas em tabelas próprias, relacionadas por `nome_evento`.
- Tabela `bronze.cobertura_midia_bruto` ganhou a restrição de unicidade por evento e país, impedindo carga duplicada.
- Janelas de extração unificadas: tanto os dados de visitas quanto os de cobertura cobrem os mesmos 91 dias por evento, permitindo comparação dia a dia sem ajuste.
- A pipeline de extração de visitas passou a separar as respostas da API pelo código HTTP: código 200 segue para a leitura do JSON, código 404 (título sem dado na janela) é descartado sem gravar linha, e qualquer outro código interrompe a carga. Sem isso, um único título sem dado derrubava a extração inteira, como ocorreu com o artigo principal do terremoto do Marrocos.
- Pipelines descontinuadas: `extracao_bronze_pageviews.hpl` e `extracao_bronze_artigos_relacionados.hpl`, substituídas pela `extracao_bronze_pageviews_unificada.hpl`, que faz as duas extrações em um fluxo só, com a granularidade de acesso e agente variando na própria URL da requisição. O arquivo `artigos_teste.csv` também foi descontinuado. O histórico dos três permanece no repositório Git.
- A soma dos três tipos de acesso (desktop, mobile-app e mobile-web) é feita na camada Gold, e não na Silver, para preservar a granularidade original. Os agentes `spider` e `automated` são mantidos como controle: se a curva de `user` reage ao evento e a de robôs não, fica demonstrado que o fenômeno medido é atenção humana.

---

## Histórico de revisão
- 26/08/2026: versão consolidada, 5 critérios, 20 eventos curados.
- 09/09/2026: substituição da fonte de cobertura midiática (GDELT DOC 2.0 → Media Cloud API v4) em todos os critérios que dependiam dela, após descontinuação da GDELT por rate limiting. Escopo de coleções definido (10 países, curadoria nacional validada via Directory API). Documentada a mudança de eixo comparativo central (PT vs. EN → Wikipedia vs. Media Cloud), a recriação de `bronze.eventos_bruto`, a renomeação de `palavra_chave_gdelt` e a descontinuação de `artigos_teste.csv`.
- 21/09/2026: definida a regra da data do evento; corrigidas as datas do iPhone 15 e da ignição de fusão nuclear.
- 21/09/2026: Critério 4 revisado (regra de criação do artigo em até 30 dias substituída por artigo com visitas registradas até 7 dias após o evento; exceção documentada da OpenAI na regra do ranking Interbrand).
- 22/09/2026: Critério 3 validado nos 8 eventos de morte (100 ou mais fontes distintas em apenas 3 das 10 coleções). Documentadas a curadoria automatizada dos artigos relacionados, as 45 remoções da revisão manual, a regra dos títulos anteriores do artigo principal e a regra de zero e nulo. Registrados os resultados dos gates da Bronze e da Silver e as pipelines descontinuadas.
