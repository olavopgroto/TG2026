-- =====================================================================
-- GATE DE AUDITORIA DA BRONZE - 40 EVENTOS (revisado em 21/09/2026)
--
-- Roda DEPOIS da carga dos tres workflows (eventos, cobertura, pageviews).
-- So le dados: nao altera nenhuma tabela. As tabelas gate_* sao TEMP e
-- somem sozinhas no fim da sessao.
--
-- Precisa do artigos_metadados.csv copiado para /tmp dentro do container
-- (lista oficial de artigos, aliases e datas de criacao).
--
-- Mudancas em relacao ao gate original:
--   B2  dia faltando deixou de ser erro: com a regra nova, linha ausente
--       e NULO. O gate agora separa dia faltando EXPLICADO (antes da
--       criacao do artigo) de NAO EXPLICADO (depois da criacao).
--   D1  ignora dias com zero: a API devolve 0 explicito, entao user,
--       spider e automated iguais a 0 no mesmo dia e normal.
--   C4  novo: confere os aliases do artigo principal.
--
-- Status: OK = passou | FALHA = bloqueia a Silver | ALERTA = olhar,
-- mas nao bloqueia sozinho | INFO = so registro.
-- =====================================================================

\qecho '>>> carregando a lista oficial de artigos (artigos_metadados.csv)'
CREATE TEMP TABLE gate_meta (
    nome_evento TEXT, categoria TEXT, artigo_wikipedia TEXT, eh_principal TEXT,
    alias_de TEXT, posicao_ranking TEXT, media_base TEXT, media_pico TEXT,
    razao_amplificacao TEXT, data_criacao TEXT, primeiro_dia_com_views TEXT
);
COPY gate_meta FROM '/tmp/artigos_metadados.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

CREATE TEMP TABLE gate_resultado (
    gate TEXT, checagem TEXT, descricao TEXT, valor NUMERIC, esperado TEXT, status TEXT
);

-- ---------------------------------------------------------------------
-- base de apoio: pageviews com data convertida, e grade esperada de dias
-- ---------------------------------------------------------------------
CREATE TEMP TABLE gate_pv AS
SELECT evento_referencia, artigo, tipo_acesso, tipo_agente, visualizacoes,
       to_date(left(timestamp_bruto, 8), 'YYYYMMDD') AS dia
FROM bronze.pageviews_bruto;
CREATE INDEX ON gate_pv (evento_referencia, artigo, tipo_acesso, tipo_agente, dia);

CREATE TEMP TABLE gate_grade AS
SELECT m.nome_evento, m.artigo_wikipedia AS artigo,
       (m.eh_principal = 'True') AS eh_principal, NULLIF(m.alias_de, '') AS alias_de,
       NULLIF(m.data_criacao, '')::date AS data_criacao, e.data_fim_extracao,
       a.acesso, g.agente, d::date AS dia
FROM gate_meta m
JOIN bronze.eventos_bruto e ON e.nome_evento = m.nome_evento
CROSS JOIN (VALUES ('desktop'), ('mobile-app'), ('mobile-web')) a(acesso)
CROSS JOIN (VALUES ('user'), ('spider'), ('automated')) g(agente)
CROSS JOIN LATERAL generate_series(e.data_inicio_extracao, e.data_fim_extracao, INTERVAL '1 day') d;

CREATE TEMP TABLE gate_faltas AS
SELECT g.*, (g.dia < g.data_criacao) AS antes_da_criacao
FROM gate_grade g
LEFT JOIN gate_pv p
  ON p.evento_referencia = g.nome_evento AND p.artigo = g.artigo
 AND p.tipo_acesso = g.acesso AND p.tipo_agente = g.agente AND p.dia = g.dia
WHERE p.dia IS NULL;

