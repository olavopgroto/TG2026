-- =====================================================================
-- GATE DE AUDITORIA DA SILVER - 40 eventos (setembro de 2026)
--
-- Roda DEPOIS das cinco pipelines de carga da Silver.
-- So le dados: nao altera nenhuma tabela. A tabela gate_resultado e TEMP
-- e some sozinha no fim da sessao. Nao precisa de arquivo externo.
--
-- Os seis grupos:
--   A  contagem e integridade das seis tabelas
--   B  fidelidade a Bronze (a Silver nao pode perder nem inventar dado)
--   C  grade completa e regra de zero e nulo
--   D  agregacao por evento (as duas curvas)
--   E  cobertura midiatica
--   F  prontidao para a Gold
--
-- Status: OK = passou | FALHA = bloqueia a Gold | ALERTA = olhar, mas nao
-- bloqueia sozinho | INFO = so registro.
-- =====================================================================

CREATE TEMP TABLE gate_resultado (
    grupo TEXT, checagem TEXT, descricao TEXT, valor NUMERIC, esperado TEXT, status TEXT
);

-- =====================================================================
-- GRUPO A - contagem e integridade
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'A', 'A1', 'linhas em silver.eventos', COUNT(*), '40',
       CASE WHEN COUNT(*) = 40 THEN 'OK' ELSE 'FALHA' END FROM silver.eventos;

INSERT INTO gate_resultado
SELECT 'A', 'A2', 'linhas em silver.artigos', COUNT(*), '1424',
       CASE WHEN COUNT(*) = 1424 THEN 'OK' ELSE 'FALHA' END FROM silver.artigos;

INSERT INTO gate_resultado
SELECT 'A', 'A3', 'linhas em silver.pageviews_diario_artigo', COUNT(*), '1166256',
       CASE WHEN COUNT(*) = 1166256 THEN 'OK' ELSE 'FALHA' END FROM silver.pageviews_diario_artigo;

INSERT INTO gate_resultado
SELECT 'A', 'A4', 'linhas em silver.pageviews_diario_evento', COUNT(*), '32760',
       CASE WHEN COUNT(*) = 32760 THEN 'OK' ELSE 'FALHA' END FROM silver.pageviews_diario_evento;

INSERT INTO gate_resultado
SELECT 'A', 'A5', 'linhas em silver.cobertura_diaria_pais', COUNT(*), '36400',
       CASE WHEN COUNT(*) = 36400 THEN 'OK' ELSE 'FALHA' END FROM silver.cobertura_diaria_pais;

INSERT INTO gate_resultado
SELECT 'A', 'A6', 'linhas em silver.cobertura_diaria', COUNT(*), '3640',
       CASE WHEN COUNT(*) = 3640 THEN 'OK' ELSE 'FALHA' END FROM silver.cobertura_diaria;

INSERT INTO gate_resultado
SELECT 'A', 'A7', 'artigos com 35 titulos por evento (fora os aliases)', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_evento FROM silver.artigos WHERE alias_de IS NULL GROUP BY 1 HAVING COUNT(*) <> 35) x;

INSERT INTO gate_resultado
SELECT 'A', 'A8', 'linhas da grade com id_evento diferente do artigo', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo p JOIN silver.artigos a ON a.id_artigo = p.id_artigo
WHERE a.id_evento <> p.id_evento;

INSERT INTO gate_resultado
SELECT 'A', 'A9', 'aliases apontando para um principal inexistente no evento', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.artigos a
WHERE a.alias_de IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM silver.artigos p
                  WHERE p.id_evento = a.id_evento AND p.artigo = a.alias_de AND p.eh_principal);

INSERT INTO gate_resultado
SELECT 'A', 'A10', 'eventos sem exatamente um artigo principal', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_evento FROM silver.artigos WHERE eh_principal GROUP BY 1 HAVING COUNT(*) <> 1) x;

-- =====================================================================
-- GRUPO B - fidelidade a Bronze
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'B', 'B1', 'eventos divergentes da Bronze campo a campo', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.eventos s JOIN bronze.eventos_bruto b USING (nome_evento)
WHERE (s.categoria, s.data_evento, s.artigo_principal, s.palavra_chave_busca,
       s.data_inicio_extracao, s.data_fim_extracao)
   IS DISTINCT FROM
      (b.categoria, b.data_evento, b.artigo_wikipedia, b.palavra_chave_busca,
       b.data_inicio_extracao, b.data_fim_extracao);

