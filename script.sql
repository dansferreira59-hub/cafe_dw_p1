-- 4 Fase 1 — Preparação do banco
-- Enunciado 1: Criação do banco cafe_dw com codificação UTF8 direto no bd
-- Criando os 3 schemas da arquitetura em camadas

create schema if not exists raw;
create schema if not exists staging;
create schema if not exists dw;

-- Verificando
select SCHEMA_NAME
from information_schema.schemata
where schema_name in('raw', 'staging', 'dw' );