-- combinacoes sem NENHUMA linha, separando as de artigo criado depois da janela
CREATE TEMP TABLE gate_combo_vazio AS
SELECT f.nome_evento, f.artigo, f.acesso, f.agente,
       BOOL_AND(f.data_criacao > f.data_fim_extracao) AS criado_depois_da_janela,
       -- principal (ou alias) sem dado no proprio titulo, mas com outro titulo da familia carregado:
       -- caso do Marrocos, cujas visitas estao todas nos nomes antigos
       BOOL_AND(f.eh_principal OR f.alias_de IS NOT NULL) AND EXISTS (
           SELECT 1 FROM gate_meta m JOIN gate_pv p
             ON p.evento_referencia = m.nome_evento AND p.artigo = m.artigo_wikipedia
           WHERE m.nome_evento = f.nome_evento AND p.tipo_acesso = f.acesso AND p.tipo_agente = f.agente
             AND (m.eh_principal = 'True' OR NULLIF(m.alias_de, '') IS NOT NULL)
             AND m.artigo_wikipedia <> f.artigo) AS coberto_por_outro_titulo
FROM gate_faltas f GROUP BY 1, 2, 3, 4 HAVING COUNT(*) = 91;

-- =====================================================================
-- GATE E - eventos e janelas
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'E', 'E0', 'eventos carregados em eventos_bruto', COUNT(*), '40',
       CASE WHEN COUNT(*) = 40 THEN 'OK' ELSE 'FALHA' END
FROM bronze.eventos_bruto;

INSERT INTO gate_resultado
SELECT 'E', 'E1', 'eventos com janela diferente de 91 dias', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.eventos_bruto
WHERE data_fim_extracao - data_inicio_extracao + 1 <> 91;

INSERT INTO gate_resultado
SELECT 'E', 'E2', 'eventos fora do desenho 30 dias antes / 60 depois', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.eventos_bruto
WHERE data_evento - data_inicio_extracao <> 30 OR data_fim_extracao - data_evento <> 60;

INSERT INTO gate_resultado
SELECT 'E', 'E3', 'categorias sem exatamente 8 eventos', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT categoria FROM bronze.eventos_bruto GROUP BY categoria HAVING COUNT(*) <> 8) x;

INSERT INTO gate_resultado
SELECT 'E', 'E4', 'eventos da lista de artigos ausentes em eventos_bruto', COUNT(DISTINCT m.nome_evento), '0',
       CASE WHEN COUNT(DISTINCT m.nome_evento) = 0 THEN 'OK' ELSE 'FALHA' END
FROM gate_meta m LEFT JOIN bronze.eventos_bruto e ON e.nome_evento = m.nome_evento
WHERE e.nome_evento IS NULL;

-- =====================================================================
-- GATE A - chaves entre as tres tabelas
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'A', 'A1', 'eventos em pageviews que nao existem em eventos_bruto', COUNT(DISTINCT p.evento_referencia), '0',
       CASE WHEN COUNT(DISTINCT p.evento_referencia) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.pageviews_bruto p LEFT JOIN bronze.eventos_bruto e ON e.nome_evento = p.evento_referencia
WHERE e.nome_evento IS NULL;

INSERT INTO gate_resultado
SELECT 'A', 'A2', 'eventos em cobertura que nao existem em eventos_bruto', COUNT(DISTINCT c.evento_referencia), '0',
       CASE WHEN COUNT(DISTINCT c.evento_referencia) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.cobertura_midia_bruto c LEFT JOIN bronze.eventos_bruto e ON e.nome_evento = c.evento_referencia
WHERE e.nome_evento IS NULL;

INSERT INTO gate_resultado
SELECT 'A', 'A3', 'eventos sem pageviews ou sem cobertura', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.eventos_bruto e
WHERE NOT EXISTS (SELECT 1 FROM bronze.pageviews_bruto p WHERE p.evento_referencia = e.nome_evento)
   OR NOT EXISTS (SELECT 1 FROM bronze.cobertura_midia_bruto c WHERE c.evento_referencia = e.nome_evento);

INSERT INTO gate_resultado
SELECT 'A', 'A4', 'linhas de cobertura (40 eventos x 10 paises)', COUNT(*), '400',
       CASE WHEN COUNT(*) = 400 THEN 'OK' ELSE 'FALHA' END
FROM bronze.cobertura_midia_bruto;

INSERT INTO gate_resultado
SELECT 'A', 'A5', 'eventos sem exatamente 10 paises na cobertura', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT evento_referencia FROM bronze.cobertura_midia_bruto
      GROUP BY evento_referencia HAVING COUNT(DISTINCT pais_cobertura) <> 10) x;

