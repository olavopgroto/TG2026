-- =====================================================================
-- CAMADA SILVER - 40 eventos (setembro de 2026)
--
-- Roda uma vez, no DBeaver ou via psql. Cria as seis tabelas na ordem
-- das dependencias. Nao apaga nada: use o bloco de recarga no fim do
-- arquivo quando precisar refazer a carga.
--
-- REGRA ZERO x NULO (decidida em 21/09/2026):
--   a Wikimedia devolve o dia com valor 0 quando o titulo existe e
--   ninguem acessou. Entao: linha com 0 na Bronze = ZERO aqui;
--   dia sem linha na Bronze = NULO aqui. A coluna origem_valor registra
--   qual dos casos e cada linha, e a data de criacao do artigo explica
--   (mas nao decide) o nulo.
--
-- ALIASES: titulos anteriores do artigo principal (ex.: o terremoto da
--   Turquia, que em fevereiro de 2023 estava no singular). A serie deles
--   e somada a do principal na tabela agregada, mas fica separada na
--   granular, para ser possivel desfazer a soma a qualquer momento.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS silver;

-- ---------------------------------------------------------------------
-- 1. eventos (40 linhas) - espelho da Bronze com id proprio
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.eventos (
    id_evento               BIGSERIAL       PRIMARY KEY,
    nome_evento             TEXT            NOT NULL,
    categoria               VARCHAR(50)     NOT NULL,
    data_evento             DATE            NOT NULL,
    artigo_principal        TEXT            NOT NULL,
    palavra_chave_busca     TEXT            NOT NULL,
    data_inicio_extracao    DATE            NOT NULL,
    data_fim_extracao       DATE            NOT NULL,
    data_carga              TIMESTAMP       NOT NULL DEFAULT now(),

    CONSTRAINT uq_silver_eventos_nome UNIQUE (nome_evento),
    CONSTRAINT ck_silver_eventos_categoria CHECK (categoria IN
        ('desastre_natural', 'politico', 'morte_figura_publica', 'lancamento_produto', 'ciencia_global'))
);

COMMENT ON TABLE silver.eventos IS
  'Os 40 eventos curados. O id_evento e a chave usada pelas demais tabelas da Silver e da Gold.';

-- ---------------------------------------------------------------------
-- 2. artigos (1.424 linhas) - dimensao com as metricas da curadoria
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.artigos (
    id_artigo               BIGSERIAL       PRIMARY KEY,
    id_evento               BIGINT          NOT NULL REFERENCES silver.eventos (id_evento),
    artigo                  TEXT            NOT NULL,
    eh_principal            BOOLEAN         NOT NULL DEFAULT false,
    alias_de                TEXT,                       -- titulo do principal quando esta linha e um titulo anterior dele
    posicao_ranking         INT,                        -- 0 = principal e aliases; 1 a 70 = ordem da razao de amplificacao
    media_base              NUMERIC(12,2),              -- media diaria antes do evento (curadoria)
    media_pico              NUMERIC(12,2),              -- media diaria nos 15 dias seguintes (curadoria)
    razao_amplificacao      NUMERIC(10,2),              -- media_pico / media_base
    data_criacao            DATE,                       -- primeira revisao do artigo de destino

    CONSTRAINT uq_silver_artigos UNIQUE (id_evento, artigo)
);

CREATE INDEX IF NOT EXISTS idx_silver_artigos_evento ON silver.artigos (id_evento);

COMMENT ON COLUMN silver.artigos.razao_amplificacao IS
  'Quanto o artigo subiu por causa do evento. Serve de filtro de sensibilidade na Gold (ex.: manter so artigos acima de 2x).';
COMMENT ON COLUMN silver.artigos.alias_de IS
  'Preenchido apenas em titulos anteriores do artigo principal. Na tabela agregada a serie deles entra somada ao principal.';

-- ---------------------------------------------------------------------
-- 3. pageviews diario por artigo (~1,17 milhao) - grade completa
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.pageviews_diario_artigo (
    id_evento           BIGINT          NOT NULL REFERENCES silver.eventos (id_evento),
    id_artigo           BIGINT          NOT NULL REFERENCES silver.artigos (id_artigo),
    dia                 DATE            NOT NULL,
    dias_desde_evento   INT             NOT NULL,       -- -30 a +60
    tipo_acesso         VARCHAR(20)     NOT NULL,
    tipo_agente         VARCHAR(20)     NOT NULL,
    visualizacoes       BIGINT,                         -- NULL = nao havia dado para o titulo naquele dia
    origem_valor        VARCHAR(24)     NOT NULL,

    CONSTRAINT pk_silver_pv_artigo PRIMARY KEY (id_artigo, dia, tipo_acesso, tipo_agente),
    CONSTRAINT ck_silver_pv_origem CHECK (origem_valor IN
        ('api', 'ausente_antes_criacao', 'ausente_pos_criacao')),
    CONSTRAINT ck_silver_pv_coerencia CHECK (
        (origem_valor = 'api' AND visualizacoes IS NOT NULL)
     OR (origem_valor <> 'api' AND visualizacoes IS NULL))
);

