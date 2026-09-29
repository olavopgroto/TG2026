-- =====================================================================
-- CAMADA GOLD - 40 eventos (setembro de 2026)
-- Arquivo: sql/ddl/gold/01_gold.sql
--
-- Esquema estrela: 3 dimensoes e 6 fatos, mais 1 view de conveniencia.
-- Roda uma vez, no DBeaver ou via psql. Nao apaga nada: o bloco de
-- recarga esta comentado no fim do arquivo.
--
-- ESCOPO (recorte de 26/09/2026): a camada calcula exatamente as
-- metricas prometidas na Fase 1 do artigo, e nada alem disso. Cada
-- coluna corresponde a uma conta que pode ser explicada em uma frase.
-- O que ficou de fora esta registrado no backlog do projeto: corte
-- otimizado das duas fases, terceira variante da correlacao, escore
-- padronizado, assimetria da curva, cobertura por pais e quebra por
-- tipo de acesso.
--
-- ORDEM DE CARGA (dependencia de chave estrangeira):
--   1. dim_data
--   2. dim_tempo_relativo
--   3. dim_evento
--   4. fato_serie_diaria
--   5. fato_serie_robos
--   6. fato_serie_sensibilidade
--   7. fato_metricas_evento
--   8. fato_correlacao_defasagem
--   9. fato_defasagem_evento
--
-- REGRAS DE NEGOCIO QUE ESTA CAMADA MATERIALIZA:
--
--   ZERO x NULO (21/09/2026): a Silver guarda nulo onde a API nao
--     devolveu dado. Aqui o nulo e preservado nas colunas de valor e
--     convertido em zero apenas nas colunas *_tratado, que sao as
--     series usadas na correlacao cruzada. O ajuste de decaimento
--     ignora nulo e zero, porque o logaritmo exige valor positivo.
--
--   SERIE OFICIAL (26/09/2026): as metricas usam views_principal
--     (artigo do evento somado aos seus titulos anteriores), agente
--     user, com os tres tipos de acesso somados. A curva do conjunto
--     entra como analise de sensibilidade.
--
--   PICO (23/09/2026): o decaimento e medido a partir do pico da serie,
--     nunca da data do evento. Ha eventos com pico em -28 (eleicao
--     brasileira, primeiro turno) e em +55 (ChatGPT).
--
--   BASE (26/09/2026): mediana diaria dos dias -30 a -4, so com dias
--     que tem dado da API. So e valida com no minimo 14 dias com dado
--     e mediana de no minimo 10 visitas/dia (publico) ou 1 materia/dia
--     (midia). Base invalida deixa a amplificacao nula e tira o evento
--     das medias por categoria. Isso exclui por regra, e nao por
--     excecao, os 11 eventos sem artigo antes do evento e o iPhone 15,
--     cuja base de 2 visitas/dia geraria 9.555x.
--
--   CORTE DE SENSIBILIDADE (26/09/2026): no corte X entram os artigos
--     com razao_amplificacao >= X, MAIS o artigo principal e seus
--     aliases, sempre. Artigo com razao nula fica fora de qualquer
--     corte acima de 1x.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS gold;

COMMENT ON SCHEMA gold IS
  'Metricas de analise em esquema estrela, prontas para o Power BI. Carregada pelas pipelines de hop/pipelines/gold/.';


