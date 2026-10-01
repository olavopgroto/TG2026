-- =====================================================================
-- GATE DA CAMADA GOLD - 40 eventos
-- Arquivo: sql/auditoria/gate_gold.sql
--
-- Nenhuma analise sai da Gold sem passar por aqui. O gate separa o que
-- bloqueia (ALERTA) do que e apenas registrado (INFO), no mesmo padrao
-- dos gates da Bronze e da Silver.
--
-- Como rodar:
--   docker cp sql/auditoria/gate_gold.sql tcc_postgres:/tmp/gate.sql
--   docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/gate.sql -o /tmp/resultado.txt
--   docker cp tcc_postgres:/tmp/resultado.txt tmp/resultado_gold.txt
--
-- Os valores esperados vem das validacoes feitas durante a construcao
-- da camada, todas registradas em docs/pendencias_gold.md.
-- =====================================================================

\pset border 2

CREATE TEMP TABLE resultado_gate AS
WITH

-- ---------------------------------------------------------------------
-- GRUPO A: volumes e completude das grades
-- ---------------------------------------------------------------------
a AS (
    SELECT 'A' AS grupo, 'A1' AS checagem,
           (SELECT COUNT(*) FROM gold.dim_data)::text AS valor,
           '2254' AS esperado,
           'linhas em dim_data (calendario de 2019-12-01 a 2026-01-31)' AS descricao
    UNION ALL SELECT 'A','A2',(SELECT COUNT(*) FROM gold.dim_tempo_relativo)::text,'91','linhas em dim_tempo_relativo (eixo de -30 a +60)'
    UNION ALL SELECT 'A','A3',(SELECT COUNT(*) FROM gold.dim_evento)::text,'40','linhas em dim_evento'
    UNION ALL SELECT 'A','A4',(SELECT COUNT(*) FROM gold.fato_serie_diaria)::text,'3640','linhas em fato_serie_diaria (40 x 91)'
    UNION ALL SELECT 'A','A5',(SELECT COUNT(*) FROM gold.fato_serie_robos)::text,'7280','linhas em fato_serie_robos (40 x 91 x 2)'
    UNION ALL SELECT 'A','A6',(SELECT COUNT(*) FROM gold.fato_serie_sensibilidade)::text,'14560','linhas em fato_serie_sensibilidade (40 x 91 x 4)'
    UNION ALL SELECT 'A','A7',(SELECT COUNT(*) FROM gold.fato_metricas_evento)::text,'80','linhas em fato_metricas_evento (40 x 2 fontes)'
    UNION ALL SELECT 'A','A8',(SELECT COUNT(*) FROM gold.fato_correlacao_defasagem)::text,'1680','linhas em fato_correlacao_defasagem (40 x 2 x 21)'
    UNION ALL SELECT 'A','A9',(SELECT COUNT(*) FROM gold.fato_defasagem_evento)::text,'80','linhas em fato_defasagem_evento (40 x 2)'
    UNION ALL SELECT 'A','A10',
           (SELECT COUNT(*) FROM (SELECT id_evento FROM gold.fato_serie_diaria GROUP BY 1 HAVING COUNT(*) <> 91) x)::text,
           '0','eventos sem os 91 dias na serie diaria'
    UNION ALL SELECT 'A','A11',
           (SELECT COUNT(*) FROM (SELECT id_evento, corte_amplificacao FROM gold.fato_serie_sensibilidade GROUP BY 1,2 HAVING COUNT(*) <> 91) x)::text,
           '0','pares de evento e corte sem os 91 dias'
    UNION ALL SELECT 'A','A12',
           (SELECT COUNT(*) FROM (SELECT id_evento, tipo_agente FROM gold.fato_serie_robos GROUP BY 1,2 HAVING COUNT(*) <> 91) x)::text,
           '0','pares de evento e agente sem os 91 dias'
),