CREATE INDEX IF NOT EXISTS idx_silver_pv_evento_dia ON silver.pageviews_diario_artigo (id_evento, dia);
CREATE INDEX IF NOT EXISTS idx_silver_pv_agente     ON silver.pageviews_diario_artigo (tipo_agente);

COMMENT ON TABLE silver.pageviews_diario_artigo IS
  'Grade completa: todo artigo, todos os 91 dias da janela, nas 9 combinacoes de acesso e agente. Dias que a API nao devolveu existem aqui como NULL, com o motivo em origem_valor.';
COMMENT ON COLUMN silver.pageviews_diario_artigo.origem_valor IS
  'api = valor veio da Wikimedia (inclusive zero); ausente_antes_criacao = o artigo ainda nao existia; ausente_pos_criacao = titulo renomeado ou falha da API.';

-- ---------------------------------------------------------------------
-- 4. pageviews diario por evento (32.760) - as duas curvas
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.pageviews_diario_evento (
    id_evento               BIGINT          NOT NULL REFERENCES silver.eventos (id_evento),
    dia                     DATE            NOT NULL,
    dias_desde_evento       INT             NOT NULL,
    tipo_acesso             VARCHAR(20)     NOT NULL,
    tipo_agente             VARCHAR(20)     NOT NULL,
    views_principal         BIGINT,                     -- artigo principal + seus titulos anteriores
    views_conjunto          BIGINT,                     -- todos os artigos do evento, principal incluso
    artigos_com_dado        INT             NOT NULL,   -- quantos artigos tinham valor nesse dia

    CONSTRAINT pk_silver_pv_evento PRIMARY KEY (id_evento, dia, tipo_acesso, tipo_agente)
);

COMMENT ON TABLE silver.pageviews_diario_evento IS
  'Duas leituras da atencao por dia: a curva do artigo principal (o evento em si) e a curva do conjunto de 35 artigos (evento mais transbordamento para o campo semantico).';

-- ---------------------------------------------------------------------
-- 5. cobertura diaria por pais (36.400) - payload aberto
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.cobertura_diaria_pais (
    id_evento               BIGINT          NOT NULL REFERENCES silver.eventos (id_evento),
    pais_cobertura          VARCHAR(50)     NOT NULL,
    dia                     DATE            NOT NULL,
    dias_desde_evento       INT             NOT NULL,
    materias                INT             NOT NULL,   -- count: materias que casaram com a query
    materias_total          BIGINT,                     -- total_count: universo do dia naquela colecao
    proporcao               NUMERIC(12,8),              -- ratio devolvido pela API

    CONSTRAINT pk_silver_cob_pais PRIMARY KEY (id_evento, pais_cobertura, dia)
);

COMMENT ON TABLE silver.cobertura_diaria_pais IS
  'Cobertura por pais, mantida separada para permitir medir o vies de cobertura domestica (ex.: Turquia no terremoto, Brasil no G20 do Rio).';

-- ---------------------------------------------------------------------
-- 6. cobertura diaria agregada (3.640)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.cobertura_diaria (
    id_evento               BIGINT          NOT NULL REFERENCES silver.eventos (id_evento),
    dia                     DATE            NOT NULL,
    dias_desde_evento       INT             NOT NULL,
    materias                INT             NOT NULL,   -- soma dos 10 paises
    materias_total          BIGINT,
    paises_com_materia      INT             NOT NULL,   -- quantos dos 10 tiveram ao menos uma materia

    CONSTRAINT pk_silver_cob PRIMARY KEY (id_evento, dia)
);

COMMENT ON TABLE silver.cobertura_diaria IS
  'Cobertura midiatica agregada por evento e dia. E a serie comparada com a atencao publica na Gold.';

-- =====================================================================
-- RECARGA: rode este bloco antes de executar as pipelines de novo
-- =====================================================================
-- TRUNCATE silver.pageviews_diario_artigo, silver.pageviews_diario_evento,
--          silver.cobertura_diaria_pais, silver.cobertura_diaria,
--          silver.artigos, silver.eventos
--   RESTART IDENTITY CASCADE;
