-- Conéctate al servidor correspondiente de cada maestro o esclavo
psql -U postgres -p 5433
psql -U postgres -p 5434
psql -U postgres -p 5435
psql -U postgres -p 5436

SELECT version();

-- Crear las bases de datos
CREATE DATABASE telpark1;
CREATE DATABASE telpark2;

--------------CUESTION 1--------------

-- 1. Instalar la extensión postgres_fdw
-- Ejecutar CREATE EXTENSION IF NOT EXISTS postgres_fdw; en cada base de datos (TELPARK1 y TELPARK2).

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
\dx 

-- 2. Crear un "server" objeto que apunte a la otra base de datos
-- En TELPARK1, crear un server que apunte a TELPARK2
-- En TELPARK2, crear un server que apunte a TELPARK1

DROP SERVER IF EXISTS maestro1 CASCADE;
CREATE SERVER maestro1
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5434', dbname 'telpark2');
\des 

DROP SERVER IF EXISTS maestro2 CASCADE; 
CREATE SERVER maestro2
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5433', dbname 'telpark1');
\des  

-- 3. Crear un "user mapping" para la conexion.

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER maestro1 CASCADE;
CREATE USER MAPPING FOR CURRENT_USER
    SERVER maestro1
    OPTIONS (user 'postgres', password 'postgres');
\deu+  

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER maestro2 CASCADE; 
CREATE USER MAPPING FOR CURRENT_USER
    SERVER maestro2
    OPTIONS (user 'postgres', password 'postgres');
\deu+ 

-- 4. Crear tablas de ejemplo en telpark1 y telpark2
-- IMPORTANTE: Esto es crucial, las tablas deben existir antes de crear las foreign tables

-- En la base de datos telpark1, crear las tablas clientes y reservas

DROP TABLE IF EXISTS clientes CASCADE; 
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre TEXT,
    provincia TEXT
);

DROP TABLE IF EXISTS reservas CASCADE; 
CREATE TABLE reservas (
    id_reserva SERIAL PRIMARY KEY,
    id_cliente INT REFERENCES clientes(id_cliente),
    fecha TEXT
);

-- Insertar datos en telpark1

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(1, 'Laura López', 'Madrid'),
(2, 'Carlos Ruiz', 'Barcelona');

INSERT INTO reservas (id_cliente, fecha) VALUES
(1, '2025-05-10'),
(1, '2025-05-12'),
(2, '2025-05-11');

\d clientes
\d reservas

-- En la base de datos telpark2, crear las tablas clientes y reservas

DROP TABLE IF EXISTS clientes CASCADE;
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre TEXT,
    provincia TEXT
);

DROP TABLE IF EXISTS reservas CASCADE;
CREATE TABLE reservas (
    id_reserva SERIAL PRIMARY KEY,
    id_cliente INT REFERENCES clientes(id_cliente),
    fecha TEXT
);

-- Insertar datos en telpark2
INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(3, 'Ana Torres', 'Valencia'),
(4, 'Javier Gómez', 'Madrid');

INSERT INTO reservas (id_cliente, fecha) VALUES
(3, '2025-05-14'),
(4, '2025-05-15'),
(4, '2025-05-16');

\d clientes
\d reservas

-- 5. Crear "foreign tables" para acceder a las tablas remotas
-- En TELPARK1, para acceder a una tabla llamada tabla_ejemplo en TELPARK2
-- Lo mismo en TELPARK2 para acceder a las tablas de TELPARK1

DROP FOREIGN TABLE IF EXISTS clientes_telpark2 CASCADE;
CREATE FOREIGN TABLE clientes_telpark2 (
    id_cliente INT,
    nombre TEXT,
    provincia TEXT
)
SERVER maestro1
OPTIONS (schema_name 'public', table_name 'clientes');
\d clientes_telpark2
\d+ clientes_telpark2 

DROP FOREIGN TABLE IF EXISTS reservas_telpark2 CASCADE;
CREATE FOREIGN TABLE reservas_telpark2 (
    id_reserva INT,
    id_cliente INT,
    fecha TEXT
)
SERVER maestro1
OPTIONS (schema_name 'public', table_name 'reservas');
\d reservas_telpark2
\d+ reservas_telpark2


