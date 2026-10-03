-----------------------------------------------------
-- Fase 1 — Preparação do banco
-- Enunciado 1: 
-- No pgAdmin, crie o banco de dados cafe_dw com codificação UTF8 (registre essa etapa
-- como comentário no script). Na Query Tool desse banco, crie os schemas raw, staging e
-- dw, usando IF NOT EXISTS, e escreva uma consulta a information_schema.schemata que
-- devolva exatamente essas três linhas
-----------------------------------------------------

create schema if not exists raw;
create schema if not exists staging;
create schema if not exists dw;

-- Verificando
select SCHEMA_NAME
from information_schema.schemata
where schema_name in('raw', 'staging', 'dw' );


----------------------------------------------------------------------
-- Fase 2 - Camada Raw (Extract) O CSV entra no banco sem nenhuma interpretação. Nenhum valor é alterado
-- nesta fase.
-- Enunciado 2: 
-- Crie a tabela raw.cafe_sales com as oito colunas da Tabela 1, todas do tipo TEXT, sem
-- nenhuma restrição e na mesma ordem do arquivo CSV. Inicie o bloco com DROP TABLE IF
-- EXISTS ... CASCADE.
----------------------------------------------------------------------

DROP TABLE IF EXISTS raw.cafe_sales CASCADE;
CREATE TABLE raw.cafe_sales (
    transaction_id TEXT,
    item TEXT,
    quantity TEXT,
    price_per_unit TEXT,
    total_spent TEXT,
    payment_method TEXT,
    location TEXT,
    transaction_date TEXT
);

-----------------------------------------------------
-- Enunciado 3: 
-- Importe dirty_cafe_sales.csv para raw.cafe_sales com Import/Export Data… do
-- pgAdmin (Format csv, Encoding UTF8, Header ligado, Delimiter vírgula). Registre em
-- comentário as opções usadas e escreva duas consultas de validação: o total de linhas (10.000
-- esperadas) e o total de valores distintos de transaction_id.
-----------------------------------------------------

SELECT COUNT(*) FROM raw.cafe_sales; -- Esperado: 10000
SELECT COUNT(DISTINCT transaction_id) FROM raw.cafe_sales;

-----------------------------------------------------
-- Fase 3 — Perfilamento da sujeira
-- Enunciado 4: 
-- Para cada uma das colunas item, payment_method e location da camada raw, escreva uma
-- consulta que liste cada valor distinto e a quantidade de linhas em que ele aparece, da maior
-- para a menor quantidade. Os valores NULL também devem aparecer.
-----------------------------------------------------

-- 1. Perfilamento distinto da coluna 'item'
SELECT 
    item, 
    COUNT(*) AS quantidade
FROM raw.cafe_sales
GROUP BY item
ORDER BY quantidade DESC;

-- 2. Perfilamento distinto da coluna 'payment_method'
SELECT 
    payment_method, 
    COUNT(*) AS quantidade
FROM raw.cafe_sales
GROUP BY payment_method
ORDER BY quantidade DESC;

-- 3. Perfilamento distinto da coluna 'location'
SELECT 
    location, 
    COUNT(*) AS quantidade
FROM raw.cafe_sales
GROUP BY location
ORDER BY quantidade DESC;

-----------------------------------------------------
-- Enunciado 5: 
-- Escreva uma única consulta, usando UNION ALL, que devolva uma linha para cada coluna
-- da camada raw, exceto transaction_id, com quatro colunas: coluna (o nome da coluna,
-- como texto), qtd_error, qtd_unknown e qtd_vazio (valor NULL ou texto vazio após TRIM).
-- O resultado terá sete linhas
-----------------------------------------------------

