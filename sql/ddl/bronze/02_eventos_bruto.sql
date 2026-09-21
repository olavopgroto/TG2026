-- =====================================================================
-- bronze.eventos_bruto
-- Espelha a estrutura real do banco (conferida pelo pg_dump em 21/09/2026).
-- Substitui o desenho antigo da era GDELT (volume_artigos, tom_medio etc.).
-- Seguro para rodar de novo: nao apaga nem altera tabela existente.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bronze.eventos_bruto (
    id                      BIGSERIAL       PRIMARY KEY,

    -- Espelho do eventos_curados.csv
    nome_evento             TEXT            NOT NULL,
    categoria               VARCHAR(50)     NOT NULL,
    data_evento             DATE            NOT NULL,
    artigo_wikipedia        TEXT            NOT NULL,
    palavra_chave_busca     TEXT            NOT NULL,
    data_inicio_extracao    DATE            NOT NULL,
    data_fim_extracao       DATE            NOT NULL,

    -- Auditoria de ingestao
    data_ingestao           TIMESTAMP       NOT NULL DEFAULT now(),
    id_lote_origem          VARCHAR(36)     NOT NULL,
    nome_pipeline_hop       VARCHAR(100)    NOT NULL,

    CONSTRAINT uq_eventos_nome UNIQUE (nome_evento),
    CONSTRAINT ck_eventos_categoria CHECK (categoria IN
        ('desastre_natural', 'politico', 'morte_figura_publica', 'lancamento_produto', 'ciencia_global')),
    CONSTRAINT ck_eventos_janela CHECK (data_fim_extracao > data_inicio_extracao),
    CONSTRAINT ck_eventos_dentro CHECK (data_evento BETWEEN data_inicio_extracao AND data_fim_extracao)
);

CREATE INDEX IF NOT EXISTS idx_eventos_categoria ON bronze.eventos_bruto (categoria);

COMMENT ON TABLE bronze.eventos_bruto IS
  'Espelho dos eventos curados (eventos_curados.csv). Tabela de referencia sem metricas: pageviews ficam em bronze.pageviews_bruto e cobertura em bronze.cobertura_midia_bruto, relacionadas por nome_evento.';
COMMENT ON COLUMN bronze.eventos_bruto.palavra_chave_busca IS
  'Query booleana efetivamente usada na extracao da Media Cloud. Renomeada de palavra_chave_gdelt em setembro de 2026.';
COMMENT ON CONSTRAINT ck_eventos_dentro ON bronze.eventos_bruto IS
  'Garante que a data do evento caia dentro da propria janela de extracao declarada.';