-- ---------------------------------------------------------------------
-- GRUPO B: fidelidade a Silver
-- ---------------------------------------------------------------------
b AS (
    SELECT 'B' AS grupo, 'B1' AS checagem,
           ((SELECT COALESCE(SUM(views_principal),0) FROM gold.fato_serie_diaria)
          - (SELECT COALESCE(SUM(views_principal),0) FROM silver.pageviews_diario_evento WHERE tipo_agente = 'user'))::text AS valor,
           '0' AS esperado,
           'soma de visitas do publico: Gold menos Silver' AS descricao
    UNION ALL SELECT 'B','B2',
           ((SELECT COALESCE(SUM(materias),0) FROM gold.fato_serie_diaria)
          - (SELECT COALESCE(SUM(materias),0) FROM silver.cobertura_diaria))::text,
           '0','soma de materias: Gold menos Silver'
    UNION ALL SELECT 'B','B3',
           ((SELECT COALESCE(SUM(views_principal),0) FROM gold.fato_serie_robos)
          - (SELECT COALESCE(SUM(views_principal),0) FROM silver.pageviews_diario_evento WHERE tipo_agente IN ('spider','automated')))::text,
           '0','soma de visitas dos robos: Gold menos Silver'
    UNION ALL SELECT 'B','B4',
           (SELECT COUNT(*) FROM silver.eventos s WHERE NOT EXISTS (SELECT 1 FROM gold.dim_evento g WHERE g.id_evento = s.id_evento))::text,
           '0','eventos da Silver ausentes na dim_evento'
    UNION ALL SELECT 'B','B5',
           (SELECT COUNT(*) FROM (SELECT id_evento, dia, tipo_agente FROM silver.pageviews_diario_evento GROUP BY 1,2,3 HAVING COUNT(views_principal) BETWEEN 1 AND 2) x)::text,
           '0','dias com soma parcial de acessos (premissa da soma dos tres acessos)'
),

-- ---------------------------------------------------------------------
-- GRUPO C: regras da camada
-- ---------------------------------------------------------------------
c AS (
    SELECT 'C' AS grupo, 'C1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE views_principal_tratado <> COALESCE(views_principal,0))::text AS valor,
           '0' AS esperado,
           'serie tratada diferente do COALESCE da original (regra de zero e nulo)' AS descricao
    UNION ALL SELECT 'C','C2',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE views_principal IS NULL)::text,
           '440','dias sem dado no publico na janela inteira'
    UNION ALL SELECT 'C','C3',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE views_principal IS NULL AND dias_desde_evento >= 0)::text,
           '11','dias sem dado no publico a partir do evento (D5 do gate da Silver)'
    UNION ALL SELECT 'C','C4',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE pct_pico_publico = 1)::text,
           '40','dias no pico do publico (um por evento)'
    UNION ALL SELECT 'C','C5',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE pct_pico_midia = 1)::text,
           '41','dias no pico da midia (41 por empate do ChatGPT nos dias 54 e 55)'
    UNION ALL SELECT 'C','C6',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE pct_pico_publico > 1 OR pct_pico_midia > 1 OR pct_pico_publico < 0 OR pct_pico_midia < 0)::text,
           '0','percentuais fora do intervalo de 0 a 1'
    UNION ALL SELECT 'C','C7',
           (SELECT COUNT(*) FROM gold.fato_serie_sensibilidade WHERE artigos_no_corte < 1)::text,
           '0','cortes sem nenhum artigo (o principal entra sempre)'
    UNION ALL SELECT 'C','C8',
           (SELECT COUNT(*) FROM gold.fato_serie_sensibilidade s JOIN gold.fato_serie_diaria d ON d.id_evento = s.id_evento AND d.dia = s.dia
             WHERE s.corte_amplificacao = 1.0 AND s.views_conjunto IS DISTINCT FROM d.views_conjunto)::text,
           '0','corte 1x divergente da serie diaria (dois caminhos de calculo independentes)'
    UNION ALL SELECT 'C','C9',
           (SELECT COUNT(*) FROM (
                SELECT id_evento FROM gold.fato_serie_sensibilidade GROUP BY id_evento
                 HAVING MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 1.0) < MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 5.0)) x)::text,
           '0','eventos com mais artigos no corte alto que no corte 1x'
    UNION ALL SELECT 'C','C10',
           (SELECT COUNT(*) FROM gold.fato_serie_robos WHERE views_principal_tratado <> COALESCE(views_principal,0))::text,
           '0','serie tratada dos robos diferente do COALESCE da original'
    UNION ALL SELECT 'C','C11',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_data d WHERE d.data = f.dia))::text,
           '0','dias da serie ausentes no calendario'
),

