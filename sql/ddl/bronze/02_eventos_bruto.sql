CREATE TABLE IF NOT EXISTS bronze.eventos_bruto (
    id                      BIGSERIAL PRIMARY KEY,

    id_evento_gdelt          VARCHAR(50),
    nome_evento              TEXT NOT NULL,
    palavra_chave_busca      TEXT NOT NULL,
    data_evento               DATE NOT NULL,
    categoria_preliminar      VARCHAR(50),

    escala_goldstein         NUMERIC(4,2),
    pais_geografico          VARCHAR(10),
    nome_geografico          TEXT,

    timestamp_cobertura      TIMESTAMP NOT NULL,
    volume_artigos           INT,
    tom_medio                 NUMERIC(6,3),

    data_ingestao             TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem            VARCHAR(36)     NOT NULL,   -- VARCHAR, mesmo motivo acima
    nome_pipeline_hop         VARCHAR(100)    NOT NULL
);

COMMENT ON TABLE bronze.eventos_bruto IS 'Eventos curados com apoio do GDELT Events 2.0, enriquecidos com timeline de cobertura jornalística do GDELT DOC 2.0';