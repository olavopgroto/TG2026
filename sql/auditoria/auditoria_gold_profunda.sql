-- =====================================================================
-- AUDITORIA PROFUNDA DA CAMADA GOLD
-- Arquivo: sql/auditoria/auditoria_gold_profunda.sql
--
-- Complementa o gate_gold.sql. A diferenca e o principio:
--
--   o gate pergunta  "o numero gravado e o que esperavamos?"
--   esta pergunta    "se eu refizer a conta do zero, por outro caminho,
--                     da o mesmo numero?"
--
-- Quase toda checagem aqui RECALCULA a metrica a partir da Silver ou da
-- serie diaria e compara, linha a linha, com o que a pipeline gravou.
-- Um resultado diferente de zero significa que a pipeline e o recalculo
-- discordam, e ai um dos dois esta errado.
--
-- Comparacoes de numero quebrado usam tolerancia de 0,000001, porque
-- ponto flutuante nao fecha exato na casa decimal final.
--
-- NOTA: as checagens K5 e L3 foram reescritas depois da primeira execucao.
-- A versao original usava GROUP BY com HAVING dentro de uma subconsulta
-- escalar, que devolve vazio em vez de zero quando nada viola a condicao,
-- e o vazio era reportado como ALERTA. O dado estava correto; a checagem
-- e que estava mal escrita.
--
-- Como rodar:
--   docker cp sql/auditoria/auditoria_gold_profunda.sql tcc_postgres:/tmp/aud.sql
--   docker exec tcc_postgres psql -U tcc -d tcc_wikipedia -q -f /tmp/aud.sql -o /tmp/resultado.txt
--   docker cp tcc_postgres:/tmp/resultado.txt tmp/resultado_auditoria_gold.txt
-- =====================================================================

\pset border 2

CREATE TEMP TABLE aud AS
WITH