INSERT INTO gate_resultado
SELECT 'B', 'B2', 'soma de visualizacoes: Silver menos Bronze',
       (SELECT COALESCE(SUM(visualizacoes), 0) FROM silver.pageviews_diario_artigo)
     - (SELECT COALESCE(SUM(visualizacoes), 0) FROM bronze.pageviews_bruto), '0',
       CASE WHEN (SELECT COALESCE(SUM(visualizacoes), 0) FROM silver.pageviews_diario_artigo)
               = (SELECT COALESCE(SUM(visualizacoes), 0) FROM bronze.pageviews_bruto)
            THEN 'OK' ELSE 'FALHA' END;

INSERT INTO gate_resultado
SELECT 'B', 'B3', 'linhas com origem api menos linhas da Bronze',
       (SELECT COUNT(*) FROM silver.pageviews_diario_artigo WHERE origem_valor = 'api')
     - (SELECT COUNT(*) FROM bronze.pageviews_bruto), '0',
       CASE WHEN (SELECT COUNT(*) FROM silver.pageviews_diario_artigo WHERE origem_valor = 'api')
               = (SELECT COUNT(*) FROM bronze.pageviews_bruto)
            THEN 'OK' ELSE 'FALHA' END;

INSERT INTO gate_resultado
SELECT 'B', 'B4', 'artigos da Bronze ausentes em silver.artigos', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT DISTINCT evento_referencia, artigo FROM bronze.pageviews_bruto) b
LEFT JOIN silver.eventos e ON e.nome_evento = b.evento_referencia
LEFT JOIN silver.artigos a ON a.id_evento = e.id_evento AND a.artigo = b.artigo
WHERE a.id_artigo IS NULL;

INSERT INTO gate_resultado
SELECT 'B', 'B5', 'pares evento x pais com soma de materias divergente da Bronze', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT c.evento_referencia, c.pais_cobertura, SUM((x->>'count')::int) AS soma
      FROM bronze.cobertura_midia_bruto c CROSS JOIN LATERAL jsonb_array_elements(c.payload) x
      GROUP BY 1, 2) b
JOIN silver.eventos e ON e.nome_evento = b.evento_referencia
JOIN (SELECT id_evento, pais_cobertura, SUM(materias) AS soma
      FROM silver.cobertura_diaria_pais GROUP BY 1, 2) s
  ON s.id_evento = e.id_evento AND s.pais_cobertura = b.pais_cobertura
WHERE b.soma <> s.soma;

INSERT INTO gate_resultado
SELECT 'B', 'B6', 'artigos sem nenhum dado da API na janela inteira', COUNT(*), '1 (principal do Marrocos)',
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'ALERTA' END
FROM (SELECT id_artigo FROM silver.pageviews_diario_artigo
      GROUP BY 1 HAVING COUNT(*) FILTER (WHERE origem_valor = 'api') = 0) x;

-- =====================================================================
-- GRUPO C - grade completa e regra de zero e nulo
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'C', 'C1', 'artigos sem as 819 linhas da grade (91 dias x 9 combinacoes)', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_artigo FROM silver.pageviews_diario_artigo GROUP BY 1 HAVING COUNT(*) <> 819) x;

INSERT INTO gate_resultado
SELECT 'C', 'C2', 'combinacoes de acesso e agente fora das 9 esperadas', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo
WHERE tipo_acesso NOT IN ('desktop', 'mobile-app', 'mobile-web')
   OR tipo_agente NOT IN ('user', 'spider', 'automated');

INSERT INTO gate_resultado
SELECT 'C', 'C3', 'linhas com origem api e valor nulo, ou o contrario', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo
WHERE (origem_valor = 'api' AND visualizacoes IS NULL)
   OR (origem_valor <> 'api' AND visualizacoes IS NOT NULL);

INSERT INTO gate_resultado
SELECT 'C', 'C4', 'linhas ausente_antes_criacao com dia depois da criacao', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo p JOIN silver.artigos a USING (id_artigo)
WHERE p.origem_valor = 'ausente_antes_criacao'
  AND (a.data_criacao IS NULL OR p.dia >= a.data_criacao);

