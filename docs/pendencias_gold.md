# Pendências, decisões e limitações da camada Gold

Documento vivo. Registra o que foi verificado, o que divergiu do esperado, as decisões de
método tomadas durante a construção e o que ficou fora de escopo. A intenção é não fechar a
camada com a impressão de que está tudo resolvido.

Atualizado em 01/10/2026, depois do gate e da auditoria profunda. Revisado em 06/10/2026: limitação L2 corrigida (erro E6).

**Estado: camada completa.** 9 tabelas carregadas, 1 view, 9 pipelines, 1 workflow e 2
arquivos de auditoria.

| Auditoria | Resultado |
|---|---|
| `gate_gold.sql` | 54 OK, 5 informativos, nenhum alerta |
| `auditoria_gold_profunda.sql` | 53 OK, nenhum alerta |

São 112 checagens no total, das quais 53 refazem a conta por um caminho independente e
comparam com o que a pipeline gravou.

| Tabela | Linhas |
|---|---|
| `dim_data` | 2.254 |
| `dim_tempo_relativo` | 91 |
| `dim_evento` | 40 |
| `fato_serie_diaria` | 3.640 |
| `fato_serie_robos` | 7.280 |
| `fato_serie_sensibilidade` | 14.560 |
| `fato_metricas_evento` | 80 |
| `fato_correlacao_defasagem` | 1.680 |
| `fato_defasagem_evento` | 80 |

---

## 1. O que ainda falta

| # | O que é | Prioridade |
|---|---|---|
| P1 | Recarregar a camada do zero pelo workflow, para provar que ela é reproduzível (nunca foi executado de ponta a ponta) | ALTA |
| P2 | Power BI: modelo, medidas e painéis | ALTA |
| P3 | Capítulos 4, 5 e 6, aplicando as decisões da seção 7 | ALTA |
| P4 | Resumo de uma página para a orientadora | ALTA |
| P5 | Decidir onde guardar as saídas das auditorias como evidência (hoje caem em `tmp/`, que é ignorado pelo git) | MÉDIA |

---

## 2. Decisões de método tomadas durante a construção

Cada uma foi testada antes de virar regra. Todas valem igualmente para os 40 eventos.

### D1. A correlação ignora os dias sem dado, em vez de convertê-los em zero
**Revisão da regra original, feita em 01/10.** A regra anterior transformava "sem dado" em
zero, o que criava uma curva de público em degrau nos eventos cujo artigo não existia no
começo da janela. O teste mostrou que isso fabricava defasagem: o iPhone 15 aparecia com 8
dias de defasagem e, com os nulos ignorados, cai para 0, com correlação praticamente igual
(0,475 contra 0,492). O mesmo aconteceu com o Google Gemini e as Enchentes do RS.

A função `corr` do PostgreSQL descarta o par quando um lado é nulo. O número de pares de
cada linha fica gravado em `n_pares`, e varia de 46 a 91 conforme o evento.

### D2. O sinal da distância entre picos foi corrigido
O comentário original dizia "dia do pico da mídia menos o do público". A conta estava
invertida em relação à convenção do projeto. A forma correta é **dia do pico do público
menos o da mídia**, coerente com a convenção provada por série artificial: defasagem
positiva significa mídia antes.

### D3. Tolerância de um dia entre as duas medidas
Uma direção só é afirmada quando a correlação e a distância entre os picos apontam o mesmo
sentido, e uma diferença de até um dia conta como empate.

Justificativa: a Wikimedia fecha o dia em UTC e as matérias vêm de dez países em fusos que
vão das Américas à Oceania, então um dia de diferença está dentro da imprecisão da medida.
Sem a tolerância, 11 eventos cairiam em inconclusivo apenas por isso, entre eles Kobe
Bryant, Diego Maradona e Elizabeth II, todos com correlação zero e picos a um dia.

### D4. Limiar de sete dias para eventos de picos distantes
A distância entre os picos vale 0 em 19 eventos, 1 em 16, e depois 3, 4, 10, 13 e 29.
**Nenhum evento fica entre 2 e 9 dias**, então qualquer limiar nessa faixa produz o mesmo
resultado: a separação está no dado, e não na escolha do número.