-- =====================================================================
-- GRUPO R: a serie diaria recalculada a partir da Silver
-- =====================================================================
serie_recalc AS (
    SELECT p.id_evento,
           p.dia,
           p.dias_desde_evento,
           SUM(p.views_principal)::bigint AS views_principal,
           SUM(p.views_conjunto)::bigint  AS views_conjunto,
           MAX(p.artigos_com_dado)::int   AS artigos_com_dado
    FROM silver.pageviews_diario_evento p
    WHERE p.tipo_agente = 'user'
    GROUP BY p.id_evento, p.dia, p.dias_desde_evento
),
pico_recalc AS (
    SELECT DISTINCT ON (id_evento)
           id_evento,
           views_principal   AS pico,
           dias_desde_evento AS dia_pico
    FROM serie_recalc
    WHERE views_principal IS NOT NULL
    ORDER BY id_evento, views_principal DESC NULLS LAST, dias_desde_evento
),
r AS (
    SELECT 'R' AS grupo, 'R1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             FULL JOIN serie_recalc s ON s.id_evento = g.id_evento AND s.dia = g.dia
            WHERE g.id_evento IS NULL OR s.id_evento IS NULL)::text AS valor,
           '0' AS esperado,
           'linhas que existem em um lado e nao no outro (Gold contra recalculo da Silver)' AS descricao
    UNION ALL SELECT 'R','R2',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN serie_recalc s ON s.id_evento = g.id_evento AND s.dia = g.dia
            WHERE g.views_principal IS DISTINCT FROM s.views_principal)::text,
           '0','visitas do publico divergentes do recalculo'
    UNION ALL SELECT 'R','R3',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN serie_recalc s ON s.id_evento = g.id_evento AND s.dia = g.dia
            WHERE g.views_conjunto IS DISTINCT FROM s.views_conjunto)::text,
           '0','visitas do conjunto divergentes do recalculo'
    UNION ALL SELECT 'R','R4',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN serie_recalc s ON s.id_evento = g.id_evento AND s.dia = g.dia
            WHERE g.artigos_com_dado IS DISTINCT FROM s.artigos_com_dado)::text,
           '0','contagem de artigos com dado divergente do recalculo'
    UNION ALL SELECT 'R','R5',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN silver.cobertura_diaria s ON s.id_evento = g.id_evento AND s.dia = g.dia
            WHERE g.materias IS DISTINCT FROM s.materias
               OR g.paises_com_materia IS DISTINCT FROM s.paises_com_materia)::text,
           '0','cobertura divergente da Silver'
    UNION ALL SELECT 'R','R6',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN pico_recalc p ON p.id_evento = g.id_evento
            WHERE g.views_principal IS NOT NULL
              AND abs(g.pct_pico_publico - (g.views_principal::numeric / p.pico)) > 0.000001)::text,
           '0','percentual do pico do publico divergente do recalculo'
    UNION ALL SELECT 'R','R7',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN pico_recalc p ON p.id_evento = g.id_evento
            WHERE g.dias_desde_pico_publico <> g.dias_desde_evento - p.dia_pico)::text,
           '0','dias desde o pico do publico divergentes do recalculo'
    UNION ALL SELECT 'R','R8',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN gold.dim_evento e ON e.id_evento = g.id_evento
            WHERE g.dias_desde_evento <> (g.dia - e.data_evento))::text,
           '0','dias desde o evento incoerentes com a data de calendario'
    UNION ALL SELECT 'R','R9',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN gold.dim_evento e ON e.id_evento = g.id_evento
            WHERE g.dia NOT BETWEEN e.data_inicio_janela AND e.data_fim_janela)::text,
           '0','dias fora da janela registrada no evento'
    UNION ALL SELECT 'R','R10',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria WHERE materias = 0 AND paises_com_materia <> 0)::text,
           '0','dias sem materia mas com paises contados'
    UNION ALL SELECT 'R','R11',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria g
             JOIN gold.dim_evento e ON e.id_evento = g.id_evento
            WHERE g.artigos_com_dado > e.qtd_artigos + e.qtd_aliases)::text,
           '0','mais artigos com dado do que o evento tem'
    UNION ALL SELECT 'R','R12',
           (SELECT COUNT(*) FROM gold.fato_serie_robos g
             JOIN (SELECT id_evento, dia, tipo_agente, SUM(views_principal)::bigint AS v
                     FROM silver.pageviews_diario_evento
                    WHERE tipo_agente IN ('spider','automated')
                    GROUP BY 1,2,3) s
               ON s.id_evento = g.id_evento AND s.dia = g.dia AND s.tipo_agente = g.tipo_agente
            WHERE g.views_principal IS DISTINCT FROM s.v)::text,
           '0','curva dos robos divergente do recalculo, por agente'
),

