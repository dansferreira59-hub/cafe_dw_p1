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