INSERT INTO gate_resultado
SELECT 'C', 'C5', 'linhas ausente_pos_criacao com dia antes da criacao', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo p JOIN silver.artigos a USING (id_artigo)
WHERE p.origem_valor = 'ausente_pos_criacao'
  AND a.data_criacao IS NOT NULL AND p.dia < a.data_criacao;

INSERT INTO gate_resultado
SELECT 'C', 'C6', 'zeros explicitos vindos da API (prova da regra zero x nulo)', COUNT(*), '> 0',
       CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo WHERE origem_valor = 'api' AND visualizacoes = 0;

INSERT INTO gate_resultado
SELECT 'C', 'C7', 'linhas com dias_desde_evento incoerente com a data', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo p JOIN silver.eventos e USING (id_evento)
WHERE p.dias_desde_evento <> (p.dia - e.data_evento);

INSERT INTO gate_resultado
SELECT 'C', 'C8', 'linhas fora da janela de 30 dias antes e 60 depois', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo
WHERE dias_desde_evento < -30 OR dias_desde_evento > 60;

INSERT INTO gate_resultado
SELECT 'C', 'C9', 'linhas com visualizacoes negativas', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_artigo WHERE visualizacoes < 0;

-- =====================================================================
-- GRUPO D - agregacao por evento
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'D', 'D1', 'soma da curva do conjunto menos a soma da grade',
       (SELECT COALESCE(SUM(views_conjunto), 0) FROM silver.pageviews_diario_evento)
     - (SELECT COALESCE(SUM(visualizacoes), 0) FROM silver.pageviews_diario_artigo), '0',
       CASE WHEN (SELECT COALESCE(SUM(views_conjunto), 0) FROM silver.pageviews_diario_evento)
               = (SELECT COALESCE(SUM(visualizacoes), 0) FROM silver.pageviews_diario_artigo)
            THEN 'OK' ELSE 'FALHA' END;

INSERT INTO gate_resultado
SELECT 'D', 'D2', 'linhas com views_principal diferente do recalculo', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_evento v
JOIN (SELECT p.id_evento, p.dia, p.tipo_acesso, p.tipo_agente,
             SUM(p.visualizacoes) FILTER (WHERE a.eh_principal OR a.alias_de IS NOT NULL) AS principal,
             SUM(p.visualizacoes) AS conjunto,
             COUNT(p.visualizacoes) AS com_dado
      FROM silver.pageviews_diario_artigo p JOIN silver.artigos a USING (id_artigo)
      GROUP BY 1, 2, 3, 4) r
  ON r.id_evento = v.id_evento AND r.dia = v.dia
 AND r.tipo_acesso = v.tipo_acesso AND r.tipo_agente = v.tipo_agente
WHERE v.views_principal IS DISTINCT FROM r.principal;

INSERT INTO gate_resultado
SELECT 'D', 'D3', 'linhas com views_conjunto ou artigos_com_dado diferentes do recalculo', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_evento v
JOIN (SELECT p.id_evento, p.dia, p.tipo_acesso, p.tipo_agente,
             SUM(p.visualizacoes) AS conjunto, COUNT(p.visualizacoes) AS com_dado
      FROM silver.pageviews_diario_artigo p
      GROUP BY 1, 2, 3, 4) r
  ON r.id_evento = v.id_evento AND r.dia = v.dia
 AND r.tipo_acesso = v.tipo_acesso AND r.tipo_agente = v.tipo_agente
WHERE v.views_conjunto IS DISTINCT FROM r.conjunto
   OR v.artigos_com_dado IS DISTINCT FROM r.com_dado;

INSERT INTO gate_resultado
SELECT 'D', 'D4', 'eventos sem as 819 linhas agregadas', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_evento FROM silver.pageviews_diario_evento GROUP BY 1 HAVING COUNT(*) <> 819) x;

INSERT INTO gate_resultado
SELECT 'D', 'D5', 'dias sem dado no principal a partir do evento', COUNT(*), '99 (ChatGPT, RS e Maui)',
       CASE WHEN COUNT(*) = 99 THEN 'OK' ELSE 'ALERTA' END
FROM silver.pageviews_diario_evento
WHERE views_principal IS NULL AND dias_desde_evento >= 0;

INSERT INTO gate_resultado
SELECT 'D', 'D6', 'linhas com curva do principal maior que a do conjunto', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.pageviews_diario_evento
WHERE views_principal IS NOT NULL AND views_conjunto IS NOT NULL
  AND views_principal > views_conjunto;

