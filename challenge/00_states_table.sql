-- 00 — Expand the schema with the full names of the Brazilian states.
--
-- Provided by the challenge. `geo.state` already holds the two-letter code, so
-- the new table is a plain lookup dimension; the ALTERs narrow the column to
-- CHAR(2) and point a foreign key at it.
--
-- Before running the ALTERs, confirm the data is actually clean enough for the
-- constraint. It is: all 27 codes present in `geo` exist in `states`, and the
-- only rows that would violate the FK are the handful whose state is NULL —
-- and NULL is exempt from foreign key checks.
--
--   SELECT DISTINCT state FROM geo
--   WHERE state IS NOT NULL AND state NOT IN (SELECT short FROM states);
--   -- 0 rows
USE magist;

DROP TABLE IF EXISTS `states`;
CREATE TABLE `states` (
  `state` varchar(40) DEFAULT NULL,
  `short` char(2) NOT NULL,
  PRIMARY KEY (`short`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `states` VALUES ('Acre','AC'),('Alagoas','AL'),('Amazonas','AM'),('Amapá','AP'),('Bahía','BA'),('Ceará','CE'),('Distrito Federal','DF'),('Espirito Santo','ES'),('Goiás','GO'),('Maranhão','MA'),('Minas Geraís','MG'),('Mato Grosso do Sul','MS'),('Mato Grosso','MT'),('Pará','PA'),('Paraíba','PB'),('Pernambuco','PE'),('Piauí','PI'),('Paraná','PR'),('Rio de Janeiro','RJ'),('Rio Grande do Norte','RN'),('Rondônia','RO'),('Roraima','RR'),('Rio Grande do Sul','RS'),('Santa Catarina','SC'),('Sergipe','SE'),('São Paulo','SP'),('Tocantins','TO');

ALTER TABLE geo
MODIFY state CHAR(2);
ALTER TABLE geo
ADD FOREIGN KEY (state) REFERENCES states(short);

-- Where this sits in the schema: customers carry a zip prefix, `geo` turns the
-- prefix into a state code, `states` turns the code into a name. So every
-- review reaches a state name through four joins and no shortcuts:
--
--   order_reviews -> orders -> customers -> geo -> states
--
-- `geo.zip_code_prefix` is unique in this dataset (19,177 rows, 19,177
-- distinct), so that chain does not fan out. Worth checking rather than
-- assuming: in the raw Olist geolocation export the prefix is NOT unique, and
-- the same join there would multiply every review by its number of geocodes.
