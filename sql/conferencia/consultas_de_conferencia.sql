-- =====================================================================
-- Consultas de conferencia do painel (TCC Ciclo de vida da atencao)
-- Cada consulta vem depois de uma linha "conferencia" que diz o que ela
-- confere e o valor esperado. Para rodar todas de uma vez:
--   docker cp sql/conferencia/consultas_de_conferencia.sql tcc_postgres:/tmp/conf.sql
--   docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/conf.sql -o /tmp/resultado_conf.txt
--   docker cp tcc_postgres:/tmp/resultado_conf.txt tmp/resultado_conferencia.txt
-- No DBeaver, cada consulta tambem roda sozinha (cursor nela e Ctrl+Enter).
-- =====================================================================

-- ------------------------------ VISAO GERAL ------------------------------
SELECT 'VG.1 | cartoes de visitas e materias, pela Gold | esperado: 132558655, 195771 e 3640 linhas' AS conferencia;
SELECT SUM(views_principal) AS visitas, SUM(materias) AS materias, COUNT(*) AS linhas
FROM gold.fato_serie_diaria;

SELECT 'VG.2 | visitas pela Silver (so pessoas, tres acessos) | esperado: 132558655' AS conferencia;
SELECT SUM(views_principal) AS visitas
FROM silver.pageviews_diario_evento
WHERE tipo_agente = 'user';

SELECT 'VG.3 | materias pela Silver, pais por pais | esperado: 195771' AS conferencia;
SELECT SUM(materias) AS materias
FROM silver.cobertura_diaria_pais;

SELECT 'VG.4 | colunas por ano | esperado: 2, 2, 12, 14, 8 e 2, de 2020 a 2025' AS conferencia;
SELECT EXTRACT(YEAR FROM data_evento) AS ano, COUNT(*) AS eventos
FROM gold.dim_evento
GROUP BY 1 ORDER BY 1;

SELECT 'VG.5 | visitas do Kobe Bryant | esperado: 26865913' AS conferencia;
SELECT SUM(f.views_principal) AS visitas
FROM gold.fato_serie_diaria f
JOIN gold.dim_evento e USING (id_evento)
WHERE e.nome_evento = 'Kobe Bryant';

-- ---------------------------- SUBIDA E QUEDA -----------------------------
SELECT 'SQ.1 | meia-vida contada por fonte | esperado: publico 2.21 com 39 eventos; midia 2.05 com 40' AS conferencia;
SELECT fonte, ROUND(AVG(meia_vida_observada)::numeric, 2) AS media, COUNT(meia_vida_observada) AS eventos
FROM gold.fato_metricas_evento
GROUP BY fonte;

SELECT 'SQ.2 | outras medidas de queda | esperado: publico 3.27, 16.88, 10.4 (37); midia 3.44, 15.21, 7.2 (39)' AS conferencia;
SELECT fonte,
       ROUND(AVG(meia_vida_fase1)::numeric, 2)   AS primeira_fase,
       ROUND(AVG(meia_vida_simples)::numeric, 2) AS reta_unica,
       ROUND(AVG(dias_ate_10pct)::numeric, 1)    AS ate_10pct,
       COUNT(dias_ate_10pct)                     AS eventos_10pct
FROM gold.fato_metricas_evento
GROUP BY fonte;

SELECT 'SQ.3 | topo da curva media | esperado: maior valor das duas colunas no dia 1, cerca de 0.83 no publico e 0.80 na imprensa' AS conferencia;
SELECT dias_desde_evento,
       ROUND(AVG(pct_pico_publico)::numeric, 3) AS publico,
       ROUND(AVG(pct_pico_midia)::numeric, 3)   AS imprensa
FROM gold.fato_serie_diaria
WHERE dias_desde_evento BETWEEN -2 AND 3
GROUP BY 1 ORDER BY 1;

SELECT 'SQ.4 | serie dos robos | esperado: 3640 linhas por tipo, menos dias com valor nos outros robos (automated)' AS conferencia;
SELECT tipo_agente, COUNT(*) AS linhas, COUNT(pct_pico) AS dias_com_valor
FROM gold.fato_serie_robos
GROUP BY 1;