-- =====================================================================
-- GATE B - continuidade de datas
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'B', 'B1', 'cobertura com payload diferente de 91 dias ou fora da janela', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.cobertura_midia_bruto c
JOIN bronze.eventos_bruto e ON e.nome_evento = c.evento_referencia
WHERE jsonb_array_length(c.payload) <> 91
   OR (SELECT MIN((x->>'date')::date) FROM jsonb_array_elements(c.payload) x) <> e.data_inicio_extracao
   OR (SELECT MAX((x->>'date')::date) FROM jsonb_array_elements(c.payload) x) <> e.data_fim_extracao
   OR (SELECT COUNT(DISTINCT x->>'date') FROM jsonb_array_elements(c.payload) x) <> 91;

INSERT INTO gate_resultado
SELECT 'B', 'B2a', 'combinacoes esperadas sem NENHUMA linha na Bronze', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM gate_combo_vazio
WHERE NOT COALESCE(criado_depois_da_janela, false) AND NOT COALESCE(coberto_por_outro_titulo, false);

INSERT INTO gate_resultado
SELECT 'B', 'B2f', 'combinacoes vazias cobertas por outro titulo do mesmo artigo (alias)', COUNT(*),
       '9 (principal do Marrocos)',
       CASE WHEN COUNT(*) = 9 THEN 'OK' ELSE 'INFO' END
FROM gate_combo_vazio WHERE coberto_por_outro_titulo AND NOT COALESCE(criado_depois_da_janela, false);

INSERT INTO gate_resultado
SELECT 'B', 'B2e', 'combinacoes vazias de artigo criado DEPOIS da janela', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ALERTA' END
FROM gate_combo_vazio WHERE criado_depois_da_janela;

INSERT INTO gate_resultado
SELECT 'B', 'B2b', 'dias ausentes ANTES da criacao do artigo (nulo explicado)', COUNT(*), 'qualquer',
       'INFO'
FROM gate_faltas WHERE antes_da_criacao;

INSERT INTO gate_resultado
SELECT 'B', 'B2c', 'dias ausentes DEPOIS da criacao (renomeacao ou falha da API)', COUNT(*), 'poucos',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ALERTA' END
FROM gate_faltas f
WHERE (NOT f.antes_da_criacao OR f.data_criacao IS NULL)
  AND NOT EXISTS (SELECT 1 FROM gate_combo_vazio v WHERE v.nome_evento = f.nome_evento AND v.artigo = f.artigo
                  AND v.acesso = f.acesso AND v.agente = f.agente);

INSERT INTO gate_resultado
SELECT 'B', 'B2d', 'dias a partir do evento sem dado no principal NEM nos aliases', COUNT(*),
       '11 (ChatGPT 5, RS 5, Maui 1)',
       CASE WHEN COUNT(*) = 11 THEN 'OK' ELSE 'ALERTA' END
FROM (
    SELECT g.nome_evento, g.dia
    FROM (SELECT DISTINCT nome_evento, dia FROM gate_grade WHERE eh_principal OR alias_de IS NOT NULL) g
    JOIN bronze.eventos_bruto e ON e.nome_evento = g.nome_evento
    WHERE g.dia >= e.data_evento
      AND NOT EXISTS (
          SELECT 1 FROM gate_meta m JOIN gate_pv p
            ON p.evento_referencia = m.nome_evento AND p.artigo = m.artigo_wikipedia
          WHERE m.nome_evento = g.nome_evento AND p.dia = g.dia
            AND (m.eh_principal = 'True' OR NULLIF(m.alias_de, '') IS NOT NULL))
) x;

INSERT INTO gate_resultado
SELECT 'B', 'B3', 'linhas de pageviews fora da janela do evento', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM gate_pv p JOIN bronze.eventos_bruto e ON e.nome_evento = p.evento_referencia
WHERE p.dia < e.data_inicio_extracao OR p.dia > e.data_fim_extracao;

-- =====================================================================
-- GATE C - dupla contagem e lista de artigos
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'C', 'C1', 'linhas duplicadas no grao evento x artigo x dia x acesso x agente', COALESCE(SUM(n - 1), 0), '0',
       CASE WHEN COALESCE(SUM(n - 1), 0) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT COUNT(*) n FROM bronze.pageviews_bruto
      GROUP BY evento_referencia, artigo, timestamp_bruto, tipo_acesso, tipo_agente HAVING COUNT(*) > 1) x;

