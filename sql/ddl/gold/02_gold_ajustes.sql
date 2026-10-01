-- =====================================================================
-- CAMADA GOLD - AJUSTES (setembro de 2026)
-- Arquivo: sql/ddl/gold/02_gold_ajustes.sql
--
-- Roda DEPOIS do 01_gold.sql. Nao recria nada: apenas corrige um
-- comentario errado e acrescenta uma coluna a uma tabela ainda vazia.
-- Nenhuma tabela carregada e tocada.
--
-- POR QUE ESTE ARQUIVO EXISTE, E NAO UMA EDICAO DO 01:
-- o 01 registra a camada como foi criada; este registra o que mudou
-- depois e por que. O historico fica legivel.
--
-- -----------------------------------------------------------------
-- AJUSTE 1: sinal do lag_por_pico (correcao de erro)
--
-- O comentario original dizia "dia do pico da midia menos o dia do
-- pico do publico". A conta estava invertida em relacao a convencao
-- do projeto, que foi provada com uma serie artificial: defasagem
-- positiva significa midia antes. Pela formula antiga, o Furacao Ian
-- (midia no dia 1, publico no dia 2) daria -1, ou seja, publico antes,
-- o oposto do que os dados mostram.
--
-- AJUSTE 2: coluna leitura
--
-- A conclusao de cada evento passa a ficar gravada em uma coluna, em
-- vez de exigir o cruzamento de tres colunas na hora de ler. A regra
-- e aplicada na pipeline, em transform visivel, e e a mesma para os
-- 40 eventos.
--
-- As seis leituras possiveis:
--
--   inicio_nao_observavel  o artigo principal foi criado depois do dia
--                          do evento, entao a Wikipedia nao registra o
--                          inicio da atencao (ChatGPT, Enchentes do RS
--                          e Incendios de Maui)
--   picos_distantes        os picos das duas curvas estao a mais de 7
--                          dias um do outro, o que acontece em eventos
--                          com duas datas ou que duram semanas (COP28,
--                          COP30 e a eleicao brasileira, esta com
--                          primeiro e segundo turno). Comparar picos
--                          nao se aplica a esses casos
--   inconclusivo           a correlacao nao e significativa, ou a
--                          correlacao e a distancia entre os picos
--                          apontam direcoes diferentes
--   simultaneo             as duas medidas ficam dentro da tolerancia
--                          de um dia
--   midia_antes            as duas medidas indicam a imprensa na frente
--   publico_antes          as duas medidas indicam o publico na frente
--
-- SOBRE A TOLERANCIA DE UM DIA: a Wikimedia fecha o dia em UTC e as
-- materias vem de dez paises em fusos diferentes, entao um dia de
-- diferenca esta dentro da imprecisao da propria medida. Sem ela,
-- eventos como Kobe Bryant (correlacao 0, picos a 1 dia) cairiam em
-- inconclusivo sem motivo real.
--
-- SOBRE O LIMIAR DE SETE DIAS: a distancia entre os picos nos 40
-- eventos vale 0 em 19 deles, 1 em 16, depois 3, 4, 10, 13 e 29.
-- Nenhum evento fica entre 2 e 9 dias, entao qualquer limiar nessa
-- faixa produz o mesmo resultado. A separacao esta no dado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- AJUSTE 1
-- ---------------------------------------------------------------------
COMMENT ON COLUMN gold.fato_defasagem_evento.lag_por_pico IS
  'Dia do pico do publico menos o dia do pico da midia. Metrica de validacao independente da estatistica: positivo significa midia antes, mesma convencao da defasagem.';

COMMENT ON COLUMN gold.fato_defasagem_evento.concorda_com_lag_por_pico IS
  'Verdadeiro quando a defasagem e a distancia entre os picos apontam a mesma direcao, com tolerancia de um dia nas duas medidas.';


-- ---------------------------------------------------------------------
-- AJUSTE 2
-- ---------------------------------------------------------------------
ALTER TABLE gold.fato_defasagem_evento
    ADD COLUMN IF NOT EXISTS leitura VARCHAR(30);

UPDATE gold.fato_defasagem_evento
   SET leitura = 'inconclusivo'
 WHERE leitura IS NULL;

ALTER TABLE gold.fato_defasagem_evento
    ALTER COLUMN leitura SET NOT NULL;

ALTER TABLE gold.fato_defasagem_evento
    DROP CONSTRAINT IF EXISTS ck_gold_def_leitura;

ALTER TABLE gold.fato_defasagem_evento
    ADD CONSTRAINT ck_gold_def_leitura CHECK (leitura IN
        ('simultaneo', 'midia_antes', 'publico_antes',
         'inconclusivo', 'inicio_nao_observavel', 'picos_distantes'));

COMMENT ON COLUMN gold.fato_defasagem_evento.leitura IS
  'Conclusao do evento em uma palavra, calculada por regra na pipeline: simultaneo, midia_antes, publico_antes, inconclusivo, inicio_nao_observavel ou picos_distantes.';


-- ---------------------------------------------------------------------
-- AJUSTE 3: nota sobre a coluna que saiu de uso
--
-- A correlacao passou a ignorar os dias sem dado, em vez de converte-los
-- em zero. O teste que motivou a mudanca: com a conversao, o iPhone 15
-- aparecia com defasagem de 8 dias; sem ela, a defasagem cai para zero,
-- com correlacao praticamente igual (0,475 contra 0,492). A defasagem
-- era um artefato: a serie do publico virava um degrau, porque o artigo
-- nao existia nos 29 primeiros dias.
--
-- A coluna foi mantida porque registra a regra revista e porque remove-la
-- exigiria recarregar duas tabelas ja validadas.
-- ---------------------------------------------------------------------
COMMENT ON COLUMN gold.fato_serie_diaria.views_principal_tratado IS
  'Serie com o nulo convertido em zero. Nao e mais usada no calculo: a correlacao passou a ignorar os dias sem dado, porque converte-los em zero gerava defasagem falsa. Mantida como registro da regra revista e como checagem de coerencia com a Silver.';

COMMENT ON COLUMN gold.fato_serie_robos.views_principal_tratado IS
  'Serie com o nulo convertido em zero. Nao e usada no calculo, pela mesma razao registrada em gold.fato_serie_diaria.';


-- =====================================================================
-- CONFERENCIA (rodar depois do arquivo)
-- =====================================================================
-- SELECT column_name, data_type, is_nullable
--   FROM information_schema.columns
--  WHERE table_schema = 'gold' AND table_name = 'fato_defasagem_evento'
--  ORDER BY ordinal_position;
--
-- esperado: 10 colunas, a ultima leitura, character varying, NO