-- =====================================================================
-- GRUPO S: sensibilidade
-- =====================================================================
s AS (
    SELECT 'S' AS grupo, 'S1' AS checagem,
           (SELECT COUNT(*) FROM (
                SELECT id_evento, dia
                FROM gold.fato_serie_sensibilidade
                GROUP BY id_evento, dia
                HAVING MAX(views_conjunto) FILTER (WHERE corte_amplificacao = 1.0)
                     < MAX(views_conjunto) FILTER (WHERE corte_amplificacao = 2.0)
                    OR MAX(views_conjunto) FILTER (WHERE corte_amplificacao = 2.0)
                     < MAX(views_conjunto) FILTER (WHERE corte_amplificacao = 3.0)
                    OR MAX(views_conjunto) FILTER (WHERE corte_amplificacao = 3.0)
                     < MAX(views_conjunto) FILTER (WHERE corte_amplificacao = 5.0)) x)::text AS valor,
           '0' AS esperado,
           'dias em que um corte mais rigoroso tem MAIS visitas que um mais frouxo' AS descricao
    UNION ALL SELECT 'S','S2',
           (SELECT COUNT(*) FROM (
                SELECT id_evento
                FROM gold.fato_serie_sensibilidade
                GROUP BY id_evento
                HAVING MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 1.0)
                     < MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 2.0)
                    OR MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 2.0)
                     < MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 3.0)
                    OR MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 3.0)
                     < MAX(artigos_no_corte) FILTER (WHERE corte_amplificacao = 5.0)) x)::text,
           '0','eventos em que um corte mais rigoroso mantem MAIS artigos'
    UNION ALL SELECT 'S','S3',
           (SELECT COUNT(*) FROM (
                SELECT s.id_evento, s.corte_amplificacao, MAX(s.artigos_no_corte) AS gravado,
                       (SELECT COUNT(*) FROM silver.artigos a
                         WHERE a.id_evento = s.id_evento
                           AND (s.corte_amplificacao = 1.0 OR a.eh_principal OR a.alias_de IS NOT NULL
                                OR (a.razao_amplificacao IS NOT NULL AND a.razao_amplificacao >= s.corte_amplificacao))) AS recalculado
                FROM gold.fato_serie_sensibilidade s
                GROUP BY s.id_evento, s.corte_amplificacao) x
            WHERE gravado <> recalculado)::text,
           '0','contagem de artigos por corte divergente do recalculo pela regra'
    UNION ALL SELECT 'S','S4',
           (SELECT COUNT(*) FROM (
                SELECT id_evento, dia FROM gold.vw_sensibilidade_larga
                 WHERE views_1x IS DISTINCT FROM (SELECT views_conjunto FROM gold.fato_serie_sensibilidade f
                                                   WHERE f.id_evento = gold.vw_sensibilidade_larga.id_evento
                                                     AND f.dia = gold.vw_sensibilidade_larga.dia
                                                     AND f.corte_amplificacao = 1.0)) x)::text,
           '0','view larga divergente da tabela longa'
    UNION ALL SELECT 'S','S5',
           (SELECT COUNT(*) FROM gold.vw_sensibilidade_larga)::text,
           '3640','linhas na view larga (uma por evento e dia)'
),

