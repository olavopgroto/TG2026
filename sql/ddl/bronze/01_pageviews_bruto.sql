CREATE TABLE IF NOT EXISTS bronze.pageviews_bruto (
    id                  BIGSERIAL PRIMARY KEY,

    -- Rastreabilidade: a qual evento curado esta extração pertence
    evento_referencia   VARCHAR(100),

    -- Campos da API (Wikimedia Pageviews per-article)
    projeto             VARCHAR(50)     NOT NULL,
    artigo              TEXT            NOT NULL,
    granularidade       VARCHAR(10)     NOT NULL,   -- sempre "daily" (horária não existe publicamente desde 2018)
    timestamp_bruto     VARCHAR(20)     NOT NULL,   -- formato original da API: AAAAMMDDHH
    tipo_acesso         VARCHAR(20)     NOT NULL,
    tipo_agente         VARCHAR(20)     NOT NULL,
    visualizacoes       BIGINT          NOT NULL,

    -- Auditoria de ingestão
    data_ingestao       TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem      VARCHAR(36)     NOT NULL,   -- VARCHAR, não UUID: Hop não gera tipo UUID nativo
    nome_pipeline_hop   VARCHAR(100)    NOT NULL
);

COMMENT ON TABLE bronze.pageviews_bruto IS 'Dados brutos de pageviews extraídos da Wikimedia REST API, sem transformação';
COMMENT ON COLUMN bronze.pageviews_bruto.evento_referencia IS 'Nome do evento curado (eventos_curados.csv) que originou esta extração';
COMMENT ON COLUMN bronze.pageviews_bruto.timestamp_bruto IS 'Timestamp no formato original da API (string), sem conversão de tipo';