DROP FOREIGN TABLE IF EXISTS clientes_telpark1 CASCADE;
CREATE FOREIGN TABLE clientes_telpark1 (
    id_cliente INT,
    nombre TEXT,
    provincia TEXT
)
SERVER maestro2
OPTIONS (schema_name 'public', table_name 'clientes');
\d clientes_telpark1
\d+ clientes_telpark1

DROP FOREIGN TABLE IF EXISTS reservas_telpark1 CASCADE;
CREATE FOREIGN TABLE reservas_telpark1 (
    id_reserva INT,
    id_cliente INT,
    fecha TEXT
)
SERVER maestro2
OPTIONS (schema_name 'public', table_name 'reservas');
\d reservas_telpark1
\d+ reservas_telpark1

-- 6. Consultar las tablas remotas
-- Ahora se pueden realizar consultas como si las tablas remotas fueran locales

-- Ver todos los clientes de TELPARK2 desde TELPARK1
SELECT * FROM clientes_telpark2;

-- Ver todas las reservas de TELPARK2 desde TELPARK1
SELECT * FROM reservas_telpark2;

-- Ver todos los clientes de TELPARK1 desde TELPARK2
SELECT * FROM clientes_telpark1;

-- Ver todas las reservas de TELPARK1 desde TELPARK2
SELECT * FROM reservas_telpark1;

--------------CUESTION 2--------------

--MAESTRO1:

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
  (5, 'Ana García', 'Madrid'),
  (6, 'Luis Pérez', 'Barcelona'),
  (7, 'Sofía Martínez', 'Valencia');
 

 INSERT INTO reservas (id_reserva, id_cliente, fecha) VALUES
  (101, 7, '2024-05-01'),
  (102, 6, '2024-05-05'),
  (103, 5, '2024-05-10');

--MAESTRO2:

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
  (8, 'Javier López', 'Sevilla'),
  (9, 'Carmen Díaz', 'Málaga'),
  (10, 'Pedro Ramírez', 'Madrid');
 

INSERT INTO reservas (id_reserva, id_cliente, fecha) VALUES
  (201, 8, '2024-05-03'),
  (202, 10, '2024-05-08'),
  (203, 9, '2024-05-12'),
  (204, 8, '2024-05-15');

--CONSULTA:

EXPLAIN ANALYZE
SELECT
  provincia,
  SUM(total_reservas) AS total_reservas
FROM (
  SELECT
    c.provincia,
    COUNT(r.id_reserva) AS total_reservas
  FROM
    clientes c
    JOIN reservas r ON c.id_cliente = r.id_cliente
  GROUP BY
    c.provincia
  UNION ALL
  SELECT
    c.provincia,
    COUNT(r.id_reserva) AS total_reservas
  FROM
    clientes_telpark2 c
    JOIN reservas_telpark2 r ON c.id_cliente = r.id_cliente
  GROUP BY
    c.provincia
) AS subconsulta
GROUP BY
  provincia
ORDER BY
  provincia;

--------------CUESTION 3--------------

CREATE USER usuario_replica REPLICATION LOGIN ENCRYPTED PASSWORD 'postgres';

GRANT USAGE ON SCHEMA public TO usuario_replica;
grant select on all tables in schema public to usuario_replica;

CREATE DATABASE replica_master;

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(11, 'Sara Martinez', 'Sevilla'),
(12, 'Juan Cuesta', 'Barcelona');

\l

CREATE USER usuario_replica REPLICATION LOGIN ENCRYPTED PASSWORD 'postgres'; 

GRANT USAGE ON SCHEMA public TO usuario_replica;
grant select on all tables in schema public to usuario_replica;

CREATE DATABASE replica_master2;

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(13, 'Luis Fuentes', 'Sevilla'),
(14, 'Pedro Alonso', 'Barcelona');

\x

select * from pg_stat_replication;

select * from pg_stat_wal_receiver;

--------------CUESTION 4--------------

