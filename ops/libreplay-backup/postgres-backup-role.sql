\set ON_ERROR_STOP on

-- Run while connected to the LibrePlay application database as a database
-- owner/admin. Pass the role password as a psql variable, never inline:
--   psql -v pg_backup_password='...' -f postgres-backup-role.sql
\if :{?pg_backup_password}
\else
\echo 'required psql variable missing: pg_backup_password'
\quit 1
\endif

SELECT
  'CREATE ROLE libreplay_backup LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION PASSWORD '
  || quote_literal(:'pg_backup_password')
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_roles
  WHERE rolname = 'libreplay_backup'
)
\gexec

ALTER ROLE libreplay_backup
  WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION
  PASSWORD :'pg_backup_password';

GRANT CONNECT ON DATABASE libreplay_lan TO libreplay_backup;
GRANT USAGE ON SCHEMA public TO libreplay_backup;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO libreplay_backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO libreplay_backup;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO libreplay_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON SEQUENCES TO libreplay_backup;
