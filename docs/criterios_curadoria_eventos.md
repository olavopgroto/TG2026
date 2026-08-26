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
- `numero_fontes` (GDELT) ≥ 50 no dia do óbito (limiar a calibrar com dados reais — validação pendente até a pipeline de extração GDELT estar pronta)

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

Dentre os eventos que atendem à regra de cada critério, os eventos são ordenados pela cobertura midiática obtida via GDELT DOC 2.0 (campo `numero_fontes`, agregado nos 7 dias seguintes ao evento). Havendo empate ou impossibilidade de consulta prévia à API, usa-se como proxy provisório uma métrica objetiva equivalente (ex: número de mortes para desastres), até a extração real recalcular o ranking com dado de cobertura efetivo.

## Validação pendente

Os 4 nomes do Critério 3 foram pré-selecionados por relevância global reconhecida (cobertura contínua multi-continental). A validação final pelo filtro `numero_fontes ≥ 50` será feita em lote assim que a pipeline de extração GDELT estiver operacional.

---

## Histórico de revisão
- 26/08/2026: versão consolidada, 5 critérios, 20 eventos curados.