-- =====================================================================
-- DIMENSOES
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. dim_data - calendario real (cerca de 2.206 linhas)
--    De 2019-12-27 (Kobe menos 30) a 2026-01-09 (COP30 mais 60).
--    Necessaria porque o Power BI exige uma tabela de datas continua
--    para qualquer calculo de inteligencia temporal.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.dim_data (
    data                DATE            PRIMARY KEY,
    ano                 SMALLINT        NOT NULL,
    mes                 SMALLINT        NOT NULL,
    dia                 SMALLINT        NOT NULL,
    ano_mes             CHAR(7)         NOT NULL,   -- AAAA-MM, para eixo agrupado
    nome_mes            VARCHAR(12)     NOT NULL,
    trimestre           SMALLINT        NOT NULL,
    dia_da_semana       SMALLINT        NOT NULL,   -- 0 = domingo, 6 = sabado
    nome_dia_semana     VARCHAR(13)     NOT NULL,
    eh_fim_de_semana    BOOLEAN         NOT NULL,

    CONSTRAINT ck_gold_data_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT ck_gold_data_dia CHECK (dia BETWEEN 1 AND 31),
    CONSTRAINT ck_gold_data_trim CHECK (trimestre BETWEEN 1 AND 4),
    CONSTRAINT ck_gold_data_dsem CHECK (dia_da_semana BETWEEN 0 AND 6)
);

COMMENT ON TABLE gold.dim_data IS
  'Calendario continuo cobrindo todas as janelas dos 40 eventos. Marcar como tabela de datas no Power BI.';
COMMENT ON COLUMN gold.dim_data.eh_fim_de_semana IS
  'Serve para investigar o efeito do fim de semana na cobertura jornalistica, que costuma cair aos domingos.';


-- ---------------------------------------------------------------------
-- 2. dim_tempo_relativo - eixo do evento (91 linhas, de -30 a +60)
--    E o eixo que permite comparar eventos de datas diferentes.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.dim_tempo_relativo (
    dias_desde_evento   INT             PRIMARY KEY,
    fase                VARCHAR(20)     NOT NULL,
    eh_pos_evento       BOOLEAN         NOT NULL,
    semana_relativa     INT             NOT NULL,

    CONSTRAINT ck_gold_trel_faixa CHECK (dias_desde_evento BETWEEN -30 AND 60),
    CONSTRAINT ck_gold_trel_fase CHECK (fase IN
        ('pre_evento', 'dia_do_evento', 'primeira_semana', 'primeiro_mes', 'cauda'))
);

COMMENT ON TABLE gold.dim_tempo_relativo IS
  'Eixo de tempo relativo ao evento, de -30 a +60. Fases: pre_evento (-30 a -1), dia_do_evento (0), primeira_semana (1 a 7), primeiro_mes (8 a 30), cauda (31 a 60).';
COMMENT ON COLUMN gold.dim_tempo_relativo.semana_relativa IS
  'Semana em relacao ao evento: 0 = dias 0 a 6, 1 = dias 7 a 13, -1 = dias -7 a -1. Para visuais agregados por semana.';


-- ---------------------------------------------------------------------
-- 3. dim_evento - os 40 eventos (40 linhas)
--    Herda o id_evento da Silver. Guarda so atributos descritivos e
--    marcadores de qualidade; metrica nenhuma.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.dim_evento (
    id_evento                       BIGINT          PRIMARY KEY,
    nome_evento                     TEXT            NOT NULL,
    categoria                       VARCHAR(50)     NOT NULL,
    data_evento                     DATE            NOT NULL,
    artigo_principal                TEXT            NOT NULL,
    palavra_chave_busca             TEXT            NOT NULL,
    data_inicio_janela              DATE            NOT NULL,
    data_fim_janela                 DATE            NOT NULL,

    -- contexto da curadoria
    qtd_artigos                     INT             NOT NULL,
    qtd_aliases                     INT             NOT NULL,

    -- marcadores de qualidade, usados para filtrar e para explicar no texto
    data_criacao_principal          DATE,
    principal_criado_apos_evento    BOOLEAN         NOT NULL,
    dias_sem_dado_principal         INT             NOT NULL,
    paises_sem_materia              INT             NOT NULL,
    dias_com_materia_pos_evento     INT             NOT NULL,

    CONSTRAINT uq_gold_evento_nome UNIQUE (nome_evento),
    CONSTRAINT ck_gold_evento_categoria CHECK (categoria IN
        ('desastre_natural', 'politico', 'morte_figura_publica', 'lancamento_produto', 'ciencia_global')),
    CONSTRAINT ck_gold_evento_janela CHECK (data_fim_janela > data_inicio_janela),
    CONSTRAINT ck_gold_evento_dentro CHECK (data_evento BETWEEN data_inicio_janela AND data_fim_janela),
    CONSTRAINT ck_gold_evento_qtds CHECK (qtd_artigos > 0 AND qtd_aliases >= 0)
);

