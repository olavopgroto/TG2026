# Pendências e limitações conhecidas da camada Gold

Documento vivo. Registra tudo o que foi verificado, o que divergiu do esperado, o que
ficou fora de escopo e o que ainda é suposição não testada. A intenção é não fechar a
camada com a impressão de que está tudo resolvido.

Atualizado em 29/09/2026, durante a construção da Gold.

Status possíveis: **aberto**, **resolvido**, **aceito** (fica como está, com justificativa),
**backlog** (fora do escopo do MVP).

---

## 1. Críticos, resolver antes de fechar a Gold

### G1. Média de controle dos robôs calculada sobre 39 eventos, não 40
**Status:** aberto
**O que é:** quando o pico de uma curva é zero, a divisão pelo pico não existe e o
`pct_pico` fica nulo. O artigo `Kobe_Bryant` não teve nenhum acesso `automated` na janela
inteira (os 91 dias valem zero), então esse evento sai de qualquer média de `pct_pico`.
As médias de controle apresentadas (automated 0,0767 antes e 0,3460 na primeira semana)
foram calculadas sobre 39 eventos.
**Impacto:** baixo no número, alto na honestidade do texto. Qualquer média publicada
precisa dizer sobre quantos eventos foi calculada.
**Como resolver:** checagem no gate da Gold contando curvas de robô inteiramente zeradas,
e nota no capítulo 5 informando a base de cálculo de cada média.

### G2. Soma parcial silenciosa quando um tipo de acesso é nulo e outro não
**Status:** aberto, nunca testado
**O que é:** na `fato_serie_diaria` e na `fato_serie_robos`, a soma dos três tipos de
acesso usa `SUM`, que ignora nulos. Se num mesmo dia o desktop tiver valor e o mobile-web
for nulo, a soma devolve o valor parcial sem sinalizar nada. A premissa adotada é que a
Wikimedia devolve os nove recortes juntos, então ou todos têm dado ou nenhum tem.
**Impacto:** se a premissa for falsa, há dias com valor subestimado e nenhum aviso.
**Como resolver:** contar, na Silver, os dias em que o agente `user` tem entre 1 e 2
acessos com valor. Se der zero, a premissa está correta e vira checagem do gate.

### G3. Número de eventos sem linha de base está errado na documentação
**Status:** aberto
**O que é:** a documentação anterior fala em 11 eventos sem linha de base. A verificação
mostrou 10 eventos com artigo principal criado no dia do evento ou depois, e 15 eventos
sem nenhum dado no período anterior ao evento. São três recortes diferentes sendo tratados
como um só.
**Detalhe:** os cinco eventos adicionais são Google Gemini (artigo existia como rascunho),
iPhone 15 e Threads Meta (títulos eram redirect com tráfego quase nulo), Samsung Galaxy S24
(4 dias com dado no período de base) e Furacão Ian (9 dias).
**Impacto:** o número que for para o artigo precisa ser o real, e vir com o critério que o
produziu.
**Como resolver:** a `fato_metricas_evento` vai produzir a lista definitiva, com o motivo
de cada evento em `base_motivo`. Só depois disso o texto pode ser escrito.

---

## 2. Verificados e aprovados

| # | O que foi testado | Resultado |
|---|---|---|
| V1 | Estrutura da Gold contra o DDL, coluna a coluna | 9 tabelas e 1 view, nomes e ordem corretos |
| V2 | `dim_data`: 2.254 linhas, sem repetição, 4 datas conferidas manualmente | correto, incluindo dia da semana |
| V3 | `dim_tempo_relativo`: 91 linhas, fases e semanas nas bordas | correto, inclusive semana -1 nos dias negativos |
| V4 | `dim_evento`: contagens contra os gates da Bronze e da Silver | dias sem dado, países zerados e cobertura esparsa, todos batendo |
| V5 | `fato_serie_diaria`: soma contra a Silver | 132.558.655 visitas e 195.771 matérias, idênticas |
| V6 | Picos contra a tabela F3 do gate da Silver | Kobe dia 0, Eleição Brasil dia -28, ChatGPT dia 55, Turquia dia 0 |
| V7 | Normalização: 40 dias com pct igual a 1 no público, máximo 1, mínimo 0,000008 | correto |
| V8 | `artigos_com_dado` idêntico nos três tipos de acesso | zero divergências, o uso do máximo é válido |
| V9 | Dias nulos separados por posição na janela | 11 a partir do evento, batendo com o D5 do gate da Silver |

---

## 3. Divergências explicadas, sem ação pendente

### D1. Kobe Bryant sem nenhum acesso `automated` na janela
Dado real. Em janeiro de 2020 a Wikimedia praticamente não classificava tráfego nessa
categoria. Não é falha de carga. Consequência registrada em G1.

### D2. Pico isolado de tráfego `automated` na Turquia, 43 dias após o evento
16.763 acessos em 21/03/2023, quase o dobro do segundo maior dia. Origem localizada no
título da época (`2023_Turkey–Syria_earthquake`, singular), com 16.735 dos acessos. Causa
desconhecida. **Status: aceito.** Não afeta métrica nenhuma do MVP, porque a curva dos
robôs não entra em decaimento nem em correlação.