UPDATE reservas SET fecha = '2025-05-17' WHERE id_reserva = 101;

UPDATE clientes SET nombre = 'Laura Sanjuan' WHERE id_cliente = 4;

CREATE DATABASE replica_caida;

CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre TEXT,
    provincia TEXT
);

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(20, 'Pablo Herraez', 'Madrid'),
(21, 'Laura Santos', 'Madrid');

--------------CUESTION 5--------------

CREATE ROLE replicator LOGIN REPLICATION PASSWORD 'postgres';

\du

DROP DATABASE IF EXISTS replica_telpark2 CASCADE;
CREATE DATABASE replica_telpark2;

\c replica_telpark2;

DROP TABLE IF EXISTS clientes CASCADE; 
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre TEXT,
    provincia TEXT
);
ALTER TABLE clientes OWNER TO postgres;

DROP TABLE IF EXISTS reservas CASCADE; 
CREATE TABLE reservas (
    id_reserva SERIAL PRIMARY KEY,
    id_cliente INT REFERENCES clientes(id_cliente),
    fecha TEXT
);
ALTER TABLE reservas OWNER TO postgres;

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(1, 'Laura López', 'Madrid'),
(2, 'Carlos Ruiz', 'Barcelona'),
(3, 'Ana Torres', 'Valencia'),
(4, 'Javier Gómez', 'Madrid'),
(5, 'Ana García', 'Madrid'),
(6, 'Luis Pérez', 'Barcelona'),
(7, 'Sofía Martínez', 'Valencia'),
(8, 'Javier López', 'Sevilla'),
(9, 'Carmen Díaz', 'Málaga'),
(10, 'Pedro Ramírez', 'Madrid');

INSERT INTO reservas (id_cliente, fecha) VALUES
(1, '2025-05-10'),
(1, '2025-05-12'),
(2, '2025-05-11'),
(3, '2025-05-14'),
(4, '2025-05-15'),
(4, '2025-05-16'),


CREATE PUBLICATION pub_clientes FOR TABLE clientes;
CREATE PUBLICATION pub_reservas FOR TABLE reservas;

GRANT SELECT ON TABLE clientes TO replicator;
GRANT SELECT ON TABLE reservas TO replicator;

CREATE SUBSCRIPTION sub_telpark2_clientes
    CONNECTION 'host=127.0.0.1 port=5434 dbname=telpark2 user=replicator password=postgres'
    PUBLICATION pub_clientes
    WITH (copy_data = true);


CREATE SUBSCRIPTION sub_telpark2_reservas
    CONNECTION 'host=127.0.0.1 port=5434 dbname=telpark2 user=replicator password=postgres'
    PUBLICATION pub_reservas
    WITH (copy_data = true);

DROP SUBSCRIPTION sub_telpark2_clientes;
DROP SUBSCRIPTION sub_telpark2_reservas;

-----------------------------------------------------------------------------------------------------------------------------------------------------

DROP DATABASE IF EXISTS replica_telpark1 CASCADE;
CREATE DATABASE replica_telpark1;

\c replica_telpark1;

DROP TABLE IF EXISTS clientes CASCADE; 
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre TEXT,
    provincia TEXT
);
ALTER TABLE clientes OWNER TO postgres;

DROP TABLE IF EXISTS reservas CASCADE; 
CREATE TABLE reservas (
    id_reserva SERIAL PRIMARY KEY,
    id_cliente INT REFERENCES clientes(id_cliente),
    fecha TEXT
);
ALTER TABLE reservas OWNER TO postgres;

CREATE PUBLICATION pub_telpark1 FOR ALL TABLES;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;

CREATE SUBSCRIPTION sub_telpark1
 CONNECTION 'host=127.0.0.1 port=5433 dbname=telpark1 user=replicator password=postgres'
 PUBLICATION pub_telpark1
 WITH (copy_data = true);

INSERT INTO clientes (id_cliente, nombre, provincia) VALUES
(13, 'Sara Fructuoso', 'Madrid'),
(14, 'Gonzalo Cidre', 'Torrelodones');