-- ---------------------------------------------------------------------
-- GRUPO D: metricas por evento
-- ---------------------------------------------------------------------
d AS (
    SELECT 'D' AS grupo, 'D1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE fonte = 'publico' AND base_valida)::text AS valor,
           '25' AS esperado,
           'eventos com linha de base valida no publico' AS descricao
    UNION ALL SELECT 'D','D2',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE fonte = 'midia' AND base_valida)::text,
           '26','eventos com linha de base valida na midia'
    UNION ALL SELECT 'D','D3',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE (base_valida AND amplificacao IS NULL) OR (NOT base_valida AND amplificacao IS NOT NULL))::text,
           '0','incoerencia entre base_valida e amplificacao'
    UNION ALL SELECT 'D','D4',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE base_motivo NOT IN ('ok','poucos_dias_com_dado','abaixo_do_piso','artigo_inexistente_antes'))::text,
           '0','motivos de base fora da lista prevista'
    UNION ALL SELECT 'D','D5',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE n_pontos_simples < 5 AND lambda_simples IS NOT NULL)::text,
           '0','ajustes com menos de 5 pontos que nao foram descartados'
    UNION ALL SELECT 'D','D6',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE meia_vida_simples IS NOT NULL AND (lambda_simples IS NULL OR lambda_simples <= 0))::text,
           '0','meia-vida calculada sem lambda positivo'
    UNION ALL SELECT 'D','D7',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE dia_pico NOT BETWEEN -30 AND 60)::text,
           '0','dia do pico fora da janela'
    UNION ALL SELECT 'D','D8',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento m JOIN gold.fato_serie_diaria f ON f.id_evento = m.id_evento AND f.dias_desde_evento = m.dia_pico
             WHERE m.fonte = 'publico' AND f.views_principal IS DISTINCT FROM m.valor_pico)::text,
           '0','pico do publico divergente da serie diaria'
    UNION ALL SELECT 'D','D9',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento m JOIN gold.fato_serie_diaria f ON f.id_evento = m.id_evento AND f.dias_desde_evento = m.dia_pico
             WHERE m.fonte = 'midia' AND f.materias IS DISTINCT FROM m.valor_pico)::text,
           '0','pico da midia divergente da serie diaria'
),

-- ---------------------------------------------------------------------
-- GRUPO E: correlacao cruzada
-- ---------------------------------------------------------------------
e AS (
    SELECT 'E' AS grupo, 'E1' AS checagem,
           (SELECT COUNT(*) FROM (SELECT id_evento, variante FROM gold.fato_correlacao_defasagem GROUP BY 1,2 HAVING COUNT(*) <> 21) x)::text AS valor,
           '0' AS esperado,
           'pares de evento e variante sem as 21 defasagens' AS descricao
    UNION ALL SELECT 'E','E2',
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem WHERE correlacao IS NULL)::text,
           '0','linhas sem correlacao calculada'
    UNION ALL SELECT 'E','E3',
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem WHERE correlacao NOT BETWEEN -1 AND 1)::text,
           '0','correlacoes fora do intervalo de -1 a 1'
    UNION ALL SELECT 'E','E4',
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem WHERE eh_significativa <> (abs(correlacao) > limite_critico))::text,
           '0','marca de significancia incoerente com a regua de 2 sobre a raiz de n'
    UNION ALL SELECT 'E','E5',
           (SELECT ROUND(correlacao,4) FROM gold.fato_correlacao_defasagem
             WHERE variante = 'nivel_log' AND defasagem = 0
               AND id_evento = (SELECT id_evento FROM gold.dim_evento WHERE nome_evento = 'Kobe Bryant'))::text,
           '0.9340','correlacao do Kobe na defasagem 0 (reproduz o piloto manual)'
    UNION ALL SELECT 'E','E6',
           (SELECT MAX(n_pares) FROM gold.fato_correlacao_defasagem)::text,
           '91','maior numero de pares (evento sem nenhum dia sem dado)'
    UNION ALL SELECT 'E','E7',
           (SELECT MIN(n_pares) FROM gold.fato_correlacao_defasagem)::text,
           '46','menor numero de pares (evento com mais dias sem artigo)'
    UNION ALL SELECT 'E','E8',
           (WITH artificial AS (
                SELECT g AS d,
                       CASE WHEN g < 0 THEN 1.0 ELSE 100.0 * exp(-0.5 * g) END           AS publico,
                       CASE WHEN g + 2 < 0 THEN 1.0 ELSE 100.0 * exp(-0.5 * (g + 2)) END AS midia
                FROM generate_series(-30, 60) g),
                correlograma AS (
                SELECT dd.k AS k, corr(x.publico, y.midia) AS r
                FROM (SELECT generate_series(-10, 10) AS k) dd
                CROSS JOIN artificial x
                JOIN artificial y ON y.d = x.d - dd.k
                GROUP BY dd.k)
            SELECT k FROM correlograma ORDER BY r DESC LIMIT 1)::text,
           '2','teste da convencao de sinal: serie artificial com a midia 2 dias a frente'
),

