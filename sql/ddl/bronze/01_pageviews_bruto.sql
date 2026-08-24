-- Camada Bronze: dados brutos de pageviews, espelhando a resposta da Wikimedia REST API
-- Granularidade: horária

CREATE TABLE IF NOT EXISTS bronze.pageviews_bruto (
    id                      BIGSERIAL PRIMARY KEY,

    -- Campos da API (Wikimedia Pageviews per-article)
    projeto                 VARCHAR(50)     NOT NULL,   -- ex: en.wikipedia, pt.wikipedia
    artigo                  TEXT            NOT NULL,   -- título da página
    granularidade           VARCHAR(10)     NOT NULL,   -- ex: hourly
    timestamp_bruto         VARCHAR(20)     NOT NULL,   -- formato original da API: AAAAMMDDHH
    tipo_acesso             VARCHAR(20)     NOT NULL,   -- desktop, mobile-web, mobile-app (access_method como atributo)
    tipo_agente             VARCHAR(20)     NOT NULL,   -- user, bot, spider, all-agents
    visualizacoes           BIGINT          NOT NULL,

    -- Auditoria de ingestão (padrão de mercado, não é da API)
    data_ingestao           TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem          UUID            NOT NULL,
    nome_pipeline_hop       VARCHAR(100)    NOT NULL
);

COMMENT ON TABLE bronze.pageviews_bruto IS 'Dados brutos de pageviews extraídos da Wikimedia REST API, sem transformação. Granularidade horária.';
COMMENT ON COLUMN bronze.pageviews_bruto.timestamp_bruto IS 'Timestamp no formato original da API (string AAAAMMDDHH), sem conversão de tipo';
COMMENT ON COLUMN bronze.pageviews_bruto.tipo_acesso IS 'Método de acesso mantido como atributo categórico, não como métrica separada';
COMMENT ON COLUMN bronze.pageviews_bruto.id_lote_origem IS 'Identifica qual execução do pipeline Hop gerou este registro';