# Pendências e limitações conhecidas da camada Gold

Documento vivo. Registra tudo o que foi verificado, o que divergiu do esperado, o que
ficou fora de escopo e o que ainda é suposição não testada. A intenção é não fechar a
camada com a impressão de que está tudo resolvido.

Atualizado em 29/09/2026, após a carga da `fato_metricas_evento`.

**Estado da camada:** 7 das 9 tabelas carregadas e validadas. Faltam as duas de
correlação, o workflow de orquestração e o gate.

| Tabela | Linhas | Estado |
|---|---|---|
| `dim_data` | 2.254 | validada |
| `dim_tempo_relativo` | 91 | validada |
| `dim_evento` | 40 | validada |
| `fato_serie_diaria` | 3.640 | validada |
| `fato_serie_robos` | 7.280 | validada |
| `fato_serie_sensibilidade` | 14.560 | validada |
| `fato_metricas_evento` | 80 | validada |
| `fato_correlacao_defasagem` | 1.680 | vazia |
| `fato_defasagem_evento` | 80 | vazia |

---

## 1. Entregas que faltam antes de fechar a camada

| # | O que é | Prazo |
|---|---|---|
| P1 | As duas fatos de correlação, começando por um piloto no Kobe antes de virar pipeline | semana de 12/10 |
| P2 | Gate da Gold, com as checagens da seção 10 | semana de 18/10 |
| P3 | Workflow `hop/workflows/gold/wf_carga_gold.hwf` encadeando as nove pipelines na ordem de dependência | antes do gate |
| P4 | Checagem de curvas de robô inteiramente zeradas, dentro do gate (ver G1) | dentro do P2 |

---

## 2. Resolvidas

### G1. Média de controle dos robôs calculada sobre 39 eventos, não 40
**Status:** parcialmente resolvido, vira checagem do gate
O artigo `Kobe_Bryant` não teve nenhum acesso `automated` na janela inteira. Com pico zero,
o `pct_pico` fica nulo e o evento sai de qualquer média. As médias de controle apresentadas
foram calculadas sobre 39 eventos. A correção é declarar o N em toda média publicada e
listar as curvas zeradas no gate.

### G2. Soma parcial silenciosa quando um tipo de acesso é nulo e outro não
**Status:** resolvido, verificado
Contagem de dias com 1 ou 2 acessos preenchidos: **zero ocorrências** em toda a Silver. Ou
os três acessos têm dado, ou nenhum tem. Nenhuma soma da Gold está subestimada. Virou
checagem do gate.

### G3. Número de eventos sem linha de base estava errado na documentação
**Status:** resolvido
A documentação antiga falava em 11. Os números reais, com o critério aplicado:

| Fonte | Base válida | Motivo da exclusão |
|---|---|---|
| Público | 25 de 40 | 15 por poucos dias com dado (menos de 14 no período de -30 a -4) |
| Mídia | 26 de 40 | 14 por base abaixo do piso (mediana menor que 1 matéria por dia) |

Nenhum evento caiu pelo piso de 10 visitas no público: a regra dos 14 dias já elimina os
casos de tráfego quase nulo.

### G4. A meia-vida do ajuste simples superestima a queda em 5 a 8 vezes
**Status:** resolvido, virou resultado do trabalho

| Fonte | Meia-vida contada | Fase 1 (0 a 7 dias) | Ajuste simples |
|---|---|---|---|
| Público | 2,21 dias | 3,27 dias | 16,88 dias |
| Mídia | 2,05 dias | 3,44 dias | 15,21 dias |

A regressão simples cobre do pico até o dia 60, e a cauda longa domina a reta, achatando a
queda brutal dos primeiros dias. O R² não denuncia o problema: no Kobe o ajuste simples dá
0,690 no público e 0,805 na mídia. A contagem direta, que não depende de modelo nenhum,
confirma que a fase 1 é a medida correta.

### G5. O ajuste em duas fases parecia pior que o simples na mídia
**Status:** resolvido, com a conclusão invertida
O `r2_combinado_fases` é uma métrica ruim de comparação, e a proposta foi minha. Ele mistura
a fase 1, que é o que interessa, com a fase 2, que na mídia costuma ser ruído (R² de 0,034
no Matthew Perry). A comparação correta é o R² da fase 1 contra o do ajuste simples:

| Fonte | Fase 1 melhor | Simples melhor | R² simples médio | R² fase 1 médio |
|---|---|---|---|---|
| Público | 34 de 40 | 6 | 0,700 | 0,882 |
| Mídia | 28 de 40 | 12 | 0,508 | 0,678 |

O modelo de duas fases se confirma nas duas fontes.

---

## 3. Verificados e aprovados