### D5. Seis leituras possíveis, calculadas por regra no transform
| Leitura | Quando |
|---|---|
| `inicio_nao_observavel` | artigo principal criado depois do dia do evento |
| `picos_distantes` | picos a mais de 7 dias um do outro |
| `inconclusivo` | correlação não significativa, ou medidas discordantes |
| `simultaneo` | as duas medidas dentro da tolerância de um dia |
| `midia_antes` | as duas medidas indicam a imprensa na frente |
| `publico_antes` | as duas medidas indicam o público na frente |

A categoria `publico_antes` foi mantida mesmo ficando vazia: uma classificação que não
consegue expressar o resultado contrário à hipótese seria enviesada. Ela ficar vazia **é**
o resultado.

### D6. A variante oficial é a logarítmica
A linear responde "os picos coincidem?" e a logarítmica responde "o ciclo inteiro tem o
mesmo formato?". A segunda é a pergunta do trabalho, e é a mais estável: no Kobe, a linear
despenca de 0,88 para 0,45 com um dia de deslocamento, enquanto a log mantém um platô
largo. A linear fica como análise de sensibilidade.

### D7. Faixa de defasagem mantida em -10 a +10
Com os nulos ignorados, a maior defasagem observada é 6, longe do teto. Ampliar a faixa
apenas abriria espaço para defasagem falsa.

### D8. Amplificação como métrica secundária
Reportada por categoria e sempre com o número de eventos, nunca como média geral dos 40.
Base válida em 25 de 40 eventos no público e 26 na mídia.

---

## 3. Resultados confirmados

### R1. Público e imprensa se movem juntos na resolução diária

| Leitura | Eventos |
|---|---|
| Simultâneo | 31 |
| Mídia antes | 1 (Furacão Ian) |
| Público antes | 0 |
| Inconclusivo | 2 (Galaxy S24, Cybertruck) |
| Início não observável | 3 (ChatGPT, Enchentes RS, Maui) |
| Picos distantes | 3 (COP28, COP30, Eleição do Brasil) |

**Nenhum evento tem o público na frente.** Quando há diferença, é sempre a imprensa.

**Ressalva importante para o texto:** o Furacão Ian, única conclusão direcional do trabalho,
só aparece como `midia_antes` na variante logarítmica; na linear ele é simultâneo. A
conclusão precisa vir com essa ressalva.

### R2. A atenção cai em dois a três dias, e uma exponencial única não enxerga isso

| Fonte | Meia-vida contada | Fase 1 | Reta única |
|---|---|---|---|
| Público | 2,21 dias | 3,27 dias | 16,88 dias |
| Mídia | 2,05 dias | 3,44 dias | 15,21 dias |

A reta única erra por 5 a 8 vezes, e o R² não denuncia o problema. A fase 1 supera o ajuste
simples em 34 de 40 eventos no público e 28 na mídia.

### R3. O transbordamento varia muito por categoria
Artigos que ao menos dobram de acesso com o evento, de 35: desastre natural 35,6; morte de
figura pública 34,9; político 29,8; ciência 25,5; **lançamento de produto 7,0**. Os oito
eventos com menos sobreviventes são exatamente os oito lançamentos de produto.

### R4. A cauda do público é mais longa que a da imprensa
Dias até cair a 10% do pico: 10,4 no público e 7,2 na mídia; máximos de 40 e 19 dias.

### R5. A série da imprensa é mais difícil de modelar
R² médio da reta única: 0,508 na mídia contra 0,700 no público.

### R6. Os robôs reagem ao evento, contrariando a hipótese original
A hipótese era que a curva dos robôs não reagisse, servindo de controle. O dado mostra o
contrário:

| Série | Média antes | Média na 1ª semana | Multiplicador |
|---|---|---|---|
| Público | 0,0523 | 0,4165 | 8,0x |
| Spider | 0,0916 | 0,4732 | 5,2x |
| Automated | 0,0767 | 0,3460 | 4,5x |

O padrão por categoria aponta a explicação: 31x em desastres, cujos artigos nascem com o
evento, e 1,4x em lançamentos de produto, cujos artigos já existiam. Rastreadores visitam
mais as páginas novas e em edição intensa, ou seja, reagem à atividade editorial provocada
pelo interesse humano.

---

## 4. Divergências explicadas e aceitas