COMMENT ON TABLE gold.dim_evento IS
  'Dimensao principal do modelo. A categoria fica aqui como atributo (dimensao degenerada), porque com 5 valores uma tabela separada so acrescentaria um join.';
COMMENT ON COLUMN gold.dim_evento.principal_criado_apos_evento IS
  'Verdadeiro quando o artigo principal nasceu no dia do evento ou depois. Explica a ausencia de linha de base em 11 eventos.';
COMMENT ON COLUMN gold.dim_evento.dias_sem_dado_principal IS
  'Dias a partir da data do evento sem nenhum dado no principal nem nos aliases. Esperado: ChatGPT 5, Enchentes RS 5, Incendios Maui 1, zero nos demais.';
COMMENT ON COLUMN gold.dim_evento.paises_sem_materia IS
  'Quantas das 10 colecoes nacionais nao publicaram nenhuma materia na janela. Esperado: 1 em COP30, Enchentes RS, Tina Turner, Cybertruck e Shinzo Abe; zero nos demais.';
COMMENT ON COLUMN gold.dim_evento.dias_com_materia_pos_evento IS
  'Dias com pelo menos uma materia entre o dia 0 e o 60. Marca series de midia esparsas: a Imagem de Sagitario A tem apenas 25.';


-- =====================================================================
-- FATOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4. fato_serie_diaria - evento x dia (3.640 linhas)
--    A tabela central do modelo. Agente user, com os tres tipos de
--    acesso somados, ao lado da serie de cobertura do mesmo dia.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_serie_diaria (
    id_evento                   BIGINT          NOT NULL REFERENCES gold.dim_evento (id_evento),
    dia                         DATE            NOT NULL REFERENCES gold.dim_data (data),
    dias_desde_evento           INT             NOT NULL REFERENCES gold.dim_tempo_relativo (dias_desde_evento),

    -- atencao publica (Wikipedia, agente user, tres acessos somados)
    views_principal             BIGINT,                     -- nulo quando nenhum titulo da familia tem dado no dia
    views_conjunto              BIGINT,
    views_principal_tratado     BIGINT          NOT NULL,   -- nulo convertido em zero, serie usada na correlacao
    artigos_com_dado            INT             NOT NULL,

    -- cobertura midiatica (Media Cloud, soma das 10 colecoes)
    materias                    INT             NOT NULL,
    paises_com_materia          INT             NOT NULL,

    -- normalizacao (as grandezas sao 364 milhoes de visitas contra 195.771 materias)
    pct_pico_publico            NUMERIC(9,6),
    pct_pico_midia              NUMERIC(9,6),
    dias_desde_pico_publico     INT             NOT NULL,
    dias_desde_pico_midia       INT             NOT NULL,

    CONSTRAINT pk_gold_serie_diaria PRIMARY KEY (id_evento, dia),
    CONSTRAINT ck_gold_serie_tratado CHECK (views_principal_tratado = COALESCE(views_principal, 0)),
    CONSTRAINT ck_gold_serie_nao_negativo CHECK (
        COALESCE(views_principal, 0) >= 0
        AND COALESCE(views_conjunto, 0) >= 0
        AND materias >= 0
        AND artigos_com_dado >= 0
        AND paises_com_materia BETWEEN 0 AND 10),
    CONSTRAINT ck_gold_serie_pct CHECK (
        (pct_pico_publico IS NULL OR pct_pico_publico BETWEEN 0 AND 1)
        AND (pct_pico_midia IS NULL OR pct_pico_midia BETWEEN 0 AND 1)),
    CONSTRAINT ck_gold_serie_familia CHECK (
        views_principal IS NULL OR views_conjunto IS NULL OR views_conjunto >= views_principal)
);

