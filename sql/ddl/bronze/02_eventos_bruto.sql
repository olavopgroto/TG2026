-- Camada Bronze: candidatos a eventos extraídos do GDELT, antes de curadoria

CREATE TABLE IF NOT EXISTS bronze.eventos_bruto (
    id                      BIGSERIAL PRIMARY KEY,

    -- Campos típicos do GDELT (ajustaremos conforme o endpoint exato usado)
    id_evento_gdelt         VARCHAR(50),
    data_evento             VARCHAR(20),
    nome_ator_1             TEXT,
    nome_ator_2             TEXT,
    codigo_evento           VARCHAR(10),
    escala_goldstein        NUMERIC(4,2),   -- intensidade do evento, escala GDELT
    numero_mencoes          INT,            -- volume de cobertura jornalística
    numero_fontes           INT,
    pais_geografico         VARCHAR(100),
    url_fonte                TEXT,

    -- Auditoria
    data_ingestao           TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem          UUID            NOT NULL,
    nome_pipeline_hop       VARCHAR(100)    NOT NULL
);

COMMENT ON TABLE bronze.eventos_bruto IS 'Candidatos a eventos extraídos do GDELT, antes da curadoria que os qualifica para dim_evento na camada gold (abordagem híbrida: GDELT como fonte de candidatos + critérios de curadoria)';