\set ON_ERROR_STOP on

-- PROD-MEDIA-PURGE-ORPHAN-02: scoped, read-only Postgres role for the media
-- orphan *inventory* job. The inventory only SELECTs referenced media object /
-- variant keys to reconcile them against the MinIO listing; it never writes.
--
-- Run while connected to the LibrePlay application database (libreplay_lan) as a
-- database owner/admin. Provide the password via PG_ORPHAN_PASSWORD without
-- putting the value in argv or shell history. Example interactive flow:
--   read -rsp 'PG_ORPHAN_PASSWORD: ' PG_ORPHAN_PASSWORD
--   export PG_ORPHAN_PASSWORD
--   psql -f ops/libreplay-media-orphan/postgres-orphan-role.sql
--   unset PG_ORPHAN_PASSWORD
-- An approved secret-manager wrapper may set PG_ORPHAN_PASSWORD for the psql
-- process, but it must not place the secret value in the command line.
--
-- After the role exists, the operator constructs the read-only DSN
--   postgresql://libreplay_media_orphan:<password>@<host>:5432/libreplay_lan
-- OUTSIDE this file and writes it to Vault as `PG_ORPHAN_DSN` only. Do NOT paste
-- the DSN or password into any committed file, command history or arguments.
\if :{?pg_orphan_password}
\else
\getenv pg_orphan_password PG_ORPHAN_PASSWORD
\if :{?pg_orphan_password}
\else
\echo 'required environment variable missing: PG_ORPHAN_PASSWORD'
\quit 1
\endif
\endif

SELECT
  'CREATE ROLE libreplay_media_orphan LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION PASSWORD '
  || quote_literal(:'pg_orphan_password')
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_roles
  WHERE rolname = 'libreplay_media_orphan'
)
\gexec

ALTER ROLE libreplay_media_orphan
  WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION
  PASSWORD :'pg_orphan_password';

GRANT CONNECT ON DATABASE libreplay_lan TO libreplay_media_orphan;
GRANT USAGE ON SCHEMA public TO libreplay_media_orphan;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO libreplay_media_orphan;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO libreplay_media_orphan;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO libreplay_media_orphan;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON SEQUENCES TO libreplay_media_orphan;