### A1. Furacão Ian classificado de forma diferente nas duas variantes
Ver R1. Das 40 leituras, 5 divergem entre as variantes: Galaxy S24 e Cybertruck
(inconclusivo no log, simultâneo no linear), Shinzo Abe e Terremoto de Myanmar (o
contrário) e o Furacão Ian. As outras 35 concordam.

### A2. Kobe Bryant sem nenhum acesso automatizado na janela
Dado real: em janeiro de 2020 a Wikimedia praticamente não classificava tráfego nessa
categoria. Com pico zero, o percentual do pico fica nulo e o evento sai de qualquer média
de robôs. A checagem V1 do gate lista as curvas zeradas, e toda média publicada precisa
declarar sobre quantos eventos foi calculada.

### A3. Pico isolado de tráfego automatizado na Turquia, 43 dias após o evento
16.763 acessos em 21/03/2023, concentrados no título da época
(`2023_Turkey–Syria_earthquake`). Causa desconhecida. Não afeta métrica nenhuma, porque a
curva dos robôs não entra em decaimento nem em correlação.

### A4. Empate no pico de matérias do ChatGPT
Dias 54 e 55 com 152 matérias cada; o desempate adotado fica com o dia mais cedo. O pico da
atenção pública do mesmo evento é o dia 55: as duas curvas explodem na mesma virada de
janeiro de 2023.

### A5. Quatro séries não caem a 10% do pico dentro da janela
ChatGPT (nas duas fontes), GPT-4 e Galaxy S24 no público. No ChatGPT o motivo é o pico no
dia 55, com apenas 5 dias de janela restantes; nos outros dois é cauda longa de acesso. O
ChatGPT também não tem meia-vida contada no público.

### A6. Os dois eventos inconclusivos não são por correlação fraca
A checagem V5 do gate mostrou que **nenhum** evento tem a melhor correlação abaixo do
limite de significância. Galaxy S24 e Cybertruck caíram em inconclusivo por discordância
entre as duas medidas, não por falta de sinal. A redação precisa refletir isso.

### A7. Curva do conjunto colapsada nos cortes altos
Google Gemini fica com 1 artigo no corte de 5x e Galaxy S24 com 2. Nesses eventos a análise
de sensibilidade perde o sentido, porque a curva do conjunto vira a do principal. É o dado
indicando ausência de transbordamento.

---

## 5. Erros cometidos e corrigidos durante a construção

Registrados porque mostram onde o método é frágil e porque explicam decisões.

| # | Erro | Como apareceu | Correção |
|---|---|---|---|
| E1 | Conversão de nulo em zero na correlação | defasagem de 8 dias no iPhone 15, com picos no mesmo dia | regra revista (D1) |
| E2 | Sinal da distância entre picos invertido no DDL | Furacão Ian daria "público antes" com a mídia na frente | comentário e fórmula corrigidos (D2) |
| E3 | R² combinado usado como critério de comparação | indicava que o ajuste duplo era pior em 38 de 39 eventos na mídia | a comparação válida é R² da fase 1 contra o da reta única |
| E4 | Métrica de assimetria proposta sem checar os dados | o pico cai no dia 0 ou 1 na maioria dos eventos, zerando o denominador | métrica descartada |
| E5 | Duas checagens da auditoria escritas com `GROUP BY` em subconsulta escalar | devolviam vazio em vez de zero e disparavam alerta falso | checagens reescritas |
| E6 | Afirmação de que a correlação em log nunca fica negativa, generalizada a partir dos eventos olhados de perto | o correlograma do Galaxy S24 no dashboard mostrou valores abaixo de zero | medido nos 40 eventos e reescrita a limitação L2 |

---

## 6. Limitações a declarar no texto