SELECT 
    'item' AS coluna,
    COUNT(CASE WHEN TRIM(item) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(item) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN item IS NULL OR TRIM(item) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales

UNION ALL

SELECT 
    'quantity' AS coluna,
    COUNT(CASE WHEN TRIM(quantity) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(quantity) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN quantity IS NULL OR TRIM(quantity) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales

UNION ALL

SELECT 
    'price_per_unit' AS coluna,
    COUNT(CASE WHEN TRIM(price_per_unit) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(price_per_unit) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN price_per_unit IS NULL OR TRIM(price_per_unit) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales

UNION ALL

SELECT 
    'total_spent' AS coluna,
    COUNT(CASE WHEN TRIM(total_spent) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(total_spent) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN total_spent IS NULL OR TRIM(total_spent) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales

UNION ALL

SELECT 
    'payment_method' AS coluna,
    COUNT(CASE WHEN TRIM(payment_method) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(payment_method) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN payment_method IS NULL OR TRIM(payment_method) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales

UNION ALL

SELECT 
    'location' AS coluna,
    COUNT(CASE WHEN TRIM(location) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(location) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN location IS NULL OR TRIM(location) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales

UNION ALL

SELECT 
    'transaction_date' AS coluna,
    COUNT(CASE WHEN TRIM(transaction_date) = 'ERROR' THEN 1 END) AS qtd_error,
    COUNT(CASE WHEN TRIM(transaction_date) = 'UNKNOWN' THEN 1 END) AS qtd_unknown,
    COUNT(CASE WHEN transaction_date IS NULL OR TRIM(transaction_date) = '' THEN 1 END) AS qtd_vazio
FROM raw.cafe_sales;

-----------------------------------------------------
-- Fase 4 — Staging: tipagem
-- Começa a transformação: textos viram números e datas, e os três marcadores de
-- “não sei” viram NULL.
-- A limpeza será feita em dois degraus. Primeiro, uma tabela tipada e permissiva, que aceita NULL
-- em tudo menos na chave. Depois, na Fase 5, os valores recuperáveis são recuperados e só as linhas
-- completas seguem para a tabela final.
-----------------------------------------------------

-----------------------------------------------------
-- Enunciado 6:
-- Crie staging.cafe_tipada conforme a Tabela 6 e carregue-a a partir de raw.cafe_sales
-- com um único INSERT ... SELECT, precedido de TRUNCATE. Em todas as colunas, aplique
-- TRIM e transforme '', 'ERROR' e 'UNKNOWN' em NULL antes de qualquer conversão; converta
-- as colunas numéricas com CAST e a data com TO_DATE no formato 'YYYY-MM-DD'. Em seguida,
-- escreva uma consulta que conte os NULL de cada coluna da tabela tipada. Para cada coluna,
-- o total deve ser igual à soma qtd_error + qtd_unknown + qtd_vazio obtida no Enunciado
-- 5.
-----------------------------------------------------


-- 1. DDL — Criação da tabela staging.cafe_tipada (Tabela 6)
DROP TABLE IF EXISTS staging.cafe_tipada CASCADE;

CREATE TABLE staging.cafe_tipada (
    transaction_id VARCHAR(20) PRIMARY KEY,
    item VARCHAR(20),
    quantity INTEGER,
    price_per_unit NUMERIC(6,2),
    total_spent NUMERIC(8,2),
    payment_method VARCHAR(20),
    location VARCHAR(20),
    transaction_date DATE
);

-- 2. Limpeza prévia e carga com unificação de marcadores de sujeira em NULL e conversão de tipos
TRUNCATE TABLE staging.cafe_tipada;

INSERT INTO staging.cafe_tipada (
    transaction_id,
    item,
    quantity,
    price_per_unit,
    total_spent,
    payment_method,
    location,
    transaction_date
)
SELECT 
    TRIM(transaction_id) AS transaction_id,
    
    NULLIF(NULLIF(NULLIF(TRIM(item), 'ERROR'), 'UNKNOWN'), '') AS item,
    
    CAST(
        NULLIF(NULLIF(NULLIF(TRIM(quantity), 'ERROR'), 'UNKNOWN'), '') 
        AS INTEGER
    ) AS quantity,
    
    CAST(
        NULLIF(NULLIF(NULLIF(TRIM(price_per_unit), 'ERROR'), 'UNKNOWN'), '') 
        AS NUMERIC(6,2)
    ) AS price_per_unit,
    
    CAST(
        NULLIF(NULLIF(NULLIF(TRIM(total_spent), 'ERROR'), 'UNKNOWN'), '') 
        AS NUMERIC(8,2)
    ) AS total_spent,
    
    NULLIF(NULLIF(NULLIF(TRIM(payment_method), 'ERROR'), 'UNKNOWN'), '') AS payment_method,
    
    NULLIF(NULLIF(NULLIF(TRIM(location), 'ERROR'), 'UNKNOWN'), '') AS location,
    
    TO_DATE(
        NULLIF(NULLIF(NULLIF(TRIM(transaction_date), 'ERROR'), 'UNKNOWN'), ''), 
        'YYYY-MM-DD'
    ) AS transaction_date

FROM raw.cafe_sales;

-- 3. Consulta de Validação — Contagem de NULLs por coluna (Formato Lado a Lado / 1 linha)
SELECT 
    COUNT(CASE WHEN item IS NULL THEN 1 END) AS null_item,
    COUNT(CASE WHEN quantity IS NULL THEN 1 END) AS null_quantity,
    COUNT(CASE WHEN price_per_unit IS NULL THEN 1 END) AS null_price_per_unit,
    COUNT(CASE WHEN total_spent IS NULL THEN 1 END) AS null_total_spent,
    COUNT(CASE WHEN payment_method IS NULL THEN 1 END) AS null_payment_method,
    COUNT(CASE WHEN location IS NULL THEN 1 END) AS null_location,
    COUNT(CASE WHEN transaction_date IS NULL THEN 1 END) AS null_transaction_date
FROM staging.cafe_tipada;

-- 3b. Consulta de Validação Alternativa — Formato Vertical (UNION ALL de 7 linhas, idêntico ao Enunciado 5)
SELECT 'item' AS coluna, COUNT(*) AS total_null FROM staging.cafe_tipada WHERE item IS NULL
UNION ALL
SELECT 'quantity', COUNT(*) FROM staging.cafe_tipada WHERE quantity IS NULL
UNION ALL
SELECT 'price_per_unit', COUNT(*) FROM staging.cafe_tipada WHERE price_per_unit IS NULL
UNION ALL
SELECT 'total_spent', COUNT(*) FROM staging.cafe_tipada WHERE total_spent IS NULL
UNION ALL
SELECT 'payment_method', COUNT(*) FROM staging.cafe_tipada WHERE payment_method IS NULL
UNION ALL
SELECT 'location', COUNT(*) FROM staging.cafe_tipada WHERE location IS NULL
UNION ALL
SELECT 'transaction_date', COUNT(*) FROM staging.cafe_tipada WHERE transaction_date IS NULL;

-----------------------------------------------------
-- Fase  5 — Staging: recuperação e limpeza
-- Enunciado 7: 
-- Crie a tabela staging.cardapio com as colunas item (VARCHAR(20), chave primária), price
-- (NUMERIC(6,2) NOT NULL) e category (VARCHAR(10) NOT NULL) e insira nela as oito linhas
-- da Tabela 3.
-----------------------------------------------------

-- 1. Criação da tabela de referência do cardápio
DROP TABLE IF EXISTS staging.cardapio CASCADE;

CREATE TABLE staging.cardapio (
    item VARCHAR(20) PRIMARY KEY,
    price NUMERIC(6,2) NOT NULL,
    category VARCHAR(10) NOT NULL
);

-- 2. Inserção dos 8 itens oficiais do cardápio
INSERT INTO staging.cardapio (item, price, category) VALUES
('Cookie', 1.00, 'Comida'),
('Juice', 3.00, 'Bebida'),
('Tea', 1.50, 'Bebida'),
('Sandwich', 4.00, 'Comida'),
('Coffee', 2.00, 'Bebida'),
('Smoothie', 4.00, 'Bebida'),
('Cake', 3.00, 'Comida'),
('Salad', 5.00, 'Comida');

-- 3. Validação do conteúdo inserido (esperadas 8 linhas)
SELECT * FROM staging.cardapio;

-----------------------------------------------------
-- Enunciado 8: 
-- Aplique à tabela staging.cafe_tipada as regras da Tabela 7, na ordem indicada, com
-- um UPDATE por regra (a R6 pode usar dois). Use subconsultas sobre staging.cardapio
-- nas regras R1 e R5. Abaixo de cada UPDATE, registre em comentário a quantidade de linhas
-- afetadas informada pelo pgAdmin
-----------------------------------------------------

-- R1: Preço nulo e item conhecido -> Preço ganha o valor do item no cardápio
UPDATE staging.cafe_tipada
SET price_per_unit = (
    SELECT c.price 
    FROM staging.cardapio c 
    WHERE c.item = staging.cafe_tipada.item
)
WHERE price_per_unit IS NULL 
  AND item IS NOT NULL;

-- pgAdmin: 479 linhas afetadas


-- R2: Preço nulo, quantidade e total conhecidos -> Preço = total_spent / quantity
UPDATE staging.cafe_tipada
SET price_per_unit = total_spent / quantity
WHERE price_per_unit IS NULL 
  AND quantity IS NOT NULL 
  AND total_spent IS NOT NULL;

-- pgAdmin: 48 linhas afetadas


-- R3: Quantidade nula, preço e total conhecidos -> Quantidade = ROUND(total_spent / price_per_unit)
UPDATE staging.cafe_tipada
SET quantity = ROUND(total_spent / price_per_unit)
WHERE quantity IS NULL 
  AND price_per_unit IS NOT NULL 
  AND total_spent IS NOT NULL;

-- pgAdmin: 456 linhas afetadas


-- R4: Total nulo, quantidade e preço conhecidos -> Total = quantity * price_per_unit
UPDATE staging.cafe_tipada
SET total_spent = quantity * price_per_unit
WHERE total_spent IS NULL 
  AND quantity IS NOT NULL 
  AND price_per_unit IS NOT NULL;

-- pgAdmin: 479 linhas afetadas


-- R5: Item nulo e preço conhecido, pertencente a um único item do cardápio -> Item do cardápio
-- (Ignora os preços ambíguos de 3.00 e 4.00, pois correspondem a mais de um produto)
UPDATE staging.cafe_tipada
SET item = (
    SELECT c.item 
    FROM staging.cardapio c 
    WHERE c.price = staging.cafe_tipada.price_per_unit
)
WHERE item IS NULL 
  AND price_per_unit IS NOT NULL
  AND price_per_unit IN (
      SELECT price 
      FROM staging.cardapio 
      GROUP BY price 
      HAVING COUNT(*) = 1
  );

-- pgAdmin: 489 linhas afetadas


-- R6a: Forma de pagamento nula -> 'Unknown'
UPDATE staging.cafe_tipada
SET payment_method = 'Unknown'
WHERE payment_method IS NULL;

-- pgAdmin: 3178 linhas afetadas


-- R6b: Localização nula -> 'Unknown'
UPDATE staging.cafe_tipada
SET location = 'Unknown'
WHERE location IS NULL;

-- pgAdmin: 3961 linhas afetadas

-----------------------------------------------------
-- Enunciado 9: 
-- Crie staging.cafe_sales com as mesmas colunas e tipos da Tabela 6, agora com NOT NULL
-- em todas elas e com as restrições CHECK (quantity > 0) e CHECK (price_per_unit > 0).
-- Carregue-a, precedida de TRUNCATE, apenas com as linhas de staging.cafe_tipada que
-- não têm nenhum valor nulo. Escreva então uma consulta que devolva, em uma única linha,
-- três colunas: linhas_tipada, linhas_limpas e descartadas. Registre os três números em
-- comentário.
-----------------------------------------------------

-- 1. Criação da tabela staging.cafe_sales (mesmos tipos da Tabela 6, com NOT NULL e CHECKs)
DROP TABLE IF EXISTS staging.cafe_sales CASCADE;

CREATE TABLE staging.cafe_sales (
    transaction_id VARCHAR(20) PRIMARY KEY,
    item VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_per_unit NUMERIC(6,2) NOT NULL CHECK (price_per_unit > 0),
    total_spent NUMERIC(8,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    location VARCHAR(20) NOT NULL,
    transaction_date DATE NOT NULL
);

-- 2. Carga da tabela precedida de TRUNCATE, selecionando apenas linhas sem NULL
TRUNCATE TABLE staging.cafe_sales;

INSERT INTO staging.cafe_sales (
    transaction_id,
    item,
    quantity,
    price_per_unit,
    total_spent,
    payment_method,
    location,
    transaction_date
)
SELECT 
    transaction_id,
    item,
    quantity,
    price_per_unit,
    total_spent,
    payment_method,
    location,
    transaction_date
FROM staging.cafe_tipada
WHERE item IS NOT NULL
  AND quantity IS NOT NULL
  AND price_per_unit IS NOT NULL
  AND total_spent IS NOT NULL
  AND payment_method IS NOT NULL
  AND location IS NOT NULL
  AND transaction_date IS NOT NULL;

-- 3. Consulta em linha única que calcula linhas_tipada, linhas_limpas e descartadas
SELECT 
    (SELECT COUNT(*) FROM staging.cafe_tipada) AS linhas_tipada,
    (SELECT COUNT(*) FROM staging.cafe_sales) AS linhas_limpas,
    (SELECT COUNT(*) FROM staging.cafe_tipada) - (SELECT COUNT(*) FROM staging.cafe_sales) AS descartadas;

-- Resultado retornado:
-- linhas_tipada: 10000
-- linhas_limpas: 9064
-- descartadas: 936

-----------------------------------------------------
-- Fase  6 — Modelo dimensional
-- Enunciado 10: 
-- Consulte a menor e a maior data de venda registradas em staging.cafe_sales. Em seguida,
-- crie dw.dim_date com as colunas da Figura 4 (date_sk inteiro no formato YYYYMMDD) e
-- carregue-a com generate_series, gerando todos os dias dos anos completos que cobrem
-- esse intervalo. Confira a quantidade de linhas geradas.
-----------------------------------------------------

-- 1. Consulta da menor e maior data registradas na camada staging
SELECT 
    MIN(transaction_date) AS menor_data, 
    MAX(transaction_date) AS maior_data 
FROM staging.cafe_sales;

-- Resultado esperado em dirty_cafe_sales.csv: 
-- menor_data: 2023-01-01 | maior_data: 2023-12-31 (cobre o ano completo de 2023)


-- 2. DDL — Criação da dimensão dw.dim_date (Figura 4)
DROP TABLE IF EXISTS dw.dim_date CASCADE;

CREATE TABLE dw.dim_date (
    date_sk INTEGER PRIMARY KEY, -- Formato YYYYMMDD (ex: 20230101)
    full_date DATE NOT NULL UNIQUE,
    day SMALLINT NOT NULL,
    month SMALLINT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    quarter SMALLINT NOT NULL,
    year SMALLINT NOT NULL,
    day_of_week VARCHAR(15) NOT NULL,
    is_weekend BOOLEAN NOT NULL
);


-- 3. Carga via generate_series cobrindo o ano completo de 2023 (01/01/2023 a 31/12/2023)
INSERT INTO dw.dim_date (
    date_sk,
    full_date,
    day,
    month,
    month_name,
    quarter,
    year,
    day_of_week,
    is_weekend
)
SELECT 
    CAST(TO_CHAR(d, 'YYYYMMDD') AS INTEGER) AS date_sk,
    d::DATE AS full_date,
    EXTRACT(DAY FROM d)::SMALLINT AS day,
    EXTRACT(MONTH FROM d)::SMALLINT AS month,
    TO_CHAR(d, 'TMMonth') AS month_name,
    EXTRACT(QUARTER FROM d)::SMALLINT AS quarter,
    EXTRACT(YEAR FROM d)::SMALLINT AS year,
    TO_CHAR(d, 'TMDay') AS day_of_week,
    EXTRACT(DOW FROM d) IN (0, 6) AS is_weekend
FROM generate_series(
    DATE '2023-01-01', 
    DATE '2023-12-31', 
    INTERVAL '1 day'
) g(d);


-- 4. Consulta de conferência da quantidade de linhas geradas
SELECT COUNT(*) AS total_dias FROM dw.dim_date;

-- Resultado esperado: 365 linhas (referentes a todos os dias do ano de 2023)

-----------------------------------------------------
-- Enunciado 11: 
-- Crie e carregue dw.dim_item, dw.dim_payment e dw.dim_location, com chaves SERIAL e
-- atributos descritivos UNIQUE. A carga usa DISTINCT sobre staging.cafe_sales; a category
-- de dim_item vem de staging.cardapio. Confira as três dimensões em uma única consulta
-- com UNION ALL: esperam-se 8 itens, 4 formas de pagamento e 3 locais, já incluído o valor
-- 'Unknown'.
-----------------------------------------------------

-- 1. Dimensão dw.dim_item
DROP TABLE IF EXISTS dw.dim_item CASCADE;

CREATE TABLE dw.dim_item (
    item_sk SERIAL PRIMARY KEY,
    item VARCHAR(20) NOT NULL UNIQUE,
    category VARCHAR(10) NOT NULL
);

INSERT INTO dw.dim_item (item, category)
SELECT DISTINCT 
    s.item,
    c.category
FROM staging.cafe_sales s
JOIN staging.cardapio c ON s.item = c.item
ORDER BY s.item;


-- 2. Dimensão dw.dim_payment
DROP TABLE IF EXISTS dw.dim_payment CASCADE;

CREATE TABLE dw.dim_payment (
    payment_sk SERIAL PRIMARY KEY,
    payment_method VARCHAR(20) NOT NULL UNIQUE
);

INSERT INTO dw.dim_payment (payment_method)
SELECT DISTINCT 
    payment_method
FROM staging.cafe_sales
ORDER BY payment_method;


-- 3. Dimensão dw.dim_location
DROP TABLE IF EXISTS dw.dim_location CASCADE;

CREATE TABLE dw.dim_location (
    location_sk SERIAL PRIMARY KEY,
    location VARCHAR(20) NOT NULL UNIQUE
);

INSERT INTO dw.dim_location (location)
SELECT DISTINCT 
    location
FROM staging.cafe_sales
ORDER BY location;


-- 4. Consulta de validação consolidada com UNION ALL
SELECT 'dw.dim_item' AS dimensao, COUNT(*) AS total_registros FROM dw.dim_item
UNION ALL
SELECT 'dw.dim_payment', COUNT(*) FROM dw.dim_payment
UNION ALL
SELECT 'dw.dim_location', COUNT(*) FROM dw.dim_location;

-- Resultado esperado da validação:
-- dw.dim_item:     8 registros
-- dw.dim_payment:  4 registros (Cash, Credit Card, Digital Wallet, Unknown)
-- dw.dim_location: 3 registros (In-store, Takeaway, Unknown)

-----------------------------------------------------
-- Enunciado 12: 
-- Crie dw.fact_sales conforme a Figura 4: transaction_nk como chave primária (dimensão
-- degenerada), chaves estrangeiras NOT NULL para as quatro dimensões, métricas NOT NULL e
-- um índice por chave estrangeira. Carregue-a a partir de staging.cafe_sales, precedida de
-- TRUNCATE: date_sk por formatação da data, sem JOIN; as outras três surrogate keys por JOIN
-- com as dimensões. Por fim, escreva uma consulta que compare, lado a lado, a quantidade de
-- linhas e a soma de total_spent da staging e da fato. Os dois pares devem ser iguais.
-----------------------------------------------------

-- 1. DDL — Criação da Tabela Fato dw.fact_sales
DROP TABLE IF EXISTS dw.fact_sales CASCADE;

CREATE TABLE dw.fact_sales (
    transaction_nk VARCHAR(20) PRIMARY KEY, -- Dimensão degenerada
    date_sk INTEGER NOT NULL REFERENCES dw.dim_date(date_sk),
    item_sk INTEGER NOT NULL REFERENCES dw.dim_item(item_sk),
    payment_sk INTEGER NOT NULL REFERENCES dw.dim_payment(payment_sk),
    location_sk INTEGER NOT NULL REFERENCES dw.dim_location(location_sk),
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(6,2) NOT NULL,
    total_spent NUMERIC(8,2) NOT NULL
);

-- Criação dos índices nas Chaves Estrangeiras (FKs) para otimização de JOINs
CREATE INDEX idx_fact_sales_date ON dw.fact_sales(date_sk);
CREATE INDEX idx_fact_sales_item ON dw.fact_sales(item_sk);
CREATE INDEX idx_fact_sales_payment ON dw.fact_sales(payment_sk);
CREATE INDEX idx_fact_sales_location ON dw.fact_sales(location_sk);


-- 2. Carga precedida de TRUNCATE
TRUNCATE TABLE dw.fact_sales;

INSERT INTO dw.fact_sales (
    transaction_nk,
    date_sk,
    item_sk,
    payment_sk,
    location_sk,
    quantity,
    price_per_unit,
    total_spent
)
SELECT 
    s.transaction_id AS transaction_nk,
    CAST(TO_CHAR(s.transaction_date, 'YYYYMMDD') AS INTEGER) AS date_sk, -- Sem JOIN (formatação direta)
    di.item_sk,
    dp.payment_sk,
    dl.location_sk,
    s.quantity,
    s.price_per_unit,
    s.total_spent
FROM staging.cafe_sales s
JOIN dw.dim_item di ON di.item = s.item
JOIN dw.dim_payment dp ON dp.payment_method = s.payment_method
JOIN dw.dim_location dl ON dl.location = s.location;


-- 3. Consulta de Validação Comparativa (Lado a Lado)
SELECT 
    (SELECT COUNT(*) FROM staging.cafe_sales) AS linhas_staging,
    (SELECT COUNT(*) FROM dw.fact_sales) AS linhas_fato,
    (SELECT SUM(total_spent) FROM staging.cafe_sales) AS total_spent_staging,
    (SELECT SUM(total_spent) FROM dw.fact_sales) AS total_spent_fato;

-- Resultado Esperado:
-- linhas_staging: 9064 | linhas_fato: 9064
-- total_spent_staging e total_spent_fato devem ser rigorosamente idênticos.

-----------------------------------------------------
-- Fase 7 — Cursor não vinculado com consulta dinâmica
-- Enunciado 13: 
-- Escreva um bloco anônimo PL/pgSQL (DO), sem criar função nem procedimento, que produza
-- um ranking de receita para cada uma das três dimensões pequenas do DW: item, payment e
-- location, nessa ordem, em uma única execução. Requisitos obrigatórios:
-- a) deve existir um único cursor, não vinculado: declarado como REFCURSOR, sem consulta
-- no DECLARE;
-- b) o bloco percorre os nomes das três dimensões com um laço, à escolha do grupo, e, a cada
-- volta, guarda o nome da dimensão da vez em uma variável;
-- c) a cada volta, a consulta é dinâmica: um texto montado por concatenação com essa
-- variável, que junta dw.fact_sales à tabela dw.dim_dimensão e devolve, para cada valor
-- do atributo de mesmo nome, a quantidade de vendas e a receita (soma de total_spent),
-- da maior para a menor receita;
-- d) a cada volta, o cursor é aberto com OPEN ... FOR EXECUTE, percorrido com FETCH em um
-- LOOP, com saída por EXIT WHEN NOT FOUND, e fechado com CLOSE antes de ser reaberto
-- com a consulta da dimensão seguinte;
-- e) antes de percorrer as dimensões, o bloco calcula a receita total da fato; a cada
-- linha lida, emite um RAISE NOTICE no formato <dimensão> | <posição> - <valor>:
-- <vendas> vendas, receita <receita> (<percentual>% do total), com o percentual
-- arredondado para duas casas;
-- f) ao terminar cada dimensão, emite um RAISE NOTICE com a quantidade de linhas lidas
-- naquela dimensão; ao terminar as três, emite um último com o total de linhas lidas.
-- Para cada dimensão, a soma dos percentuais exibidos deve ser 100%, com diferença apenas
-- de arredondamento.
-- No mercado: SQL dinâmico com responsa
-----------------------------------------------------

DO $$
DECLARE
    -- a) Único cursor não vinculado (REFCURSOR sem consulta vinculada no DECLARE)
    c_dw REFCURSOR;
    
    -- Vetor contendo a ordem exata das três dimensões pequenas
    v_dims TEXT[] := ARRAY['item', 'payment', 'location'];
    v_dim TEXT;
    v_col TEXT;
    v_sql TEXT;
    
    -- Variáveis de destino para o FETCH
    v_valor VARCHAR(100);
    v_vendas BIGINT;
    v_receita NUMERIC(12,2);
    
    -- Variáveis de controle, totais e percentuais
    v_receita_total NUMERIC(12,2);
    v_percentual NUMERIC(6,2);
    v_posicao INTEGER;
    v_linhas_dim INTEGER;
    v_total_linhas_lidas INTEGER := 0;
