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