INSERT INTO gate_resultado
SELECT 'C', 'C2', 'artigos presentes em mais de um evento (atribuicao multipla aceita)', COUNT(*), 'qualquer', 'INFO'
FROM (SELECT artigo FROM bronze.pageviews_bruto GROUP BY artigo HAVING COUNT(DISTINCT evento_referencia) > 1) x;

INSERT INTO gate_resultado
SELECT 'C', 'C3', 'linhas com categoria agregada ou valor fora do esperado em acesso/agente', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.pageviews_bruto
WHERE tipo_acesso NOT IN ('desktop', 'mobile-app', 'mobile-web')
   OR tipo_agente NOT IN ('user', 'spider', 'automated');

INSERT INTO gate_resultado
SELECT 'C', 'C4', 'aliases do principal sem nenhuma linha na Bronze', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM gate_meta m
WHERE NULLIF(m.alias_de, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gate_pv p
                  WHERE p.evento_referencia = m.nome_evento AND p.artigo = m.artigo_wikipedia);

INSERT INTO gate_resultado
SELECT 'C', 'C5', 'artigos na Bronze que nao estao na lista oficial do evento', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (SELECT DISTINCT evento_referencia, artigo FROM gate_pv) p
LEFT JOIN gate_meta m ON m.nome_evento = p.evento_referencia AND m.artigo_wikipedia = p.artigo
WHERE m.nome_evento IS NULL;

-- =====================================================================
-- GATE D - granularidade real e lotes
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'D', 'D1', '% de dias com user = spider = automated > 0 (sinal do bug antigo)',
       ROUND(100.0 * COUNT(*) FILTER (WHERE iguais) / NULLIF(COUNT(*), 0), 2), 'perto de 0',
       CASE WHEN COUNT(*) FILTER (WHERE iguais) <= 0.01 * COUNT(*) THEN 'OK' ELSE 'FALHA' END
FROM (
    SELECT (MAX(visualizacoes) FILTER (WHERE tipo_agente = 'user')
              = MAX(visualizacoes) FILTER (WHERE tipo_agente = 'spider')
        AND MAX(visualizacoes) FILTER (WHERE tipo_agente = 'spider')
              = MAX(visualizacoes) FILTER (WHERE tipo_agente = 'automated')) AS iguais
    FROM bronze.pageviews_bruto
    GROUP BY evento_referencia, artigo, timestamp_bruto, tipo_acesso
    HAVING COUNT(DISTINCT tipo_agente) = 3 AND MIN(visualizacoes) > 0
) x;

INSERT INTO gate_resultado
SELECT 'D', 'D2', 'lotes distintos em pageviews (1 por execucao)', COUNT(DISTINCT id_lote_origem), '1',
       CASE WHEN COUNT(DISTINCT id_lote_origem) = 1 THEN 'OK' ELSE 'ALERTA' END
FROM bronze.pageviews_bruto;

INSERT INTO gate_resultado
SELECT 'D', 'D3', 'linhas fora de en.wikipedia ou fora da granularidade diaria', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.pageviews_bruto
WHERE projeto NOT IN ('en.wikipedia', 'en.wikipedia.org') OR granularidade <> 'daily';

INSERT INTO gate_resultado
SELECT 'D', 'D4', 'cobertura com query diferente da registrada em eventos_bruto', COUNT(*), '0',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM bronze.cobertura_midia_bruto c JOIN bronze.eventos_bruto e ON e.nome_evento = c.evento_referencia
WHERE c.query_utilizada <> e.palavra_chave_busca;

-- =====================================================================
-- VOLUME
-- =====================================================================
INSERT INTO gate_resultado
SELECT 'V', 'V1', 'linhas em pageviews_bruto (requisito da orientadora)', COUNT(*), '>= 1.000.000',
       CASE WHEN COUNT(*) >= 1000000 THEN 'OK' ELSE 'FALHA' END
FROM bronze.pageviews_bruto;

INSERT INTO gate_resultado
SELECT 'V', 'V2', '% do teto teorico (combinacoes x 91 dias)',
       ROUND(100.0 * (SELECT COUNT(*) FROM bronze.pageviews_bruto) / NULLIF(COUNT(*), 0), 1), '> 90',
       CASE WHEN 100.0 * (SELECT COUNT(*) FROM bronze.pageviews_bruto) / NULLIF(COUNT(*), 0) > 90 THEN 'OK' ELSE 'ALERTA' END