-- =====================================================================
-- GRUPO M: metricas por evento recalculadas
-- =====================================================================
longa AS (
    SELECT id_evento, 'publico'::varchar(20) AS fonte, dias_desde_evento AS d,
           dias_desde_pico_publico AS dp, views_principal::double precision AS valor
    FROM gold.fato_serie_diaria
    UNION ALL
    SELECT id_evento, 'midia'::varchar(20), dias_desde_evento,
           dias_desde_pico_midia, materias::double precision
    FROM gold.fato_serie_diaria
),
m_recalc AS (
    SELECT l.id_evento, l.fonte,
           COALESCE(SUM(l.valor) FILTER (WHERE l.d BETWEEN 0 AND 29), 0)::bigint AS volume_30d,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.valor) FILTER (WHERE l.d BETWEEN -30 AND -4) AS base_mediana,
           COUNT(l.valor) FILTER (WHERE l.d BETWEEN -30 AND -4)::int AS base_dias,
           regr_slope(LN(NULLIF(GREATEST(l.valor, 0), 0)), l.dp) FILTER (WHERE l.dp >= 0) AS slope,
           COUNT(*) FILTER (WHERE l.dp >= 0 AND l.valor > 0)::int AS n_simples
    FROM longa l
    GROUP BY l.id_evento, l.fonte
),
m AS (
    SELECT 'M' AS grupo, 'M1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN m_recalc r ON r.id_evento = g.id_evento AND r.fonte = g.fonte
            WHERE g.volume_30d <> r.volume_30d)::text AS valor,
           '0' AS esperado,
           'volume de 30 dias divergente do recalculo' AS descricao
    UNION ALL SELECT 'M','M2',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN m_recalc r ON r.id_evento = g.id_evento AND r.fonte = g.fonte
            WHERE abs(COALESCE(g.base_mediana,-1) - COALESCE(r.base_mediana,-1)) > 0.000001)::text,
           '0','mediana da base divergente do recalculo'
    UNION ALL SELECT 'M','M3',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN m_recalc r ON r.id_evento = g.id_evento AND r.fonte = g.fonte
            WHERE g.base_dias_com_dado <> r.base_dias)::text,
           '0','dias com dado na base divergentes do recalculo'
    UNION ALL SELECT 'M','M4',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN m_recalc r ON r.id_evento = g.id_evento AND r.fonte = g.fonte
            WHERE g.n_pontos_simples <> r.n_simples)::text,
           '0','numero de pontos do ajuste divergente do recalculo'
    UNION ALL SELECT 'M','M5',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN m_recalc r ON r.id_evento = g.id_evento AND r.fonte = g.fonte
            WHERE g.lambda_simples IS NOT NULL
              AND abs(g.lambda_simples - (-r.slope)) > 0.000001)::text,
           '0','lambda divergente do recalculo da regressao'
    UNION ALL SELECT 'M','M6',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento
             WHERE meia_vida_simples IS NOT NULL
               AND abs(meia_vida_simples - (ln(2) / lambda_simples)) > 0.01)::text,
           '0','meia-vida divergente de ln(2) dividido por lambda'
    UNION ALL SELECT 'M','M7',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento
             WHERE amplificacao IS NOT NULL
               AND abs(amplificacao - (valor_pico::numeric / base_mediana)) > 0.01)::text,
           '0','amplificacao divergente de pico dividido por base'
    UNION ALL SELECT 'M','M8',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN LATERAL (
                SELECT MIN(l.dp) AS mv
                FROM longa l
                WHERE l.id_evento = g.id_evento AND l.fonte = g.fonte
                  AND l.dp > 0 AND l.valor < g.valor_pico * 0.5) x ON true
            WHERE g.meia_vida_observada IS DISTINCT FROM x.mv)::text,
           '0','meia-vida contada divergente do recalculo'
    UNION ALL SELECT 'M','M9',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento g
             JOIN LATERAL (
                SELECT MIN(l.dp) AS d10
                FROM longa l
                WHERE l.id_evento = g.id_evento AND l.fonte = g.fonte
                  AND l.dp > 0 AND l.valor < g.valor_pico * 0.1) x ON true
            WHERE g.dias_ate_10pct IS DISTINCT FROM x.d10)::text,
           '0','dias ate 10% do pico divergentes do recalculo'
    UNION ALL SELECT 'M','M10',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento
             WHERE base_valida <> (base_dias_com_dado >= 14
                                   AND base_mediana IS NOT NULL
                                   AND base_mediana >= CASE WHEN fonte = 'publico' THEN 10 ELSE 1 END))::text,
           '0','validade da base divergente da regra escrita'
    UNION ALL SELECT 'M','M11',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento
             WHERE r2_combinado_fases IS NOT NULL
               AND abs(r2_combinado_fases
                     - ((r2_fase1 * n_pontos_fase1 + r2_fase2 * n_pontos_fase2)
                        / NULLIF(n_pontos_fase1 + n_pontos_fase2, 0))) > 0.001)::text,
           '0','R2 combinado divergente da media ponderada das duas fases'
    UNION ALL SELECT 'M','M12',
           (SELECT COUNT(*) FROM gold.fato_metricas_evento
             WHERE ganho_r2_sobre_simples IS NOT NULL
               AND abs(ganho_r2_sobre_simples - (r2_combinado_fases - r2_simples)) > 0.001)::text,
           '0','ganho de R2 divergente da subtracao'
),