| # | O que foi testado | Resultado |
|---|---|---|
| V1 | Estrutura da Gold contra o DDL, coluna a coluna | 9 tabelas e 1 view corretas |
| V2 | `dim_data`: 2.254 linhas, 4 datas conferidas manualmente | correto, incluindo dia da semana |
| V3 | `dim_tempo_relativo`: fases e semanas nas bordas | correto, inclusive semana -1 |
| V4 | `dim_evento`: contagens contra os gates da Bronze e da Silver | tudo batendo |
| V5 | `fato_serie_diaria`: soma contra a Silver | 132.558.655 visitas e 195.771 matérias, idênticas |
| V6 | Picos contra a tabela F3 do gate da Silver | Kobe dia 0, Eleição Brasil dia -28, ChatGPT dia 55 |
| V7 | Normalização: 40 dias com pct igual a 1, máximo 1 | correto |
| V8 | `artigos_com_dado` idêntico nos três acessos | zero divergências |
| V9 | Dias nulos por posição na janela | 11 a partir do evento, batendo com o gate |
| V10 | Corte 1x da sensibilidade contra a série diária, por caminhos de cálculo independentes | **zero divergências em 3.640 linhas** |
| V11 | Base válida na `fato_metricas_evento` contra a medição prévia | 25 e 26, exatamente como previsto |

---

## 4. Divergências explicadas e aceitas

### D1. Kobe Bryant sem nenhum acesso `automated` na janela
Dado real. Em janeiro de 2020 a Wikimedia praticamente não classificava tráfego nessa
categoria. Consequência registrada em G1.

### D2. Pico isolado de tráfego `automated` na Turquia, 43 dias após o evento
16.763 acessos em 21/03/2023, quase o dobro do segundo maior dia, concentrados no título da
época (`2023_Turkey–Syria_earthquake`). Causa desconhecida. Não afeta métrica nenhuma do
MVP, porque a curva dos robôs não entra em decaimento nem em correlação.

### D3. Empate no pico de matérias do ChatGPT
Dias 54 e 55 com 152 matérias cada. O desempate adotado, dia mais cedo, fica com o 54. O
pico da atenção pública do mesmo evento é o dia 55: as duas curvas explodem na mesma virada
de janeiro de 2023.

### D4. 41 dias com `pct_pico_midia` igual a 1, e não 40
Consequência de D3.

### G6. ChatGPT sem meia-vida contada nem dias até 10% do pico
Pico no dia 55, janela termina no 60. Não há tempo de observar a queda. As colunas são
nulas por desenho, justamente para permitir esse caso. Vira nota no texto.

### Curva de conjunto colapsada nos cortes altos
Google Gemini fica com 1 artigo no corte de 5x e Samsung Galaxy S24 com 2. Nesses eventos a
análise de sensibilidade perde o sentido, porque a curva do conjunto vira a do principal. É
o dado indicando ausência de transbordamento, não erro.

---

## 5. Hipótese do trabalho refutada pelo dado

### R1. Os agentes automatizados reagem ao evento
A hipótese original era que a curva de robôs não reage ao evento, servindo de controle. **O
dado não sustenta isso.**

| Série | Média antes | Média na 1ª semana | Multiplicador |
|---|---|---|---|
| Público (`user`) | 0,0523 | 0,4165 | 8,0x |
| Spider | 0,0916 | 0,4732 | 5,2x |
| Automated | 0,0767 | 0,3460 | 4,5x |

O padrão por categoria aponta a explicação: a reação dos robôs é de 31x em desastres, cujos
artigos nascem com o evento, e de 1,4x em lançamentos de produto, cujos artigos já existiam
e já eram acessados. Rastreadores visitam com mais frequência páginas novas e páginas em
edição intensa, ou seja, reagem à atividade editorial provocada pelo interesse humano.

---

## 6. Achados que vão para o capítulo 5

Não são pendências, são resultados que apareceram durante a validação e que precisam ser
lembrados na hora de escrever.

1. **O transbordamento varia muito por categoria.** Artigos que sobrevivem ao corte de 2x:
   35,6 em desastre natural, 34,9 em morte de figura pública, 29,8 em político, 25,5 em
   ciência global e **7,0 em lançamento de produto**. Os oito eventos com menos
   sobreviventes são exatamente os oito lançamentos de produto. Confirma com número que o
   volume alto do conjunto em produtos é tráfego de base, e não atenção ao evento.
2. **A cauda do público é mais longa que a da imprensa.** Média de dias até cair a 10% do
   pico: 10,4 no público e 7,2 na mídia; máximos de 40 e 19 dias. As duas caem rápido no
   começo, com meia-vida parecida, mas a imprensa abandona o assunto de vez.
3. **A série da imprensa é sistematicamente mais difícil de ajustar** que a de visitas
   (R² médio de 0,508 contra 0,700 no ajuste simples).