-- ---------------------------------------------------------------------
-- GRUPO F: leituras e coerencia entre tabelas
-- ---------------------------------------------------------------------
f AS (
    SELECT 'F' AS grupo, 'F1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND leitura = 'simultaneo')::text AS valor,
           '31' AS esperado,
           'eventos com leitura simultaneo (variante oficial)' AS descricao
    UNION ALL SELECT 'F','F2',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND leitura = 'midia_antes')::text,
           '1','eventos com a midia na frente (Furacao Ian)'
    UNION ALL SELECT 'F','F3',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND leitura = 'publico_antes')::text,
           '0','eventos com o publico na frente'
    UNION ALL SELECT 'F','F4',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND leitura = 'inicio_nao_observavel')::text,
           '3','eventos com artigo criado depois do evento (ChatGPT, RS e Maui)'
    UNION ALL SELECT 'F','F5',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND leitura = 'picos_distantes')::text,
           '3','eventos com picos a mais de 7 dias (COP28, COP30 e eleicao brasileira)'
    UNION ALL SELECT 'F','F6',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND leitura = 'inconclusivo')::text,
           '2','eventos inconclusivos (Galaxy S24 e Cybertruck)'
    UNION ALL SELECT 'F','F7',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d
             JOIN gold.fato_correlacao_defasagem c ON c.id_evento = d.id_evento AND c.variante = d.variante AND c.defasagem = d.defasagem_otima
            WHERE c.correlacao IS DISTINCT FROM d.correlacao_maxima)::text,
           '0','resumo divergente do correlograma de origem'
    UNION ALL SELECT 'F','F8',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d
             JOIN gold.fato_metricas_evento mp ON mp.id_evento = d.id_evento AND mp.fonte = 'publico'
             JOIN gold.fato_metricas_evento mm ON mm.id_evento = d.id_evento AND mm.fonte = 'midia'
            WHERE d.lag_por_pico <> mp.dia_pico - mm.dia_pico)::text,
           '0','distancia entre picos divergente das metricas por evento'
    UNION ALL SELECT 'F','F9',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d1
             JOIN gold.fato_defasagem_evento d2 ON d2.id_evento = d1.id_evento AND d2.variante = 'nivel_linear'
            WHERE d1.variante = 'nivel_log' AND d1.leitura <> d2.leitura)::text,
           '5','eventos com leitura diferente entre as duas variantes (sensibilidade)'
),

-- ---------------------------------------------------------------------
-- GRUPO V: informativos, nao bloqueiam
-- ---------------------------------------------------------------------
v AS (
    SELECT 'V' AS grupo, 'V1' AS checagem,
           (SELECT COUNT(*) FROM (
                SELECT id_evento, tipo_agente FROM gold.fato_serie_robos
                 GROUP BY 1,2 HAVING COALESCE(SUM(views_principal),0) = 0) x)::text AS valor,
           'qualquer' AS esperado,
           'curvas de robo inteiramente zeradas (sem pico, saem das medias)' AS descricao
    UNION ALL SELECT 'V','V2',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE meia_vida_observada IS NULL)::text,
           'qualquer','series que nao caem a metade do pico dentro da janela'
    UNION ALL SELECT 'V','V3',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento WHERE dias_ate_10pct IS NULL)::text,
           'qualquer','series que nao caem a 10% do pico dentro da janela'
    UNION ALL SELECT 'V','V4',
           (SELECT ROUND(AVG(r2_fase1)::numeric,3) FROM gold.fato_metricas_evento WHERE fonte = 'publico')::text,
           'qualquer','R2 medio da primeira fase no publico'
    UNION ALL SELECT 'V','V5',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento WHERE variante = 'nivel_log' AND NOT eh_significativa)::text,
           'qualquer','eventos cuja melhor correlacao nao e significativa'
),