-- =====================================================================
-- GRUPO K: correlacao recalculada
-- =====================================================================
k_recalc AS (
    SELECT a.id_evento, d.k AS defasagem,
           corr(a.pub, b.mid)                     AS r_linear,
           corr(ln(1 + a.pub), ln(1 + b.mid))     AS r_log,
           COUNT(a.pub)::int                      AS n_pares
    FROM (SELECT generate_series(-10, 10) AS k) d
    CROSS JOIN (SELECT id_evento, dias_desde_evento AS dd,
                       views_principal::double precision AS pub
                  FROM gold.fato_serie_diaria) a
    JOIN (SELECT id_evento, dias_desde_evento AS dd,
                 materias::double precision AS mid
            FROM gold.fato_serie_diaria) b
      ON b.id_evento = a.id_evento AND b.dd = a.dd - d.k
    GROUP BY a.id_evento, d.k
),
kk AS (
    SELECT 'K' AS grupo, 'K1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem g
             JOIN k_recalc r ON r.id_evento = g.id_evento AND r.defasagem = g.defasagem
            WHERE g.variante = 'nivel_log' AND abs(g.correlacao - r.r_log) > 0.000001)::text AS valor,
           '0' AS esperado,
           'correlacao em log divergente do recalculo, nas 840 linhas' AS descricao
    UNION ALL SELECT 'K','K2',
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem g
             JOIN k_recalc r ON r.id_evento = g.id_evento AND r.defasagem = g.defasagem
            WHERE g.variante = 'nivel_linear' AND abs(g.correlacao - r.r_linear) > 0.000001)::text,
           '0','correlacao linear divergente do recalculo, nas 840 linhas'
    UNION ALL SELECT 'K','K3',
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem g
             JOIN k_recalc r ON r.id_evento = g.id_evento AND r.defasagem = g.defasagem
            WHERE g.n_pares <> r.n_pares)::text,
           '0','numero de pares divergente do recalculo'
    UNION ALL SELECT 'K','K4',
           (SELECT COUNT(*) FROM gold.fato_correlacao_defasagem
             WHERE abs(limite_critico - (2.0 / sqrt(n_pares))) > 0.000001)::text,
           '0','limite critico divergente de 2 sobre a raiz de n'
    UNION ALL SELECT 'K','K5',
           (SELECT COUNT(*) FROM (
                SELECT c.n_pares,
                       (SELECT COUNT(f.views_principal) FROM gold.fato_serie_diaria f
                         WHERE f.id_evento = c.id_evento) AS dias_com_dado
                FROM gold.fato_correlacao_defasagem c
                WHERE c.defasagem = 0 AND c.variante = 'nivel_log') x
            WHERE x.n_pares <> x.dias_com_dado)::text,
           '0','pares na defasagem zero divergentes dos dias com dado'
    UNION ALL SELECT 'K','K6',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d
             JOIN LATERAL (
                SELECT c.defasagem, c.correlacao
                FROM gold.fato_correlacao_defasagem c
                WHERE c.id_evento = d.id_evento AND c.variante = d.variante
                ORDER BY c.correlacao DESC NULLS LAST, abs(c.defasagem), c.defasagem
                LIMIT 1) x ON true
            WHERE d.defasagem_otima <> x.defasagem)::text,
           '0','defasagem otima que nao e o maximo do proprio correlograma'
),