### D3. Empate no pico de matérias do ChatGPT
Dias 54 e 55 com 152 matérias cada. O critério de desempate adotado, dia mais cedo, fica
com o 54. Coincidência relevante para o capítulo 5: o pico da atenção pública do mesmo
evento é o dia 55.

### D4. 41 dias com `pct_pico_midia` igual a 1, e não 40
Consequência de D3.

---

## 4. Hipótese do trabalho refutada pelo dado

### R1. Os agentes automatizados reagem ao evento
**A hipótese original** era que a curva de robôs não reage ao evento, servindo de controle
para demonstrar que o fenômeno medido é atenção humana. **O dado não sustenta isso.**

| Série | Média antes | Média na 1ª semana | Multiplicador |
|---|---|---|---|
| Público (`user`) | 0,0523 | 0,4165 | 8,0x |
| Spider | 0,0916 | 0,4732 | 5,2x |
| Automated | 0,0767 | 0,3460 | 4,5x |

O padrão por categoria aponta a explicação: a reação dos robôs é de 31x em desastres,
cujos artigos nascem com o evento, e de 1,4x em lançamentos de produto, cujos artigos já
existiam e já eram acessados. Rastreadores visitam com mais frequência páginas novas e
páginas em edição intensa, ou seja, reagem à atividade editorial provocada pelo interesse
humano, e não ao acontecimento.

**Consequência:** o argumento de controle precisa ser reescrito nos capítulos 4 e 5. A
leitura nova é mais honesta e mais interessante que a original, mas é diferente do que foi
planejado.

---

## 5. Limitações aceitas, para documentar no texto

### L1. Razão de amplificação medida em outro recorte
A `razao_amplificacao` usada nos cortes de sensibilidade foi medida na curadoria com
`all-access/all-agents`, enquanto as séries da Gold usam o agente `user` com os três
acessos somados. São recortes diferentes do mesmo dado. O efeito é pequeno, porque o
`user` responde pela maior parte do tráfego, mas existe.
**Status: aceito.** Recalcular está no backlog.

### L2. O pico é calculado sobre a janela inteira
Decisão de 29/09. Consequência: a Eleição do Brasil tem pico no dia -28, que é o primeiro
turno, e o decaimento dela é medido a partir dali. O ChatGPT tem pico no dia 55. Os dois
casos são resultado e entram na discussão, não são corrigidos.

### L3. Queries da Media Cloud apenas em inglês
Já documentado nos critérios de curadoria. Subestima a cobertura em países cuja imprensa
não escreve em inglês. Aparece nos 5 pares de evento e país sem nenhuma matéria.

### L4. Cinco coleções nacionais sem matéria em algum evento
China em COP30, Enchentes do RS, Tina Turner e Cybertruck; Alemanha em Shinzo Abe.

### L5. Série de mídia esparsa na Imagem de Sagitário A
Apenas 25 dias com matéria depois do evento. A correlação desse evento terá mais ruído.

---

## 6. Backlog, fora do escopo do MVP

| # | Item | Motivo de ter ficado fora |
|---|---|---|
| B1 | `dim_pais` e fato de cobertura por país, com análise de viés doméstico | dado preservado na Silver, análise não cabe no prazo |
| B2 | Corte otimizado das duas fases do decaimento | o corte fixo em 7 dias entrega o que o artigo prometeu |
| B3 | Terceira variante da correlação (primeira diferença do log) | exige explicar remoção de tendência |
| B4 | Escore padronizado (z-score) | o percentual do pico já normaliza e é mais fácil de explicar |
| B5 | Assimetria da curva | não funciona nestes dados: o pico cai no dia 0 ou 1 na maioria dos eventos, o que zera o denominador |
| B6 | Quebra por tipo de acesso (desktop, mobile-app, mobile-web) | dado preservado na Silver |
| B7 | Proporção de cobertura (`materias_total`) | fora das métricas do MVP |
| B8 | Recalcular a razão de amplificação no recorte `user` | ver L1 |
| B9 | Investigar a origem do pico de 21/03/2023 na Turquia | ver D2 |
| B10 | Curva do conjunto como resultado próprio (transbordamento por categoria) | entra se sobrar tempo |

---

## 7. Checagens que o gate da Gold precisa ter

Levantadas durante a construção, para não se perderem:

1. Contagem de linhas de cada tabela contra o esperado
2. Fidelidade à Silver: somas de visitas e de matérias idênticas
3. Grade completa: todo evento com 91 dias em cada fato de série
4. Coerência da regra de zero e nulo: `views_principal_tratado` igual a zero exatamente
   onde `views_principal` é nulo
5. Todo evento com exatamente um dia de `pct_pico` igual a 1, por série e por agente
6. Curvas inteiramente zeradas, listadas por evento e agente (ver G1)
7. Dias com soma parcial de acessos (ver G2)
8. Corte 1x da sensibilidade idêntico ao `views_conjunto` da série diária
9. `artigos_no_corte` nunca menor que 1, e decrescente conforme o corte sobe
10. Toda data das fatos presente na `dim_data`, e todo `dias_desde_evento` presente na
    `dim_tempo_relativo` (já garantido por chave estrangeira, mas vale afirmar)
11. Eventos com base inválida, listados com o motivo
12. Sempre informar sobre quantos eventos cada média foi calculada