SELECT 'SQ.5 = QP.1 | leituras na forma oficial | esperado: simultaneo 31, picos_distantes 3, inicio_nao_observavel 3, inconclusivo 2, midia_antes 1' AS conferencia;
SELECT leitura, COUNT(*) AS eventos
FROM gold.fato_defasagem_evento
WHERE variante = 'nivel_log'
GROUP BY 1 ORDER BY 2 DESC;

-- -------------------------- QUEM VEIO PRIMEIRO ---------------------------
SELECT 'QP.2 | os dois metodos concordam | esperado: 33 na linha nivel_log' AS conferencia;
SELECT variante, COUNT(*) FILTER (WHERE concorda_com_lag_por_pico) AS concordam
FROM gold.fato_defasagem_evento
GROUP BY 1;

SELECT 'QP.3 | dias de vantagem da imprensa | esperado: 0 com 34, 1 com 2, 2 com 1, 3 com 1, 6 com 2, nenhum negativo' AS conferencia;
SELECT defasagem_otima, COUNT(*) AS eventos
FROM gold.fato_defasagem_evento
WHERE variante = 'nivel_log'
GROUP BY 1 ORDER BY 1;

SELECT 'QP.4 | correlograma medio | esperado: maior valor no 0 (0.791); 0.749 no +1 e 0.726 no -1' AS conferencia;
SELECT defasagem, ROUND(AVG(correlacao)::numeric, 3) AS media
FROM gold.fato_correlacao_defasagem
WHERE variante = 'nivel_log'
GROUP BY 1 ORDER BY 1;

SELECT 'QP.5 | Furacao Ian nas duas formas | esperado: nivel_log 3, 1, true, midia_antes; nivel_linear simultaneo' AS conferencia;
SELECT d.variante, d.defasagem_otima, d.lag_por_pico, d.concorda_com_lag_por_pico, d.leitura
FROM gold.fato_defasagem_evento d
JOIN gold.dim_evento e USING (id_evento)
WHERE e.nome_evento = 'Furacao Ian'
ORDER BY 1;

SELECT 'QP.6 | tendencia comum | esperado: 793 positivas de 840' AS conferencia;
SELECT COUNT(*) FILTER (WHERE correlacao > 0) AS positivas, COUNT(*) AS total
FROM gold.fato_correlacao_defasagem
WHERE variante = 'nivel_log';

SELECT 'QP.7 | Kobe Bryant perto do dia 0 | esperado: no 0, r perto de 0.934, limite perto de 0.210 e 91 dias' AS conferencia;
SELECT c.defasagem,
       ROUND(c.correlacao::numeric, 3)     AS r,
       ROUND(c.limite_critico::numeric, 3) AS limite,
       c.n_pares
FROM gold.fato_correlacao_defasagem c
JOIN gold.dim_evento e USING (id_evento)
WHERE e.nome_evento = 'Kobe Bryant' AND c.variante = 'nivel_log' AND c.defasagem BETWEEN -1 AND 1
ORDER BY 1;

-- ------------------------ ASSUNTOS RELACIONADOS --------------------------
SELECT 'AR.1 | os quatro cartoes | esperado: 35.6 na marca 1; 26.6 na 2; 21.2 na 3; 14.9 na 5' AS conferencia;
SELECT corte_amplificacao, ROUND(AVG(artigos_no_corte)::numeric, 1) AS media
FROM (SELECT DISTINCT id_evento, corte_amplificacao, artigos_no_corte
      FROM gold.fato_serie_sensibilidade) t
GROUP BY 1 ORDER BY 1;

SELECT 'AR.2 | coluna Dobraram por categoria | esperado: desastre 35.6, morte 34.9, politica 29.8, ciencia 25.5, produto 7.0' AS conferencia;
SELECT e.categoria, ROUND(AVG(t.artigos_no_corte)::numeric, 1) AS media
FROM (SELECT DISTINCT id_evento, artigos_no_corte
      FROM gold.fato_serie_sensibilidade
      WHERE corte_amplificacao = 2.0) t