-- =====================================================================
-- GRUPO L: a regra da leitura, recalculada em SQL puro
-- (testa o transform do Hop contra uma implementacao independente)
-- =====================================================================
l_recalc AS (
    SELECT d.id_evento, d.variante,
           CASE
             WHEN e.data_criacao_principal > e.data_evento      THEN 'inicio_nao_observavel'
             WHEN abs(d.lag_por_pico) > 7                       THEN 'picos_distantes'
             WHEN NOT d.eh_significativa                        THEN 'inconclusivo'
             WHEN NOT d.concorda_com_lag_por_pico               THEN 'inconclusivo'
             WHEN abs(d.defasagem_otima) <= 1                   THEN 'simultaneo'
             WHEN d.defasagem_otima >= 2                        THEN 'midia_antes'
             ELSE 'publico_antes'
           END AS leitura_sql,
           CASE
             WHEN abs(d.defasagem_otima) <= 1 AND abs(d.lag_por_pico) <= 1 THEN true
             WHEN d.defasagem_otima >= 2 AND d.lag_por_pico >= 1           THEN true
             WHEN d.defasagem_otima <= -2 AND d.lag_por_pico <= -1         THEN true
             ELSE false
           END AS concorda_sql
    FROM gold.fato_defasagem_evento d
    JOIN gold.dim_evento e ON e.id_evento = d.id_evento
),
ll AS (
    SELECT 'L' AS grupo, 'L1' AS checagem,
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d
             JOIN l_recalc r ON r.id_evento = d.id_evento AND r.variante = d.variante
            WHERE d.leitura <> r.leitura_sql)::text AS valor,
           '0' AS esperado,
           'leitura do transform divergente da mesma regra escrita em SQL' AS descricao
    UNION ALL SELECT 'L','L2',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d
             JOIN l_recalc r ON r.id_evento = d.id_evento AND r.variante = d.variante
            WHERE d.concorda_com_lag_por_pico <> r.concorda_sql)::text,
           '0','marca de concordancia divergente da regra escrita em SQL'
    UNION ALL SELECT 'L','L3',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento d
             WHERE d.dias_nulos_publico <> (SELECT COUNT(*) FROM gold.fato_serie_diaria f
                                             WHERE f.id_evento = d.id_evento
                                               AND f.views_principal IS NULL))::text,
           '0','contagem de dias nulos divergente da serie diaria'
    UNION ALL SELECT 'L','L4',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento
             WHERE leitura = 'midia_antes' AND (defasagem_otima < 2 OR lag_por_pico < 1))::text,
           '0','leitura midia_antes sem as duas medidas apontando a imprensa'
    UNION ALL SELECT 'L','L5',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento
             WHERE leitura = 'publico_antes' AND (defasagem_otima > -2 OR lag_por_pico > -1))::text,
           '0','leitura publico_antes sem as duas medidas apontando o publico'
    UNION ALL SELECT 'L','L6',
           (SELECT COUNT(*) FROM gold.fato_defasagem_evento
             WHERE leitura = 'simultaneo' AND (abs(defasagem_otima) > 1 OR abs(lag_por_pico) > 1))::text,
           '0','leitura simultaneo fora da tolerancia de um dia'
),