CREATE INDEX IF NOT EXISTS idx_gold_serie_evento_rel
    ON gold.fato_serie_diaria (id_evento, dias_desde_evento);

COMMENT ON TABLE gold.fato_serie_diaria IS
  'As duas curvas de atencao por evento e dia, ja normalizadas pelo pico. E a tabela que alimenta a maior parte dos visuais.';
COMMENT ON COLUMN gold.fato_serie_diaria.views_principal_tratado IS
  'Serie continua usada na correlacao cruzada: o nulo vira zero. A trava do banco garante a igualdade com COALESCE(views_principal, 0).';
COMMENT ON COLUMN gold.fato_serie_diaria.pct_pico_publico IS
  'views_principal dividido pelo maior valor da serie do evento. Deixa toda curva entre 0 e 1, o que permite comparar eventos de tamanhos muito diferentes no mesmo grafico. Nulo quando o dia nao tem dado.';
COMMENT ON COLUMN gold.fato_serie_diaria.dias_desde_pico_publico IS
  'Dias contados a partir do pico da propria serie, e nao da data do evento. Negativo antes do pico. E o eixo do ajuste de decaimento.';


-- ---------------------------------------------------------------------
-- 5. fato_serie_robos - evento x dia x agente (7.280 linhas)
--    Curva do principal para spider e automated. Serve de controle:
--    se o publico reage ao evento e os robos nao, o que se mede e
--    atencao humana.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_serie_robos (
    id_evento                   BIGINT          NOT NULL REFERENCES gold.dim_evento (id_evento),
    dia                         DATE            NOT NULL REFERENCES gold.dim_data (data),
    dias_desde_evento           INT             NOT NULL REFERENCES gold.dim_tempo_relativo (dias_desde_evento),
    tipo_agente                 VARCHAR(20)     NOT NULL,

    views_principal             BIGINT,
    views_principal_tratado     BIGINT          NOT NULL,
    pct_pico                    NUMERIC(9,6),

    CONSTRAINT pk_gold_serie_robos PRIMARY KEY (id_evento, dia, tipo_agente),
    CONSTRAINT ck_gold_robos_agente CHECK (tipo_agente IN ('spider', 'automated')),
    CONSTRAINT ck_gold_robos_tratado CHECK (views_principal_tratado = COALESCE(views_principal, 0)),
    CONSTRAINT ck_gold_robos_pct CHECK (pct_pico IS NULL OR pct_pico BETWEEN 0 AND 1)
);

COMMENT ON TABLE gold.fato_serie_robos IS
  'Curva de controle. Fica fora do modelo principal do Power BI e alimenta o visual que demonstra que o fenomeno medido e humano.';


-- ---------------------------------------------------------------------
-- 6. fato_serie_sensibilidade - evento x dia x corte (14.560 linhas)
--    A curva do conjunto recalculada mantendo so os artigos acima de
--    cada corte de amplificacao. Corrige o defeito conhecido do
--    conjunto: em lancamento de produto, o volume vem de artigos
--    grandes que nem reagem ao evento (Apple, iOS, USB-C).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_serie_sensibilidade (
    id_evento               BIGINT          NOT NULL REFERENCES gold.dim_evento (id_evento),
    dia                     DATE            NOT NULL REFERENCES gold.dim_data (data),
    dias_desde_evento       INT             NOT NULL REFERENCES gold.dim_tempo_relativo (dias_desde_evento),
    corte_amplificacao      NUMERIC(4,1)    NOT NULL,

    views_conjunto          BIGINT,
    artigos_no_corte        INT             NOT NULL,
    pct_pico                NUMERIC(9,6),

    CONSTRAINT pk_gold_sensibilidade PRIMARY KEY (id_evento, dia, corte_amplificacao),
    CONSTRAINT ck_gold_sens_corte CHECK (corte_amplificacao IN (1.0, 2.0, 3.0, 5.0)),
    CONSTRAINT ck_gold_sens_artigos CHECK (artigos_no_corte > 0),
    CONSTRAINT ck_gold_sens_pct CHECK (pct_pico IS NULL OR pct_pico BETWEEN 0 AND 1)
);

