-- =====================================================================
-- bronze.pageviews_bruto
-- Espelha a estrutura real do banco (conferida pelo pg_dump em 21/09/2026).
-- Seguro para rodar de novo: nao apaga nem altera tabela existente.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bronze.pageviews_bruto (
    id                  BIGSERIAL       PRIMARY KEY,

    -- Rastreabilidade: evento curado (eventos_curados.csv) que originou a linha
    evento_referencia   VARCHAR(100)    NOT NULL,

    -- Campos da Wikimedia REST API (pageviews per-article), sem transformacao
    projeto             VARCHAR(50)     NOT NULL,
    artigo              TEXT            NOT NULL,
    granularidade       VARCHAR(10)     NOT NULL,
    timestamp_bruto     VARCHAR(20)     NOT NULL,
    tipo_acesso         VARCHAR(20)     NOT NULL,
    tipo_agente         VARCHAR(20)     NOT NULL,
    visualizacoes       BIGINT          NOT NULL,

    -- Auditoria de ingestao
    data_ingestao       TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem      VARCHAR(36)     NOT NULL,   -- VARCHAR, nao UUID: o Hop nao gera tipo UUID nativo
    nome_pipeline_hop   VARCHAR(100)    NOT NULL,

    CONSTRAINT uq_pageviews_grao
        UNIQUE (artigo, timestamp_bruto, tipo_acesso, tipo_agente, evento_referencia)
);

CREATE INDEX IF NOT EXISTS idx_pageviews_evento    ON bronze.pageviews_bruto (evento_referencia);
CREATE INDEX IF NOT EXISTS idx_pageviews_artigo    ON bronze.pageviews_bruto (artigo);
CREATE INDEX IF NOT EXISTS idx_pageviews_timestamp ON bronze.pageviews_bruto (timestamp_bruto);
CREATE INDEX IF NOT EXISTS idx_pageviews_agente    ON bronze.pageviews_bruto (tipo_agente);

COMMENT ON TABLE bronze.pageviews_bruto IS
  'Pageviews brutos da Wikimedia REST API, sem transformacao. Granularidade real por tipo_acesso x tipo_agente: a URL da requisicao varia esses parametros, nao apenas o rotulo gravado. Dia com valor 0 vem explicito da API; dia ausente significa que o titulo nao tinha dado naquele dia (tratado como nulo na Silver).';
COMMENT ON COLUMN bronze.pageviews_bruto.timestamp_bruto IS
  'Timestamp no formato original da API (AAAAMMDDHH). Como a granularidade e diaria, as duas ultimas posicoes sao sempre 00.';
COMMENT ON CONSTRAINT uq_pageviews_grao ON bronze.pageviews_bruto IS
  'Garante que a mesma combinacao nao seja inserida duas vezes, prevenindo a dupla contagem detectada na auditoria de setembro de 2026.';