-- =====================================================================
-- GRUPO X: dimensoes e coerencias gerais
-- =====================================================================
x AS (
    SELECT 'X' AS grupo, 'X1' AS checagem,
           (SELECT COUNT(*) FROM gold.dim_data
             WHERE ano <> EXTRACT(YEAR FROM data)
                OR mes <> EXTRACT(MONTH FROM data)
                OR dia <> EXTRACT(DAY FROM data)
                OR trimestre <> EXTRACT(QUARTER FROM data)
                OR dia_da_semana <> EXTRACT(DOW FROM data))::text AS valor,
           '0' AS esperado,
           'partes da data divergentes do calculo do banco' AS descricao
    UNION ALL SELECT 'X','X2',
           (SELECT COUNT(*) FROM gold.dim_data WHERE ano_mes <> to_char(data, 'YYYY-MM'))::text,
           '0','ano_mes divergente da data'
    UNION ALL SELECT 'X','X3',
           (SELECT COUNT(*) FROM gold.dim_data WHERE eh_fim_de_semana <> (EXTRACT(DOW FROM data) IN (0,6)))::text,
           '0','marca de fim de semana divergente do dia da semana'
    UNION ALL SELECT 'X','X4',
           (SELECT COUNT(*) FROM gold.dim_data d WHERE EXISTS (SELECT 1 FROM gold.dim_data o WHERE o.data = d.data AND o.ctid <> d.ctid))::text,
           '0','datas repetidas no calendario'
    UNION ALL SELECT 'X','X5',
           ((SELECT MAX(data) - MIN(data) + 1 FROM gold.dim_data) - (SELECT COUNT(*) FROM gold.dim_data))::text,
           '0','buracos no calendario (intervalo menos quantidade de linhas)'
    UNION ALL SELECT 'X','X6',
           (SELECT COUNT(*) FROM gold.dim_tempo_relativo
             WHERE semana_relativa <> FLOOR(dias_desde_evento::numeric / 7))::text,
           '0','semana relativa divergente do calculo'
    UNION ALL SELECT 'X','X7',
           (SELECT COUNT(*) FROM gold.dim_tempo_relativo
             WHERE fase <> CASE WHEN dias_desde_evento < 0 THEN 'pre_evento'
                                WHEN dias_desde_evento = 0 THEN 'dia_do_evento'
                                WHEN dias_desde_evento <= 7 THEN 'primeira_semana'
                                WHEN dias_desde_evento <= 30 THEN 'primeiro_mes'
                                ELSE 'cauda' END)::text,
           '0','fase divergente da regra'
    UNION ALL SELECT 'X','X8',
           (SELECT COUNT(*) FROM gold.dim_evento
             WHERE data_inicio_janela <> data_evento - 30 OR data_fim_janela <> data_evento + 60)::text,
           '0','janela do evento diferente de 30 antes e 60 depois'
    UNION ALL SELECT 'X','X9',
           (SELECT COUNT(*) FROM gold.dim_evento g
             JOIN (SELECT id_evento,
                          COUNT(*) FILTER (WHERE alias_de IS NULL) AS art,
                          COUNT(*) FILTER (WHERE alias_de IS NOT NULL) AS ali
                     FROM silver.artigos GROUP BY 1) s ON s.id_evento = g.id_evento
            WHERE g.qtd_artigos <> s.art OR g.qtd_aliases <> s.ali)::text,
           '0','contagem de artigos e aliases divergente da Silver'
    UNION ALL SELECT 'X','X10',
           (SELECT COUNT(*) FROM gold.dim_evento e
             WHERE NOT EXISTS (SELECT 1 FROM gold.fato_serie_diaria f WHERE f.id_evento = e.id_evento)
                OR NOT EXISTS (SELECT 1 FROM gold.fato_metricas_evento m WHERE m.id_evento = e.id_evento)
                OR NOT EXISTS (SELECT 1 FROM gold.fato_defasagem_evento d WHERE d.id_evento = e.id_evento))::text,
           '0','eventos ausentes em alguma tabela fato'
    UNION ALL SELECT 'X','X11',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria
             WHERE COALESCE(views_principal,0) < 0 OR COALESCE(views_conjunto,0) < 0 OR materias < 0)::text,
           '0','valores negativos na serie diaria'
    UNION ALL SELECT 'X','X12',
           (SELECT COUNT(*) FROM gold.fato_serie_diaria
             WHERE views_principal IS NOT NULL AND views_conjunto IS NOT NULL
               AND views_conjunto < views_principal)::text,
           '0','curva do conjunto menor que a do principal'
),

todas AS (
    SELECT * FROM r UNION ALL SELECT * FROM s UNION ALL SELECT * FROM m
    UNION ALL SELECT * FROM kk UNION ALL SELECT * FROM ll UNION ALL SELECT * FROM x
)

SELECT grupo, checagem,
       CASE WHEN valor IS NOT DISTINCT FROM esperado THEN 'OK' ELSE 'ALERTA' END AS status,
       valor, esperado, descricao
FROM todas;

\echo '=========================== AUDITORIA PROFUNDA DA GOLD ==========================='

SELECT grupo, checagem, status, valor, esperado, descricao
FROM aud
ORDER BY CASE status WHEN 'ALERTA' THEN 1 ELSE 2 END, grupo, checagem;

\echo ''
SELECT status, COUNT(*) AS checagens
FROM aud
GROUP BY status
ORDER BY status;