CREATE INDEX IF NOT EXISTS idx_gold_sens_corte
    ON gold.fato_serie_sensibilidade (corte_amplificacao, id_evento);

COMMENT ON TABLE gold.fato_serie_sensibilidade IS
  'Formato longo: o corte e um valor da coluna, nao uma coluna. Acrescentar um corte novo (10x, por exemplo) e carregar mais linhas, sem mexer na estrutura.';
COMMENT ON COLUMN gold.fato_serie_sensibilidade.corte_amplificacao IS
  'Razao minima de amplificacao para o artigo entrar na soma. 1.0 = todos os artigos do evento. O principal e seus aliases entram em todos os cortes, independente da razao.';
COMMENT ON COLUMN gold.fato_serie_sensibilidade.artigos_no_corte IS
  'Quantos artigos do evento sobreviveram ao corte. Cai conforme o corte sobe e deve ser sempre pelo menos 1, o principal.';


-- ---------------------------------------------------------------------
-- 7. fato_metricas_evento - evento x fonte (80 linhas)
--    Uma linha por evento e por fonte. E onde a pergunta de pesquisa
--    e respondida no nivel do evento.
--
--    As metricas se dividem em dois blocos: as contadas direto da
--    serie (pico, meia-vida observada, dias ate 10%, volume, base e
--    amplificacao) e as ajustadas por regressao (decaimento simples e
--    em duas fases). As duas meia-vidas, a contada e a ajustada,
--    servem de validacao uma da outra.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_metricas_evento (
    id_evento                   BIGINT          NOT NULL REFERENCES gold.dim_evento (id_evento),
    fonte                       VARCHAR(20)     NOT NULL,

    -- bloco 1: contado direto da serie
    valor_pico                  BIGINT          NOT NULL,
    dia_pico                    INT             NOT NULL,   -- em dias desde o evento
    data_pico                   DATE            NOT NULL,
    meia_vida_observada         INT,                        -- dias apos o pico ate cair abaixo de metade dele
    dias_ate_10pct              INT,                        -- dias apos o pico ate cair abaixo de 10% dele
    volume_30d                  BIGINT          NOT NULL,   -- soma dos dias 0 a 29 contados do evento

    -- linha de base e amplificacao
    base_mediana                NUMERIC(14,2),
    base_dias_com_dado          INT             NOT NULL,
    base_valida                 BOOLEAN         NOT NULL,
    base_motivo                 VARCHAR(40)     NOT NULL,
    amplificacao                NUMERIC(14,2),

    -- bloco 2: decaimento exponencial simples, a partir do pico
    lambda_simples              NUMERIC(14,8),
    meia_vida_simples           NUMERIC(10,2),
    r2_simples                  NUMERIC(6,4),
    n_pontos_simples            INT             NOT NULL,

    -- decaimento em duas fases, corte fixo em 7 dias apos o pico
    lambda_fase1                NUMERIC(14,8),
    meia_vida_fase1             NUMERIC(10,2),
    r2_fase1                    NUMERIC(6,4),
    n_pontos_fase1              INT             NOT NULL,
    lambda_fase2                NUMERIC(14,8),
    meia_vida_fase2             NUMERIC(10,2),
    r2_fase2                    NUMERIC(6,4),
    n_pontos_fase2              INT             NOT NULL,
    r2_combinado_fases          NUMERIC(6,4),
    ganho_r2_sobre_simples      NUMERIC(7,4),

    CONSTRAINT pk_gold_metricas PRIMARY KEY (id_evento, fonte),
    CONSTRAINT ck_gold_metricas_fonte CHECK (fonte IN ('publico', 'midia')),
    CONSTRAINT ck_gold_metricas_pico CHECK (valor_pico >= 0 AND dia_pico BETWEEN -30 AND 60),
    CONSTRAINT ck_gold_metricas_base CHECK (
        (base_valida = true  AND base_mediana IS NOT NULL AND amplificacao IS NOT NULL)
     OR (base_valida = false AND amplificacao IS NULL)),
    CONSTRAINT ck_gold_metricas_r2 CHECK (
        (r2_simples         IS NULL OR r2_simples         BETWEEN 0 AND 1)
    AND (r2_fase1           IS NULL OR r2_fase1           BETWEEN 0 AND 1)
    AND (r2_fase2           IS NULL OR r2_fase2           BETWEEN 0 AND 1)
    AND (r2_combinado_fases IS NULL OR r2_combinado_fases BETWEEN 0 AND 1)),
    CONSTRAINT ck_gold_metricas_meia_vida CHECK (
        (meia_vida_observada IS NULL OR meia_vida_observada >= 0)
    AND (dias_ate_10pct      IS NULL OR dias_ate_10pct      >= 0))
);