| # | Limitação |
|---|---|
| L1 | **Resolução diária.** Se a imprensa publica às 8h e o público consulta às 11h, isso é defasagem zero no dado. O fenômeno pode ocorrer em horas, e a Wikimedia só oferece granularidade diária nesse endpoint |
| L2 | **Tendência comum.** Na variante oficial, 793 das 840 correlações (94%) são positivas. As 47 negativas aparecem em 16 eventos e se concentram longe do evento: 41 entre 7 e 10 dias de deslocamento, 5 entre 4 e 6, e apenas 1 entre 0 e 3 (−0,008, praticamente zero). Perto do evento, a correlação é positiva em 279 de 280 casos, o que indica que parte dela vem de as duas séries subirem e descerem juntas ao longo da janela, e não só do alinhamento dia a dia. A variante de primeira diferença resolveria isso e ficou fora do escopo |
| L3 | **Razão de amplificação em outro recorte.** Foi medida na curadoria com `all-access/all-agents`, enquanto as séries da Gold usam o agente `user` com os três acessos somados |
| L4 | **Pico sobre a janela inteira.** A Eleição do Brasil tem pico no dia -28 (primeiro turno) e o ChatGPT no dia 55 |
| L5 | **Queries da Media Cloud apenas em inglês**, o que subestima a cobertura em países cuja imprensa não escreve em inglês |
| L6 | **Cinco pares de evento e país sem matéria**: China em COP30, Enchentes do RS, Tina Turner e Cybertruck; Alemanha em Shinzo Abe |
| L7 | **Imagem de Sagitário A** com apenas 25 dias de cobertura após o evento |
| L8 | **Número de pares variável na correlação**, de 46 a 91, conforme os dias sem artigo de cada evento. O limite de significância acompanha e fica mais exigente onde há menos dado |

---

## 7. Decisões que precisam estar na frente ao escrever

| # | Decisão |
|---|---|
| T1 | A meia-vida reportada é a da **fase 1**, com a contada ao lado como validação. A da reta única entra só como demonstração de que o modelo único falha |
| T2 | O ganho de R² combinado sai da conclusão. A comparação válida é R² da fase 1 contra o da reta única |
| T3 | O argumento dos robôs é reescrito: eles reagem, e a reação é à atividade editorial |
| T4 | Amplificação é métrica secundária, por categoria e sempre com o N |
| T5 | Toda média publicada declara sobre quantos eventos foi calculada |
| T6 | A conclusão do Furacão Ian vem com a ressalva de que a leitura muda na variante linear |
| T7 | Os dois eventos inconclusivos são por discordância entre medidas, não por correlação fraca |
| T8 | Corrigir a Tabela 1 (cronograma) e o `: :` duplicado nas palavras-chave |
| T9 | Ajustar as seções 2.4 e 2.6, que afirmam que o gate exige aprovação total: na prática ele separa o que bloqueia do que é alerta documentado |
| T10 | Atualizar o número de eventos sem linha de base: 25 válidos no público e 26 na mídia, e não os 11 da documentação antiga |

---

## 8. Backlog, fora do escopo

| # | Item | Motivo |
|---|---|---|
| B1 | `dim_pais` e fato de cobertura por país, com análise de viés doméstico | dado preservado na Silver |
| B2 | Corte otimizado das duas fases | o corte fixo em 7 dias entrega o que o artigo prometeu |
| B3 | Terceira variante da correlação (primeira diferença do log) | resolveria L2, mas exige explicar remoção de tendência |
| B4 | Escore padronizado (z-score) | o percentual do pico já normaliza |
| B5 | Assimetria da curva | ver E4 |
| B6 | Quebra por tipo de acesso | dado preservado na Silver |
| B7 | Proporção de cobertura | fora das métricas do MVP |
| B8 | Recalcular a razão de amplificação no recorte `user` | ver L3 |
| B9 | Investigar a origem do pico de 21/03/2023 na Turquia | ver A3 |
| B10 | Curva do conjunto como resultado próprio, por categoria | entra se sobrar tempo |
| B11 | Testar média em vez de mediana na base da mídia | mediana escolhida por robustez |
| B12 | Remover a coluna `views_principal_tratado`, que ficou sem uso | exigiria recarregar duas tabelas validadas; mantida como registro da regra revista |

---

## 9. Onde estão as auditorias

| Arquivo | O que faz |
|---|---|
| `sql/auditoria/gate_gold.sql` | 59 checagens de consistência, volumes, fidelidade à Silver e coerência entre tabelas. Inclui o teste da convenção de sinal com série artificial gerada na execução |
| `sql/auditoria/auditoria_gold_profunda.sql` | 53 checagens que recalculam as métricas por caminhos independentes, incluindo a regressão do decaimento, as 1.680 correlações e a regra da leitura reescrita em SQL para testar o transform do Hop |

As duas devem ser executadas depois de qualquer recarga da camada.
