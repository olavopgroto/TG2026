--
-- PostgreSQL database dump
--

\restrict JZwLwmMJ4HFjfBm4obMGsTMa4I9YMazaTUIIx7zOMdhLkUKCAPAE4hjU42Qvu4G

-- Dumped from database version 16.15 (Debian 16.15-1.pgdg13+2)
-- Dumped by pg_dump version 16.15 (Debian 16.15-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bronze; Type: SCHEMA; Schema: -; Owner: tcc
--

CREATE SCHEMA bronze;


ALTER SCHEMA bronze OWNER TO tcc;

--
-- Name: SCHEMA bronze; Type: COMMENT; Schema: -; Owner: tcc
--

COMMENT ON SCHEMA bronze IS 'Dados brutos, exatamente como extraídos das fontes (Wikimedia API, eventos)';


--
-- Name: gold; Type: SCHEMA; Schema: -; Owner: tcc
--

CREATE SCHEMA gold;


ALTER SCHEMA gold OWNER TO tcc;

--
-- Name: SCHEMA gold; Type: COMMENT; Schema: -; Owner: tcc
--

COMMENT ON SCHEMA gold IS 'Dados finais em esquema estrela, prontos para análise no Power BI';


--
-- Name: silver; Type: SCHEMA; Schema: -; Owner: tcc
--

CREATE SCHEMA silver;


ALTER SCHEMA silver OWNER TO tcc;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cobertura_midia_bruto; Type: TABLE; Schema: bronze; Owner: tcc
--

CREATE TABLE bronze.cobertura_midia_bruto (
    id bigint NOT NULL,
    evento_referencia text NOT NULL,
    pais_cobertura character varying(50) NOT NULL,
    collection_id_mediacloud bigint NOT NULL,
    query_utilizada text NOT NULL,
    payload jsonb NOT NULL,
    data_extracao timestamp without time zone NOT NULL,
    data_ingestao timestamp without time zone DEFAULT now() NOT NULL,
    id_lote_origem character varying(36) NOT NULL,
    nome_pipeline_hop character varying(100) NOT NULL
);


ALTER TABLE bronze.cobertura_midia_bruto OWNER TO tcc;

--
-- Name: TABLE cobertura_midia_bruto; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON TABLE bronze.cobertura_midia_bruto IS 'Cobertura midiática via Media Cloud API v4, granular por país (10 coleções nacionais validadas via Directory API). Soma por evento calculada na Silver, não na extração, preservando granularidade para análise de viés de cobertura doméstica. 3 eventos reextraídos com query corrigida (Google Gemini, Threads Meta, Eleição presidencial EUA) — ver docs/criterios_curadoria_eventos.md para detalhamento.';


--
-- Name: cobertura_midia_bruto_id_seq; Type: SEQUENCE; Schema: bronze; Owner: tcc
--

CREATE SEQUENCE bronze.cobertura_midia_bruto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bronze.cobertura_midia_bruto_id_seq OWNER TO tcc;

--
-- Name: cobertura_midia_bruto_id_seq; Type: SEQUENCE OWNED BY; Schema: bronze; Owner: tcc
--

ALTER SEQUENCE bronze.cobertura_midia_bruto_id_seq OWNED BY bronze.cobertura_midia_bruto.id;


--
-- Name: eventos_bruto; Type: TABLE; Schema: bronze; Owner: tcc
--

CREATE TABLE bronze.eventos_bruto (
    id bigint NOT NULL,
    nome_evento text NOT NULL,
    categoria character varying(50) NOT NULL,
    data_evento date NOT NULL,
    artigo_wikipedia text NOT NULL,
    palavra_chave_busca text NOT NULL,
    data_inicio_extracao date NOT NULL,
    data_fim_extracao date NOT NULL,
    data_ingestao timestamp without time zone DEFAULT now() NOT NULL,
    id_lote_origem character varying(36) NOT NULL,
    nome_pipeline_hop character varying(100) NOT NULL,
    CONSTRAINT ck_eventos_categoria CHECK (((categoria)::text = ANY ((ARRAY['desastre_natural'::character varying, 'politico'::character varying, 'morte_figura_publica'::character varying, 'lancamento_produto'::character varying, 'ciencia_global'::character varying])::text[]))),
    CONSTRAINT ck_eventos_dentro CHECK (((data_evento >= data_inicio_extracao) AND (data_evento <= data_fim_extracao))),
    CONSTRAINT ck_eventos_janela CHECK ((data_fim_extracao > data_inicio_extracao))
);


ALTER TABLE bronze.eventos_bruto OWNER TO tcc;

--
-- Name: TABLE eventos_bruto; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON TABLE bronze.eventos_bruto IS 'Espelho dos eventos curados (eventos_curados.csv). Tabela de referencia sem metricas: pageviews ficam em bronze.pageviews_bruto e cobertura em bronze.cobertura_midia_bruto, relacionadas por nome_evento.';


--
-- Name: COLUMN eventos_bruto.palavra_chave_busca; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON COLUMN bronze.eventos_bruto.palavra_chave_busca IS 'Query booleana efetivamente usada na extracao da Media Cloud. Renomeada de palavra_chave_gdelt em setembro de 2026.';


--
-- Name: CONSTRAINT ck_eventos_dentro ON eventos_bruto; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON CONSTRAINT ck_eventos_dentro ON bronze.eventos_bruto IS 'Garante que a data do evento caia dentro da propria janela de extracao declarada.';


--
-- Name: eventos_bruto_id_seq; Type: SEQUENCE; Schema: bronze; Owner: tcc
--

CREATE SEQUENCE bronze.eventos_bruto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bronze.eventos_bruto_id_seq OWNER TO tcc;

--
-- Name: eventos_bruto_id_seq; Type: SEQUENCE OWNED BY; Schema: bronze; Owner: tcc
--

ALTER SEQUENCE bronze.eventos_bruto_id_seq OWNED BY bronze.eventos_bruto.id;


--
-- Name: pageviews_bruto; Type: TABLE; Schema: bronze; Owner: tcc
--

CREATE TABLE bronze.pageviews_bruto (
    id bigint NOT NULL,
    evento_referencia character varying(100) NOT NULL,
    projeto character varying(50) NOT NULL,
    artigo text NOT NULL,
    granularidade character varying(10) NOT NULL,
    timestamp_bruto character varying(20) NOT NULL,
    tipo_acesso character varying(20) NOT NULL,
    tipo_agente character varying(20) NOT NULL,
    visualizacoes bigint NOT NULL,
    data_ingestao timestamp without time zone DEFAULT now() NOT NULL,
    id_lote_origem character varying(36) NOT NULL,
    nome_pipeline_hop character varying(100) NOT NULL
);


ALTER TABLE bronze.pageviews_bruto OWNER TO tcc;

--
-- Name: TABLE pageviews_bruto; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON TABLE bronze.pageviews_bruto IS 'Pageviews brutos da Wikimedia REST API, sem transformacao. Granularidade real por tipo_acesso x tipo_agente: a URL da requisicao varia esses parametros, nao apenas o rotulo gravado.';


--
-- Name: COLUMN pageviews_bruto.timestamp_bruto; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON COLUMN bronze.pageviews_bruto.timestamp_bruto IS 'Timestamp no formato original da API (AAAAMMDDHH). Como granularidade e diaria, as duas ultimas posicoes sao sempre 00.';


--
-- Name: pageviews_bruto_id_seq; Type: SEQUENCE; Schema: bronze; Owner: tcc
--

CREATE SEQUENCE bronze.pageviews_bruto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bronze.pageviews_bruto_id_seq OWNER TO tcc;

--
-- Name: pageviews_bruto_id_seq; Type: SEQUENCE OWNED BY; Schema: bronze; Owner: tcc
--

ALTER SEQUENCE bronze.pageviews_bruto_id_seq OWNED BY bronze.pageviews_bruto.id;


--
-- Name: artigos; Type: TABLE; Schema: silver; Owner: tcc
--

CREATE TABLE silver.artigos (
    id_artigo bigint NOT NULL,
    id_evento bigint NOT NULL,
    artigo text NOT NULL,
    eh_principal boolean DEFAULT false NOT NULL,
    alias_de text,
    posicao_ranking integer,
    media_base numeric(12,2),
    media_pico numeric(12,2),
    razao_amplificacao numeric(10,2),
    data_criacao date
);


ALTER TABLE silver.artigos OWNER TO tcc;

--
-- Name: COLUMN artigos.alias_de; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON COLUMN silver.artigos.alias_de IS 'Preenchido apenas em titulos anteriores do artigo principal. Na tabela agregada a serie deles entra somada ao principal.';


--
-- Name: COLUMN artigos.razao_amplificacao; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON COLUMN silver.artigos.razao_amplificacao IS 'Quanto o artigo subiu por causa do evento. Serve de filtro de sensibilidade na Gold (ex.: manter so artigos acima de 2x).';


--
-- Name: artigos_id_artigo_seq; Type: SEQUENCE; Schema: silver; Owner: tcc
--

CREATE SEQUENCE silver.artigos_id_artigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE silver.artigos_id_artigo_seq OWNER TO tcc;

--
-- Name: artigos_id_artigo_seq; Type: SEQUENCE OWNED BY; Schema: silver; Owner: tcc
--

ALTER SEQUENCE silver.artigos_id_artigo_seq OWNED BY silver.artigos.id_artigo;


--
-- Name: cobertura_diaria; Type: TABLE; Schema: silver; Owner: tcc
--

CREATE TABLE silver.cobertura_diaria (
    id_evento bigint NOT NULL,
    dia date NOT NULL,
    dias_desde_evento integer NOT NULL,
    materias integer NOT NULL,
    materias_total bigint,
    paises_com_materia integer NOT NULL
);


ALTER TABLE silver.cobertura_diaria OWNER TO tcc;

--
-- Name: TABLE cobertura_diaria; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON TABLE silver.cobertura_diaria IS 'Cobertura midiatica agregada por evento e dia. E a serie comparada com a atencao publica na Gold.';


--
-- Name: cobertura_diaria_pais; Type: TABLE; Schema: silver; Owner: tcc
--

CREATE TABLE silver.cobertura_diaria_pais (
    id_evento bigint NOT NULL,
    pais_cobertura character varying(50) NOT NULL,
    dia date NOT NULL,
    dias_desde_evento integer NOT NULL,
    materias integer NOT NULL,
    materias_total bigint,
    proporcao numeric(12,8)
);


ALTER TABLE silver.cobertura_diaria_pais OWNER TO tcc;

--
-- Name: TABLE cobertura_diaria_pais; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON TABLE silver.cobertura_diaria_pais IS 'Cobertura por pais, mantida separada para permitir medir o vies de cobertura domestica (ex.: Turquia no terremoto, Brasil no G20 do Rio).';


--
-- Name: eventos; Type: TABLE; Schema: silver; Owner: tcc
--

CREATE TABLE silver.eventos (
    id_evento bigint NOT NULL,
    nome_evento text NOT NULL,
    categoria character varying(50) NOT NULL,
    data_evento date NOT NULL,
    artigo_principal text NOT NULL,
    palavra_chave_busca text NOT NULL,
    data_inicio_extracao date NOT NULL,
    data_fim_extracao date NOT NULL,
    data_carga timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_silver_eventos_categoria CHECK (((categoria)::text = ANY ((ARRAY['desastre_natural'::character varying, 'politico'::character varying, 'morte_figura_publica'::character varying, 'lancamento_produto'::character varying, 'ciencia_global'::character varying])::text[])))
);


ALTER TABLE silver.eventos OWNER TO tcc;

--
-- Name: TABLE eventos; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON TABLE silver.eventos IS 'Os 40 eventos curados. O id_evento e a chave usada pelas demais tabelas da Silver e da Gold.';


--
-- Name: eventos_id_evento_seq; Type: SEQUENCE; Schema: silver; Owner: tcc
--

CREATE SEQUENCE silver.eventos_id_evento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE silver.eventos_id_evento_seq OWNER TO tcc;

--
-- Name: eventos_id_evento_seq; Type: SEQUENCE OWNED BY; Schema: silver; Owner: tcc
--

ALTER SEQUENCE silver.eventos_id_evento_seq OWNED BY silver.eventos.id_evento;


--
-- Name: pageviews_diario_artigo; Type: TABLE; Schema: silver; Owner: tcc
--

CREATE TABLE silver.pageviews_diario_artigo (
    id_evento bigint NOT NULL,
    id_artigo bigint NOT NULL,
    dia date NOT NULL,
    dias_desde_evento integer NOT NULL,
    tipo_acesso character varying(20) NOT NULL,
    tipo_agente character varying(20) NOT NULL,
    visualizacoes bigint,
    origem_valor character varying(24) NOT NULL,
    CONSTRAINT ck_silver_pv_coerencia CHECK (((((origem_valor)::text = 'api'::text) AND (visualizacoes IS NOT NULL)) OR (((origem_valor)::text <> 'api'::text) AND (visualizacoes IS NULL)))),
    CONSTRAINT ck_silver_pv_origem CHECK (((origem_valor)::text = ANY ((ARRAY['api'::character varying, 'ausente_antes_criacao'::character varying, 'ausente_pos_criacao'::character varying])::text[])))
);


ALTER TABLE silver.pageviews_diario_artigo OWNER TO tcc;

--
-- Name: TABLE pageviews_diario_artigo; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON TABLE silver.pageviews_diario_artigo IS 'Grade completa: todo artigo, todos os 91 dias da janela, nas 9 combinacoes de acesso e agente. Dias que a API nao devolveu existem aqui como NULL, com o motivo em origem_valor.';


--
-- Name: COLUMN pageviews_diario_artigo.origem_valor; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON COLUMN silver.pageviews_diario_artigo.origem_valor IS 'api = valor veio da Wikimedia (inclusive zero); ausente_antes_criacao = o artigo ainda nao existia; ausente_pos_criacao = titulo renomeado ou falha da API.';


--
-- Name: pageviews_diario_evento; Type: TABLE; Schema: silver; Owner: tcc
--

CREATE TABLE silver.pageviews_diario_evento (
    id_evento bigint NOT NULL,
    dia date NOT NULL,
    dias_desde_evento integer NOT NULL,
    tipo_acesso character varying(20) NOT NULL,
    tipo_agente character varying(20) NOT NULL,
    views_principal bigint,
    views_conjunto bigint,
    artigos_com_dado integer NOT NULL
);


ALTER TABLE silver.pageviews_diario_evento OWNER TO tcc;

--
-- Name: TABLE pageviews_diario_evento; Type: COMMENT; Schema: silver; Owner: tcc
--

COMMENT ON TABLE silver.pageviews_diario_evento IS 'Duas leituras da atencao por dia: a curva do artigo principal (o evento em si) e a curva do conjunto de 35 artigos (evento mais transbordamento para o campo semantico).';


--
-- Name: cobertura_midia_bruto id; Type: DEFAULT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.cobertura_midia_bruto ALTER COLUMN id SET DEFAULT nextval('bronze.cobertura_midia_bruto_id_seq'::regclass);


--
-- Name: eventos_bruto id; Type: DEFAULT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.eventos_bruto ALTER COLUMN id SET DEFAULT nextval('bronze.eventos_bruto_id_seq'::regclass);


--
-- Name: pageviews_bruto id; Type: DEFAULT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.pageviews_bruto ALTER COLUMN id SET DEFAULT nextval('bronze.pageviews_bruto_id_seq'::regclass);


--
-- Name: artigos id_artigo; Type: DEFAULT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.artigos ALTER COLUMN id_artigo SET DEFAULT nextval('silver.artigos_id_artigo_seq'::regclass);


--
-- Name: eventos id_evento; Type: DEFAULT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.eventos ALTER COLUMN id_evento SET DEFAULT nextval('silver.eventos_id_evento_seq'::regclass);


--
-- Name: cobertura_midia_bruto cobertura_midia_bruto_pkey; Type: CONSTRAINT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.cobertura_midia_bruto
    ADD CONSTRAINT cobertura_midia_bruto_pkey PRIMARY KEY (id);


--
-- Name: eventos_bruto eventos_bruto_pkey; Type: CONSTRAINT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.eventos_bruto
    ADD CONSTRAINT eventos_bruto_pkey PRIMARY KEY (id);


--
-- Name: pageviews_bruto pageviews_bruto_pkey; Type: CONSTRAINT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.pageviews_bruto
    ADD CONSTRAINT pageviews_bruto_pkey PRIMARY KEY (id);


--
-- Name: cobertura_midia_bruto uq_cobertura_evento_pais; Type: CONSTRAINT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.cobertura_midia_bruto
    ADD CONSTRAINT uq_cobertura_evento_pais UNIQUE (evento_referencia, pais_cobertura);


--
-- Name: eventos_bruto uq_eventos_nome; Type: CONSTRAINT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.eventos_bruto
    ADD CONSTRAINT uq_eventos_nome UNIQUE (nome_evento);


--
-- Name: pageviews_bruto uq_pageviews_grao; Type: CONSTRAINT; Schema: bronze; Owner: tcc
--

ALTER TABLE ONLY bronze.pageviews_bruto
    ADD CONSTRAINT uq_pageviews_grao UNIQUE (artigo, timestamp_bruto, tipo_acesso, tipo_agente, evento_referencia);


--
-- Name: CONSTRAINT uq_pageviews_grao ON pageviews_bruto; Type: COMMENT; Schema: bronze; Owner: tcc
--

COMMENT ON CONSTRAINT uq_pageviews_grao ON bronze.pageviews_bruto IS 'Garante que a mesma combinacao nao seja inserida duas vezes, prevenindo a dupla contagem detectada na auditoria de setembro de 2026.';


--
-- Name: artigos artigos_pkey; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.artigos
    ADD CONSTRAINT artigos_pkey PRIMARY KEY (id_artigo);


--
-- Name: eventos eventos_pkey; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.eventos
    ADD CONSTRAINT eventos_pkey PRIMARY KEY (id_evento);


--
-- Name: cobertura_diaria pk_silver_cob; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.cobertura_diaria
    ADD CONSTRAINT pk_silver_cob PRIMARY KEY (id_evento, dia);


--
-- Name: cobertura_diaria_pais pk_silver_cob_pais; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.cobertura_diaria_pais
    ADD CONSTRAINT pk_silver_cob_pais PRIMARY KEY (id_evento, pais_cobertura, dia);


--
-- Name: pageviews_diario_artigo pk_silver_pv_artigo; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.pageviews_diario_artigo
    ADD CONSTRAINT pk_silver_pv_artigo PRIMARY KEY (id_artigo, dia, tipo_acesso, tipo_agente);


--
-- Name: pageviews_diario_evento pk_silver_pv_evento; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.pageviews_diario_evento
    ADD CONSTRAINT pk_silver_pv_evento PRIMARY KEY (id_evento, dia, tipo_acesso, tipo_agente);


--
-- Name: artigos uq_silver_artigos; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.artigos
    ADD CONSTRAINT uq_silver_artigos UNIQUE (id_evento, artigo);


--
-- Name: eventos uq_silver_eventos_nome; Type: CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.eventos
    ADD CONSTRAINT uq_silver_eventos_nome UNIQUE (nome_evento);


--
-- Name: idx_eventos_categoria; Type: INDEX; Schema: bronze; Owner: tcc
--

CREATE INDEX idx_eventos_categoria ON bronze.eventos_bruto USING btree (categoria);


--
-- Name: idx_gin_cobertura_midia_payload; Type: INDEX; Schema: bronze; Owner: tcc
--

CREATE INDEX idx_gin_cobertura_midia_payload ON bronze.cobertura_midia_bruto USING gin (payload);


--
-- Name: idx_pageviews_agente; Type: INDEX; Schema: bronze; Owner: tcc
--

CREATE INDEX idx_pageviews_agente ON bronze.pageviews_bruto USING btree (tipo_agente);


--
-- Name: idx_pageviews_artigo; Type: INDEX; Schema: bronze; Owner: tcc
--

CREATE INDEX idx_pageviews_artigo ON bronze.pageviews_bruto USING btree (artigo);


--
-- Name: idx_pageviews_evento; Type: INDEX; Schema: bronze; Owner: tcc
--

CREATE INDEX idx_pageviews_evento ON bronze.pageviews_bruto USING btree (evento_referencia);


--
-- Name: idx_pageviews_timestamp; Type: INDEX; Schema: bronze; Owner: tcc
--

CREATE INDEX idx_pageviews_timestamp ON bronze.pageviews_bruto USING btree (timestamp_bruto);


--
-- Name: idx_silver_artigos_evento; Type: INDEX; Schema: silver; Owner: tcc
--

CREATE INDEX idx_silver_artigos_evento ON silver.artigos USING btree (id_evento);


--
-- Name: idx_silver_pv_agente; Type: INDEX; Schema: silver; Owner: tcc
--

CREATE INDEX idx_silver_pv_agente ON silver.pageviews_diario_artigo USING btree (tipo_agente);


--
-- Name: idx_silver_pv_evento_dia; Type: INDEX; Schema: silver; Owner: tcc
--

CREATE INDEX idx_silver_pv_evento_dia ON silver.pageviews_diario_artigo USING btree (id_evento, dia);


--
-- Name: artigos artigos_id_evento_fkey; Type: FK CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.artigos
    ADD CONSTRAINT artigos_id_evento_fkey FOREIGN KEY (id_evento) REFERENCES silver.eventos(id_evento);


--
-- Name: cobertura_diaria cobertura_diaria_id_evento_fkey; Type: FK CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.cobertura_diaria
    ADD CONSTRAINT cobertura_diaria_id_evento_fkey FOREIGN KEY (id_evento) REFERENCES silver.eventos(id_evento);


--
-- Name: cobertura_diaria_pais cobertura_diaria_pais_id_evento_fkey; Type: FK CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.cobertura_diaria_pais
    ADD CONSTRAINT cobertura_diaria_pais_id_evento_fkey FOREIGN KEY (id_evento) REFERENCES silver.eventos(id_evento);


--
-- Name: pageviews_diario_artigo pageviews_diario_artigo_id_artigo_fkey; Type: FK CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.pageviews_diario_artigo
    ADD CONSTRAINT pageviews_diario_artigo_id_artigo_fkey FOREIGN KEY (id_artigo) REFERENCES silver.artigos(id_artigo);


--
-- Name: pageviews_diario_artigo pageviews_diario_artigo_id_evento_fkey; Type: FK CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.pageviews_diario_artigo
    ADD CONSTRAINT pageviews_diario_artigo_id_evento_fkey FOREIGN KEY (id_evento) REFERENCES silver.eventos(id_evento);


--
-- Name: pageviews_diario_evento pageviews_diario_evento_id_evento_fkey; Type: FK CONSTRAINT; Schema: silver; Owner: tcc
--

ALTER TABLE ONLY silver.pageviews_diario_evento
    ADD CONSTRAINT pageviews_diario_evento_id_evento_fkey FOREIGN KEY (id_evento) REFERENCES silver.eventos(id_evento);


--
-- PostgreSQL database dump complete
--

\unrestrict JZwLwmMJ4HFjfBm4obMGsTMa4I9YMazaTUIIx7zOMdhLkUKCAPAE4hjU42Qvu4G

