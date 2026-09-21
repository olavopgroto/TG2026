-- =====================================================================
-- bronze.cobertura_midia_bruto
-- Espelha a estrutura real do banco (conferida pelo pg_dump em 21/09/2026),
-- mais a trava uq_cobertura_evento_pais, adicionada antes da carga dos
-- 40 eventos para impedir carga duplicada.
-- Seguro para rodar de novo: nao apaga nem altera tabela existente.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bronze.cobertura_midia_bruto (
    id                          BIGSERIAL       PRIMARY KEY,

    -- Um registro por evento x pais (colecao nacional do Media Cloud)
    evento_referencia           TEXT            NOT NULL,
    pais_cobertura              VARCHAR(50)     NOT NULL,
    collection_id_mediacloud    BIGINT          NOT NULL,
    query_utilizada             TEXT            NOT NULL,
    payload                     JSONB           NOT NULL,   -- resposta bruta do story_count_over_time
    data_extracao               TIMESTAMP       NOT NULL,

    -- Auditoria de ingestao
    data_ingestao               TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem              VARCHAR(36)     NOT NULL,
    nome_pipeline_hop           VARCHAR(100)    NOT NULL,

    CONSTRAINT uq_cobertura_evento_pais UNIQUE (evento_referencia, pais_cobertura)
);

CREATE INDEX IF NOT EXISTS idx_gin_cobertura_midia_payload ON bronze.cobertura_midia_bruto USING gin (payload);

COMMENT ON TABLE bronze.cobertura_midia_bruto IS
  'Cobertura midiatica via Media Cloud API v4, granular por pais (10 colecoes nacionais validadas via Directory API). A soma por evento e calculada na Silver, nao na extracao, preservando a granularidade para analise de vies de cobertura domestica. Ver docs/criterios_curadoria_eventos.md.';