COMMENT ON TABLE gold.fato_metricas_evento IS
  'Metricas de ciclo de vida por evento e fonte. fonte = publico usa views_principal (agente user); fonte = midia usa materias.';
COMMENT ON COLUMN gold.fato_metricas_evento.dia_pico IS
  'Dia do pico em relacao ao evento. Valores fora do intervalo 0 a 2 sao resultado e nao erro: eleicao brasileira em -28 (primeiro turno) e ChatGPT em +55.';
COMMENT ON COLUMN gold.fato_metricas_evento.meia_vida_observada IS
  'Contagem direta: quantos dias apos o pico a serie levou para cair abaixo da metade do pico. Nula quando a serie nao cai a metade dentro da janela. Serve para conferir a meia-vida do modelo.';
COMMENT ON COLUMN gold.fato_metricas_evento.dias_ate_10pct IS
  'Dias apos o pico ate a serie cair abaixo de 10% dele. E o fim pratico do ciclo de atencao. Nulo quando isso nao acontece dentro da janela.';
COMMENT ON COLUMN gold.fato_metricas_evento.volume_30d IS
  'Soma dos valores dos dias 0 a 29 contados da data do evento. Mede o tamanho total do ciclo, e nao so a altura do pico.';
COMMENT ON COLUMN gold.fato_metricas_evento.base_mediana IS
  'Mediana diaria dos dias -30 a -4, so com dias que tem dado da API. Mediana e nao media, para resistir a repique pre-evento.';
COMMENT ON COLUMN gold.fato_metricas_evento.base_valida IS
  'Falso quando ha menos de 14 dias com dado no periodo de base, ou quando a mediana fica abaixo do piso da fonte (10 visitas/dia no publico, 1 materia/dia na midia). Evento com base invalida sai das medias de amplificacao por categoria.';
COMMENT ON COLUMN gold.fato_metricas_evento.base_motivo IS
  'Por que a base foi aceita ou recusada: ok, poucos_dias_com_dado, abaixo_do_piso, artigo_inexistente_antes.';
COMMENT ON COLUMN gold.fato_metricas_evento.amplificacao IS
  'valor_pico dividido por base_mediana. Nula quando a base nao e valida.';
COMMENT ON COLUMN gold.fato_metricas_evento.lambda_simples IS
  'Velocidade da queda. E o negativo da inclinacao da reta ajustada sobre ln(valor) contra dias desde o pico, usando so dias com valor positivo. Nulo quando ha menos de 5 pontos validos.';
COMMENT ON COLUMN gold.fato_metricas_evento.meia_vida_simples IS
  'ln(2) dividido por lambda_simples, em dias. Nula quando lambda e nulo ou nao positivo, ou seja, quando a serie nao decai no periodo.';