-- =====================================================================
-- GRUPO E - cobertura midiatica
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'E', 'E1', 'eventos sem as 910 linhas por pais (10 x 91)', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_evento FROM silver.cobertura_diaria_pais GROUP BY 1 HAVING COUNT(*) <> 910) x;

INSERT INTO gate_resultado
SELECT 'E', 'E2', 'eventos sem os 91 dias na cobertura agregada', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_evento FROM silver.cobertura_diaria GROUP BY 1 HAVING COUNT(*) <> 91) x;

INSERT INTO gate_resultado
SELECT 'E', 'E3', 'linhas de cobertura com materias nulas ou negativas', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.cobertura_diaria_pais WHERE materias IS NULL OR materias < 0;

INSERT INTO gate_resultado
SELECT 'E', 'E4', 'linhas com materias acima do total do dia', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.cobertura_diaria_pais
WHERE materias_total IS NOT NULL AND materias > materias_total;

INSERT INTO gate_resultado
SELECT 'E', 'E5', 'linhas agregadas diferentes do recalculo por pais', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.cobertura_diaria c
JOIN (SELECT id_evento, dia, SUM(materias) AS materias,
             COUNT(*) FILTER (WHERE materias > 0) AS paises
      FROM silver.cobertura_diaria_pais GROUP BY 1, 2) r
  ON r.id_evento = c.id_evento AND r.dia = c.dia
WHERE c.materias IS DISTINCT FROM r.materias
   OR c.paises_com_materia IS DISTINCT FROM r.paises;

INSERT INTO gate_resultado
SELECT 'E', 'E6', 'linhas de cobertura com dias_desde_evento incoerente', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.cobertura_diaria_pais c JOIN silver.eventos e USING (id_evento)
WHERE c.dias_desde_evento <> (c.dia - e.data_evento);

INSERT INTO gate_resultado
SELECT 'E', 'E7', 'pares evento x pais sem nenhuma materia na janela', COUNT(*), '5 (China x4 e Alemanha x1)',
       CASE WHEN COUNT(*) = 5 THEN 'OK' ELSE 'ALERTA' END
FROM (SELECT id_evento, pais_cobertura FROM silver.cobertura_diaria_pais
      GROUP BY 1, 2 HAVING SUM(materias) = 0) x;

-- =====================================================================
-- GRUPO F - prontidao para a Gold
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'F', 'F1', 'eventos sem nenhuma materia na janela inteira', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT id_evento FROM silver.cobertura_diaria GROUP BY 1 HAVING SUM(materias) = 0) x;

INSERT INTO gate_resultado
SELECT 'F', 'F2', 'eventos sem curva de atencao publica (agente user)', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM silver.eventos e
WHERE NOT EXISTS (SELECT 1 FROM silver.pageviews_diario_evento v
                  WHERE v.id_evento = e.id_evento AND v.tipo_agente = 'user'
                    AND v.views_principal > 0);

INSERT INTO gate_resultado
SELECT 'F', 'F3', 'eventos cujo pico de atencao cai ANTES do dia do evento', COUNT(*), '0 ou poucos',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ALERTA' END
FROM (SELECT id_evento, (ARRAY_AGG(dias_desde_evento ORDER BY total DESC NULLS LAST))[1] AS dia_pico
      FROM (SELECT id_evento, dias_desde_evento, SUM(views_principal) AS total
            FROM silver.pageviews_diario_evento WHERE tipo_agente = 'user'
            GROUP BY 1, 2) d
      GROUP BY 1) p
WHERE dia_pico < 0;

INSERT INTO gate_resultado
SELECT 'F', 'F4', 'eventos com menos de 30 dias de cobertura no periodo pos-evento', COUNT(*), '0 ou poucos',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ALERTA' END
FROM (SELECT id_evento FROM silver.cobertura_diaria
      WHERE dias_desde_evento >= 0 AND materias > 0
      GROUP BY 1 HAVING COUNT(*) < 30) x;

INSERT INTO gate_resultado
SELECT 'F', 'F5', 'razao entre o pico e a base menor que 2x na atencao publica', COUNT(*), 'ate 4 (eleicoes e cupulas)',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ALERTA' END
FROM (SELECT id_evento,
             MAX(total) FILTER (WHERE dias_desde_evento BETWEEN 0 AND 14) AS pico,
             AVG(total) FILTER (WHERE dias_desde_evento < 0) AS base
      FROM (SELECT id_evento, dias_desde_evento, SUM(views_principal) AS total
            FROM silver.pageviews_diario_evento WHERE tipo_agente = 'user'
            GROUP BY 1, 2) d
      GROUP BY 1) x