todas AS (
    SELECT * FROM a UNION ALL SELECT * FROM b UNION ALL SELECT * FROM c
    UNION ALL SELECT * FROM d UNION ALL SELECT * FROM e UNION ALL SELECT * FROM f
    UNION ALL SELECT * FROM v
)

SELECT grupo,
       checagem,
       CASE WHEN esperado = 'qualquer' THEN 'INFO'
            WHEN valor IS NOT DISTINCT FROM esperado THEN 'OK'
            ELSE 'ALERTA' END AS status,
       valor,
       esperado,
       descricao
FROM todas;

\echo '================================ RESUMO DO GATE DA GOLD ================================'

SELECT grupo, checagem, status, valor, esperado, descricao
FROM resultado_gate
ORDER BY CASE status WHEN 'ALERTA' THEN 1 WHEN 'INFO' THEN 2 ELSE 3 END,
         grupo, checagem;

\echo ''
SELECT status, COUNT(*) AS checagens
FROM resultado_gate
GROUP BY status
ORDER BY status;

\echo ''
\echo '>>> panorama: leituras por categoria (variante oficial, nivel_log)'
SELECT e.categoria, d.leitura, COUNT(*) AS eventos
FROM gold.fato_defasagem_evento d
JOIN gold.dim_evento e ON e.id_evento = d.id_evento
WHERE d.variante = 'nivel_log'
GROUP BY 1,2
ORDER BY 1,2;

\echo ''
\echo '>>> divergencias entre as duas variantes (ver F9)'
SELECT d1.leitura AS leitura_log, d2.leitura AS leitura_linear, e.nome_evento
FROM gold.fato_defasagem_evento d1
JOIN gold.fato_defasagem_evento d2 ON d2.id_evento = d1.id_evento AND d2.variante = 'nivel_linear'
JOIN gold.dim_evento e ON e.id_evento = d1.id_evento
WHERE d1.variante = 'nivel_log' AND d1.leitura <> d2.leitura
ORDER BY 1,2,3;

\echo ''
\echo '>>> curvas de robo inteiramente zeradas (ver V1)'
SELECT e.nome_evento, r.tipo_agente
FROM gold.fato_serie_robos r
JOIN gold.dim_evento e ON e.id_evento = r.id_evento
GROUP BY e.nome_evento, r.tipo_agente
HAVING COALESCE(SUM(r.views_principal),0) = 0
ORDER BY 1,2;

\echo ''
\echo '>>> eventos sem base valida, com o motivo (ver D1 e D2)'
SELECT fonte, base_motivo, COUNT(*) AS eventos
FROM gold.fato_metricas_evento
WHERE NOT base_valida
GROUP BY 1,2
ORDER BY 1,3 DESC;

\echo ''
\echo '>>> series que nao caem a metade ou a 10% do pico (ver V2 e V3)'
SELECT e.nome_evento, m.fonte, m.dia_pico, m.meia_vida_observada, m.dias_ate_10pct
FROM gold.fato_metricas_evento m
JOIN gold.dim_evento e ON e.id_evento = m.id_evento
WHERE m.meia_vida_observada IS NULL OR m.dias_ate_10pct IS NULL
ORDER BY 1,2;

\echo ''
\echo '>>> panorama: meia-vida contada e ajustada, por fonte'
SELECT fonte,
       COUNT(*) AS eventos,
       ROUND(AVG(meia_vida_observada)::numeric,2) AS contada,
       ROUND(AVG(meia_vida_fase1)::numeric,2)     AS fase1,
       ROUND(AVG(meia_vida_simples)::numeric,2)   AS reta_unica,
       ROUND(AVG(r2_fase1)::numeric,3)            AS r2_fase1,
       ROUND(AVG(r2_simples)::numeric,3)          AS r2_simples
FROM gold.fato_metricas_evento
GROUP BY 1
ORDER BY 1;