COMMENT ON COLUMN gold.fato_metricas_evento.lambda_fase1 IS
  'Mesma conta do lambda_simples, restrita aos 7 primeiros dias apos o pico. A fase 2 cobre do oitavo dia ate o fim da janela.';
COMMENT ON COLUMN gold.fato_metricas_evento.r2_combinado_fases IS
  'Media dos R2 das duas fases, ponderada pelo numero de dias de cada uma.';
COMMENT ON COLUMN gold.fato_metricas_evento.ganho_r2_sobre_simples IS
  'r2_combinado_fases menos r2_simples. Positivo indica que o ajuste em duas fases descreve melhor a curva, como preve Candia et al. (2019).';


-- ---------------------------------------------------------------------
-- 8. fato_correlacao_defasagem - evento x variante x defasagem
--    (40 x 2 x 21 = 1.680 linhas)
--    Guarda o correlograma inteiro, e nao so o maximo, para mostrar se
--    o pico de correlacao e nitido ou chapado.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_correlacao_defasagem (
    id_evento           BIGINT          NOT NULL REFERENCES gold.dim_evento (id_evento),
    variante            VARCHAR(20)     NOT NULL,
    defasagem           INT             NOT NULL,

    correlacao          NUMERIC(8,6),
    n_pares             INT             NOT NULL,
    limite_critico      NUMERIC(8,6)    NOT NULL,
    eh_significativa    BOOLEAN         NOT NULL,

    CONSTRAINT pk_gold_correlacao PRIMARY KEY (id_evento, variante, defasagem),
    CONSTRAINT ck_gold_corr_variante CHECK (variante IN ('nivel_linear', 'nivel_log')),
    CONSTRAINT ck_gold_corr_defasagem CHECK (defasagem BETWEEN -10 AND 10),
    CONSTRAINT ck_gold_corr_valor CHECK (correlacao IS NULL OR correlacao BETWEEN -1 AND 1),
    CONSTRAINT ck_gold_corr_pares CHECK (n_pares > 0)
);

COMMENT ON TABLE gold.fato_correlacao_defasagem IS
  'Correlacao cruzada entre atencao publica e cobertura midiatica. Convencao de sinal: defasagem positiva significa que a midia antecede o publico.';
COMMENT ON COLUMN gold.fato_correlacao_defasagem.variante IS
  'nivel_linear = valores como estao; nivel_log = ln(1 + valor). A versao em log e necessaria porque o pico e centenas de vezes maior que a base, e sem ela so os dias em volta do pico pesam no resultado.';
COMMENT ON COLUMN gold.fato_correlacao_defasagem.limite_critico IS
  'Dois dividido pela raiz de n_pares. Correlacao acima disso em modulo e considerada significativa ao nivel usual de 5%.';


-- ---------------------------------------------------------------------
-- 9. fato_defasagem_evento - evento x variante (80 linhas)
--    Resumo da tabela anterior, mais a validacao independente pela
--    distancia entre os picos das duas curvas.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_defasagem_evento (
    id_evento                   BIGINT          NOT NULL REFERENCES gold.dim_evento (id_evento),
    variante                    VARCHAR(20)     NOT NULL,

    defasagem_otima             INT,
    correlacao_maxima           NUMERIC(8,6),
    eh_significativa            BOOLEAN         NOT NULL,
    lag_por_pico                INT             NOT NULL,
    concorda_com_lag_por_pico   BOOLEAN,
    dias_nulos_publico          INT             NOT NULL,
    dias_sem_materia            INT             NOT NULL,

    CONSTRAINT pk_gold_defasagem PRIMARY KEY (id_evento, variante),
    CONSTRAINT ck_gold_def_variante CHECK (variante IN ('nivel_linear', 'nivel_log')),
    CONSTRAINT ck_gold_def_faixa CHECK (defasagem_otima IS NULL OR defasagem_otima BETWEEN -10 AND 10),
    CONSTRAINT ck_gold_def_valor CHECK (correlacao_maxima IS NULL OR correlacao_maxima BETWEEN -1 AND 1)
);