WHERE base > 0 AND pico / base < 2;

-- =====================================================================
-- RESUMO
-- =====================================================================
\qecho ''
\qecho '=============================== RESUMO DO GATE DA SILVER ==============================='
SELECT grupo, checagem, status, valor, esperado, descricao
FROM gate_resultado
ORDER BY CASE status WHEN 'FALHA' THEN 1 WHEN 'ALERTA' THEN 2 WHEN 'OK' THEN 3 ELSE 4 END, checagem;

SELECT status, COUNT(*) AS checagens FROM gate_resultado GROUP BY status ORDER BY status;

-- =====================================================================
-- DETALHES (so aparecem linhas quando existe o caso)
-- =====================================================================
\qecho ''
\qecho '>>> B6: artigos sem nenhum dado da API na janela'
SELECT e.nome_evento, a.artigo, a.eh_principal, a.alias_de
FROM silver.artigos a JOIN silver.eventos e USING (id_evento)
WHERE NOT EXISTS (SELECT 1 FROM silver.pageviews_diario_artigo p
                  WHERE p.id_artigo = a.id_artigo AND p.origem_valor = 'api')
ORDER BY 1, 2;

\qecho '>>> D5: eventos com dias sem dado no principal a partir do evento'
SELECT e.nome_evento, COUNT(*) / 9 AS dias, MIN(v.dia) AS de, MAX(v.dia) AS ate
FROM silver.pageviews_diario_evento v JOIN silver.eventos e USING (id_evento)
WHERE v.views_principal IS NULL AND v.dias_desde_evento >= 0
GROUP BY 1 ORDER BY 2 DESC;

\qecho '>>> E7: pares evento x pais sem nenhuma materia'
SELECT e.nome_evento, c.pais_cobertura
FROM silver.cobertura_diaria_pais c JOIN silver.eventos e USING (id_evento)
GROUP BY 1, 2 HAVING SUM(c.materias) = 0 ORDER BY 1, 2;

\qecho '>>> F3: dia do pico de atencao publica por evento (agente user)'
SELECT e.categoria, e.nome_evento, p.dia_pico, p.pico
FROM (SELECT id_evento,
             (ARRAY_AGG(dias_desde_evento ORDER BY total DESC NULLS LAST))[1] AS dia_pico,
             MAX(total) AS pico
      FROM (SELECT id_evento, dias_desde_evento, SUM(views_principal) AS total
            FROM silver.pageviews_diario_evento WHERE tipo_agente = 'user'
            GROUP BY 1, 2) d
      GROUP BY 1) p
JOIN silver.eventos e USING (id_evento)
ORDER BY 1, 3, 2;

\qecho '>>> F5: amplificacao da atencao publica por evento (pico sobre base)'
SELECT e.categoria, e.nome_evento, ROUND(x.base) AS base_diaria,
       x.pico, ROUND(x.pico / NULLIF(x.base, 0), 1) AS amplificacao
FROM (SELECT id_evento,
             MAX(total) FILTER (WHERE dias_desde_evento BETWEEN 0 AND 14) AS pico,
             AVG(total) FILTER (WHERE dias_desde_evento < 0) AS base
      FROM (SELECT id_evento, dias_desde_evento, SUM(views_principal) AS total
            FROM silver.pageviews_diario_evento WHERE tipo_agente = 'user'
            GROUP BY 1, 2) d
      GROUP BY 1) x
JOIN silver.eventos e USING (id_evento)
ORDER BY 5 NULLS LAST;

\qecho '>>> panorama: volume por categoria'
SELECT e.categoria,
       SUM(v.views_principal) FILTER (WHERE v.tipo_agente = 'user') AS views_principal_user,
       SUM(v.views_conjunto)  FILTER (WHERE v.tipo_agente = 'user') AS views_conjunto_user,
       (SELECT SUM(c.materias) FROM silver.cobertura_diaria c
        JOIN silver.eventos e2 USING (id_evento) WHERE e2.categoria = e.categoria) AS materias
FROM silver.pageviews_diario_evento v JOIN silver.eventos e USING (id_evento)
GROUP BY 1 ORDER BY 1;