BEGIN
    -- e) Calcula a receita total da fato antes de iniciar a varredura das dimensões
    SELECT SUM(total_spent) INTO v_receita_total FROM dw.fact_sales;
    
    -- b) Percorre os nomes das três dimensões com um laço FOREACH
    FOREACH v_dim IN ARRAY v_dims LOOP
        v_posicao := 0;
        v_linhas_dim := 0;
        
        -- Mapeia a coluna descritiva do atributo (payment_method para 'payment', item/location para os demais)
        IF v_dim = 'payment' THEN
            v_col := 'payment_method';
        ELSE
            v_col := v_dim;
        END IF;
        
        -- c) Montagem dinâmica da consulta SQL por concatenação de strings
        v_sql := 'SELECT d.' || v_col || '::VARCHAR, COUNT(*)::BIGINT, SUM(f.total_spent)::NUMERIC(12,2) ' ||
                 'FROM dw.fact_sales f ' ||
                 'JOIN dw.dim_' || v_dim || ' d ON d.' || v_dim || '_sk = f.' || v_dim || '_sk ' ||
                 'GROUP BY d.' || v_col || ' ' ||
                 'ORDER BY SUM(f.total_spent) DESC';
                 
        -- d) Abertura do cursor com a consulta dinâmica
        OPEN c_dw FOR EXECUTE v_sql;
        
        LOOP
            -- d) Leitura registro a registro com FETCH e condição de parada
            FETCH c_dw INTO v_valor, v_vendas, v_receita;
            EXIT WHEN NOT FOUND;
            
            v_posicao := v_posicao + 1;
            v_linhas_dim := v_linhas_dim + 1;
            
            -- e) Cálculo da participação percentual individual sobre a receita total
            v_percentual := ROUND((v_receita / v_receita_total) * 100, 2);
            
            -- e) Exibição formatada das métricas no painel de mensagens do pgAdmin
            RAISE NOTICE '% | % - %: % vendas, receita % (%%% do total)', 
                v_dim, v_posicao, v_valor, v_vendas, v_receita, v_percentual;
        END LOOP;
        
        -- d) Fechamento do cursor antes de avançar para a dimensão seguinte
        CLOSE c_dw;
        
        v_total_linhas_lidas := v_total_linhas_lidas + v_linhas_dim;
        
        -- f) Emissão do total de linhas lidas na dimensão atual
        RAISE NOTICE 'Linhas lidas na dimensão %: %', v_dim, v_linhas_dim;
    END LOOP;
    
    -- f) Emissão do total geral acumulado das três dimensões
    RAISE NOTICE 'Total geral de linhas lidas nas três dimensões: %', v_total_linhas_lidas;
END $$;