FROM gate_grade;

-- =====================================================================
-- RESUMO
-- =====================================================================
\qecho ''
\qecho '================================ RESUMO DO GATE ================================'
SELECT gate, checagem, status, valor, esperado, descricao
FROM gate_resultado
ORDER BY CASE status WHEN 'FALHA' THEN 1 WHEN 'ALERTA' THEN 2 WHEN 'OK' THEN 3 ELSE 4 END, checagem;

SELECT status, COUNT(*) AS checagens FROM gate_resultado GROUP BY status ORDER BY status;

-- =====================================================================
-- DETALHES (so aparecem linhas quando existe o problema)
-- =====================================================================
\qecho ''
\qecho '>>> B2a / B2e / B2f: combinacoes sem nenhuma linha (ate 30)'
SELECT nome_evento, artigo, acesso, agente, criado_depois_da_janela, coberto_por_outro_titulo
FROM gate_combo_vazio ORDER BY 5, 6, 1, 2, 3, 4 LIMIT 30;

\qecho '>>> B2c: artigos com dias ausentes depois da criacao (top 30 por dias ausentes)'
SELECT nome_evento, artigo, data_criacao, COUNT(*) / 9.0 AS dias_ausentes_por_combinacao,
       MIN(dia) AS primeiro_dia_ausente, MAX(dia) AS ultimo_dia_ausente
FROM gate_faltas f
WHERE (NOT f.antes_da_criacao OR f.data_criacao IS NULL)
  AND NOT EXISTS (SELECT 1 FROM gate_combo_vazio v WHERE v.nome_evento = f.nome_evento AND v.artigo = f.artigo
                  AND v.acesso = f.acesso AND v.agente = f.agente)
GROUP BY 1, 2, 3 ORDER BY COUNT(*) DESC LIMIT 30;

\qecho '>>> B2d: eventos com dias sem dado no principal nem nos aliases, a partir do evento'
SELECT g.nome_evento, COUNT(*) AS dias, MIN(g.dia) AS de, MAX(g.dia) AS ate
FROM (SELECT DISTINCT nome_evento, dia FROM gate_grade WHERE eh_principal OR alias_de IS NOT NULL) g
JOIN bronze.eventos_bruto e ON e.nome_evento = g.nome_evento
WHERE g.dia >= e.data_evento
  AND NOT EXISTS (
      SELECT 1 FROM gate_meta m JOIN gate_pv p
        ON p.evento_referencia = m.nome_evento AND p.artigo = m.artigo_wikipedia
      WHERE m.nome_evento = g.nome_evento AND p.dia = g.dia
        AND (m.eh_principal = 'True' OR NULLIF(m.alias_de, '') IS NOT NULL))
GROUP BY 1 ORDER BY 2 DESC;

\qecho '>>> C4: aliases sem linha na Bronze'
SELECT m.nome_evento, m.artigo_wikipedia, m.alias_de FROM gate_meta m
WHERE NULLIF(m.alias_de, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gate_pv p
                  WHERE p.evento_referencia = m.nome_evento AND p.artigo = m.artigo_wikipedia);

\qecho '>>> C5: artigos inesperados na Bronze (ate 30)'
SELECT DISTINCT p.evento_referencia, p.artigo FROM gate_pv p
LEFT JOIN gate_meta m ON m.nome_evento = p.evento_referencia AND m.artigo_wikipedia = p.artigo
WHERE m.nome_evento IS NULL ORDER BY 1, 2 LIMIT 30;

\qecho '>>> D4: cobertura com query divergente'
SELECT c.evento_referencia, c.pais_cobertura, c.query_utilizada, e.palavra_chave_busca
FROM bronze.cobertura_midia_bruto c JOIN bronze.eventos_bruto e ON e.nome_evento = c.evento_referencia
WHERE c.query_utilizada <> e.palavra_chave_busca LIMIT 30;

\qecho '>>> volume por categoria'
SELECT e.categoria, COUNT(*) AS linhas
FROM bronze.pageviews_bruto p JOIN bronze.eventos_bruto e ON e.nome_evento = p.evento_referencia
GROUP BY 1 ORDER BY 1;