JOIN gold.dim_evento e USING (id_evento)
GROUP BY 1 ORDER BY 2 DESC;

SELECT 'AR.3 | marca de 2 vezes contada direto na Silver | esperado: 26.6, igual a AR.1' AS conferencia;
SELECT ROUND(AVG(n)::numeric, 1) AS media
FROM (SELECT id_evento,
             COUNT(*) FILTER (WHERE eh_principal OR alias_de IS NOT NULL OR razao_amplificacao >= 2) AS n
      FROM silver.artigos
      GROUP BY id_evento) t;

SELECT 'AR.4 | de onde vem o 1.424 | esperado: 40 principais, 24 titulos antigos, 1424 no total' AS conferencia;
SELECT COUNT(*) FILTER (WHERE eh_principal) AS principais,
       COUNT(*) FILTER (WHERE alias_de IS NOT NULL) AS titulos_antigos,
       COUNT(*) AS total
FROM silver.artigos;

SELECT 'AR.5 | menos artigos na marca de 5 vezes | esperado: Google Gemini 1 e Samsung Galaxy S24 2 no topo' AS conferencia;
SELECT e.nome_evento, t.artigos_no_corte
FROM (SELECT DISTINCT id_evento, artigos_no_corte
      FROM gold.fato_serie_sensibilidade
      WHERE corte_amplificacao = 5.0) t
JOIN gold.dim_evento e USING (id_evento)
ORDER BY 2 LIMIT 5;

SELECT 'AR.6 | artigos sem base (razao 999) | esperado: DESCOBERTA, anotar o numero' AS conferencia;
SELECT COUNT(*) AS artigos_sem_base
FROM silver.artigos
WHERE razao_amplificacao = 999;

-- ------------------------- QUALIDADE DOS DADOS ---------------------------
SELECT 'QD.1 | dias sem dado | esperado: 440 de 3640' AS conferencia;
SELECT COUNT(*) FILTER (WHERE views_principal IS NULL) AS sem_dado, COUNT(*) AS total
FROM gold.fato_serie_diaria;

SELECT 'QD.2 | os 15 eventos das barras | esperado: 15 linhas, ChatGPT e Enchentes no RS com 35 no topo' AS conferencia;
SELECT e.nome_evento, COUNT(*) FILTER (WHERE f.views_principal IS NULL) AS sem_dado
FROM gold.fato_serie_diaria f
JOIN gold.dim_evento e USING (id_evento)
GROUP BY 1
HAVING COUNT(*) FILTER (WHERE f.views_principal IS NULL) > 0
ORDER BY 2 DESC;

SELECT 'QD.3 | origem de cada dia na Silver | esperado: api 1136070; ausente_antes_criacao 19089; ausente_pos_criacao 11097' AS conferencia;
SELECT origem_valor, COUNT(*) AS linhas
FROM silver.pageviews_diario_artigo
GROUP BY 1;

SELECT 'QD.4 | artigos criados depois e no dia do evento | esperado: 3 depois e 7 no dia' AS conferencia;
SELECT COUNT(*) FILTER (WHERE data_criacao_principal > data_evento) AS depois,
       COUNT(*) FILTER (WHERE data_criacao_principal = data_evento) AS no_dia
FROM gold.dim_evento;

SELECT 'QD.5 | da para comparar com antes | esperado: midia abaixo_do_piso 14 e ok 26; publico ok 25 e poucos_dias_com_dado 15' AS conferencia;
SELECT fonte, base_motivo, COUNT(*) AS eventos
FROM gold.fato_metricas_evento
GROUP BY 1, 2 ORDER BY 1, 2;

SELECT 'QD.6 | na imprensa nao existe dia vazio | esperado: 0 dias vazios; dias sem materia e DESCOBERTA' AS conferencia;
SELECT COUNT(*) FILTER (WHERE materias IS NULL) AS dias_vazios,
       COUNT(*) FILTER (WHERE materias = 0)     AS dias_sem_materia
FROM gold.fato_serie_diaria;