COMMENT ON TABLE gold.fato_defasagem_evento IS
  'Resumo do correlograma por evento e variante. Se as duas variantes apontarem o mesmo sentido, o resultado fica dificil de contestar.';
COMMENT ON COLUMN gold.fato_defasagem_evento.defasagem_otima IS
  'Deslocamento em dias no qual a correlacao entre as duas curvas foi a maior. Negativo significa que o publico se moveu antes da imprensa.';
COMMENT ON COLUMN gold.fato_defasagem_evento.lag_por_pico IS
  'Dia do pico da midia menos o dia do pico do publico. Metrica de validacao independente da estatistica: positivo significa midia antes.';
COMMENT ON COLUMN gold.fato_defasagem_evento.concorda_com_lag_por_pico IS
  'Verdadeiro quando defasagem_otima e lag_por_pico tem o mesmo sinal. Nulo quando algum dos dois e zero.';
COMMENT ON COLUMN gold.fato_defasagem_evento.dias_nulos_publico IS
  'Dias da janela que entraram como zero por ausencia de dado. Importa em ChatGPT, Enchentes do RS e Incendios de Maui, cujos nulos caem logo apos o evento.';


-- =====================================================================
-- VIEW DE CONVENIENCIA
-- Nenhum calculo novo: apenas gira o formato longo da sensibilidade
-- para o formato largo, que e mais comodo em alguns visuais do Power BI.
-- =====================================================================
CREATE OR REPLACE VIEW gold.vw_sensibilidade_larga AS
SELECT
    id_evento,
    dia,
    dias_desde_evento,
    MAX(CASE WHEN corte_amplificacao = 1.0 THEN views_conjunto END)   AS views_1x,
    MAX(CASE WHEN corte_amplificacao = 2.0 THEN views_conjunto END)   AS views_2x,
    MAX(CASE WHEN corte_amplificacao = 3.0 THEN views_conjunto END)   AS views_3x,
    MAX(CASE WHEN corte_amplificacao = 5.0 THEN views_conjunto END)   AS views_5x,
    MAX(CASE WHEN corte_amplificacao = 1.0 THEN artigos_no_corte END) AS artigos_1x,
    MAX(CASE WHEN corte_amplificacao = 2.0 THEN artigos_no_corte END) AS artigos_2x,
    MAX(CASE WHEN corte_amplificacao = 3.0 THEN artigos_no_corte END) AS artigos_3x,
    MAX(CASE WHEN corte_amplificacao = 5.0 THEN artigos_no_corte END) AS artigos_5x
FROM gold.fato_serie_sensibilidade
GROUP BY id_evento, dia, dias_desde_evento;

COMMENT ON VIEW gold.vw_sensibilidade_larga IS
  'Pivot da fato_serie_sensibilidade. Nao contem regra de negocio nem calculo: so troca linhas por colunas.';


-- =====================================================================
-- CONFERENCIA (rodar depois do arquivo, comparar com o esperado)
-- Esperado: 9 tabelas e 1 view, todas vazias.
-- =====================================================================
-- SELECT table_name, table_type
--   FROM information_schema.tables
--  WHERE table_schema = 'gold'
--  ORDER BY table_type, table_name;
--
-- SELECT table_name, COUNT(*) AS colunas
--   FROM information_schema.columns
--  WHERE table_schema = 'gold'
--  GROUP BY table_name
--  ORDER BY table_name;


-- =====================================================================
-- BLOCO DE RECARGA (descomentar so quando precisar refazer a camada)
-- A ordem respeita as chaves estrangeiras.
-- =====================================================================
-- TRUNCATE TABLE
--     gold.fato_defasagem_evento,
--     gold.fato_correlacao_defasagem,
--     gold.fato_metricas_evento,
--     gold.fato_serie_sensibilidade,
--     gold.fato_serie_robos,
--     gold.fato_serie_diaria,
--     gold.dim_evento,
--     gold.dim_tempo_relativo,
--     gold.dim_data;
