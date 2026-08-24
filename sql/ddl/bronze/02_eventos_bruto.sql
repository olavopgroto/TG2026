-- Camada Bronze: eventos curados (Events 2.0) enriquecidos com timeline de cobertura (DOC 2.0)

CREATE TABLE IF NOT EXISTS bronze.eventos_bruto (
    id                      BIGSERIAL PRIMARY KEY,

    -- Identificação do evento (curadoria própria, com apoio do Events 2.0)
    id_evento_gdelt          VARCHAR(50),    -- referência ao evento original, se aplicável
    nome_evento              TEXT NOT NULL,  -- nome descritivo definido na curadoria
    palavra_chave_busca      TEXT NOT NULL,  -- termo usado na consulta à DOC 2.0
    data_evento               DATE NOT NULL,
    categoria_preliminar      VARCHAR(50),    -- classificação aplicada na curadoria (desastre, política, etc)

    -- Metadados de contexto (Events 2.0)
    escala_goldstein         NUMERIC(4,2),
    pais_geografico          VARCHAR(10),
    nome_geografico          TEXT,

    -- Timeline de cobertura (DOC 2.0) — um registro por evento + timestamp
    timestamp_cobertura      TIMESTAMP NOT NULL,
    volume_artigos           INT,            -- artigos naquele intervalo (timelinevolraw)
    tom_medio                 NUMERIC(6,3),   -- tom médio da cobertura naquele intervalo (timelinetone)

    -- Auditoria
    data_ingestao             TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem            UUID            NOT NULL,
    nome_pipeline_hop         VARCHAR(100)    NOT NULL
);

COMMENT ON TABLE bronze.eventos_bruto IS 'Eventos curados com apoio do GDELT Events 2.0, enriquecidos com timeline de cobertura jornalística do GDELT DOC 2.0';
COMMENT ON COLUMN bronze.eventos_bruto.palavra_chave_busca IS 'Termo de busca usado para consultar a DOC 2.0 API para este evento';