4. **Uma única exponencial não descreve o ciclo de atenção** nestes eventos, e o R² não
   denuncia o problema (ver G4).

---

## 7. Decisões que precisam estar na frente na hora de escrever

| # | Decisão | Motivo |
|---|---|---|
| T1 | A meia-vida reportada é a da **fase 1**, com a contada ao lado como validação. A do ajuste simples entra só como demonstração de que o modelo único falha | ver G4 |
| T2 | O `ganho_r2_sobre_simples` sai da conclusão. A comparação válida é R² da fase 1 contra R² do simples | ver G5 |
| T3 | O argumento dos robôs é reescrito: eles reagem, e a reação é à atividade editorial | ver R1 |
| T4 | Amplificação é métrica secundária, reportada por categoria e sempre com o N | ver G3 |
| T5 | Toda média publicada declara sobre quantos eventos foi calculada | ver G1 |
| T6 | Corrigir a Tabela 1 (cronograma) e o `: :` duplicado nas palavras-chave | pendência antiga |
| T7 | Ajustar as seções 2.4 e 2.6, que afirmam que o gate exige aprovação total: na prática ele separa o que bloqueia do que é alerta documentado | pendência antiga |

---

## 8. Limitações aceitas, para documentar no texto

| # | Limitação |
|---|---|
| L1 | A `razao_amplificacao` usada nos cortes foi medida na curadoria com `all-access/all-agents`, enquanto as séries da Gold usam `user` com os três acessos somados |
| L2 | O pico é calculado sobre a janela inteira. A Eleição do Brasil tem pico no dia -28 (primeiro turno) e o ChatGPT no dia 55 |
| L3 | Queries da Media Cloud apenas em inglês, o que subestima a cobertura em países cuja imprensa não escreve em inglês |
| L4 | Cinco pares de evento e país sem nenhuma matéria: China em COP30, Enchentes do RS, Tina Turner e Cybertruck; Alemanha em Shinzo Abe |
| L5 | Imagem de Sagitário A com apenas 25 dias de cobertura após o evento, o que dá mais ruído à correlação desse evento |

---

## 9. Backlog, fora do escopo do MVP

| # | Item | Motivo |
|---|---|---|
| B1 | `dim_pais` e fato de cobertura por país, com análise de viés doméstico | dado preservado na Silver, análise não cabe no prazo |
| B2 | Corte otimizado das duas fases | o corte fixo em 7 dias entrega o que o artigo prometeu |
| B3 | Terceira variante da correlação (primeira diferença do log) | exige explicar remoção de tendência |
| B4 | Escore padronizado (z-score) | o percentual do pico já normaliza e é mais fácil de explicar |
| B5 | Assimetria da curva | não funciona nestes dados: o pico cai no dia 0 ou 1 na maioria dos eventos |
| B6 | Quebra por tipo de acesso | dado preservado na Silver |
| B7 | Proporção de cobertura (`materias_total`) | fora das métricas do MVP |
| B8 | Recalcular a razão de amplificação no recorte `user` | ver L1 |
| B9 | Investigar a origem do pico de 21/03/2023 na Turquia | ver D2 |
| B10 | Curva do conjunto como resultado próprio, por categoria | entra se sobrar tempo |
| B11 | Testar média em vez de mediana na base da mídia, que salvaria parte dos 14 eventos zerados | mediana foi escolhida por robustez |

---

## 10. Checagens que o gate da Gold precisa ter

1. Contagem de linhas de cada tabela contra o esperado
2. Fidelidade à Silver: somas de visitas e de matérias idênticas
3. Grade completa: todo evento com 91 dias em cada fato de série
4. Coerência da regra de zero e nulo: `views_principal_tratado` igual a zero exatamente
   onde `views_principal` é nulo
5. Todo evento com exatamente um dia de `pct_pico` igual a 1, por série e por agente
6. Curvas inteiramente zeradas, listadas por evento e agente (ver G1)
7. Dias com soma parcial de acessos, que deve ser sempre zero (ver G2)
8. Corte 1x da sensibilidade idêntico ao `views_conjunto` da série diária
9. `artigos_no_corte` nunca menor que 1, e decrescente conforme o corte sobe
10. Toda data das fatos presente na `dim_data` e todo `dias_desde_evento` na
    `dim_tempo_relativo`
11. Eventos com base inválida listados com o motivo, e o total batendo com 25 e 26
12. Coerência entre `base_valida` e `amplificacao`: uma nula implica a outra nula
13. `meia_vida_simples` nula sempre que `lambda_simples` for nulo ou não positivo
14. Ajustes com menos de 5 pontos descartados, ou seja, lambda e R² nulos
15. Eventos sem `meia_vida_observada` ou sem `dias_ate_10pct`, listados com o dia do pico
16. Sempre informar sobre quantos eventos cada média foi calculada
