prompt ================================================================================
prompt ODB-EnvSync - Main Installer (Core only)
prompt ================================================================================
set define on
set echo on
set termout on
set serveroutput on size unlimited
whenever sqlerror exit failure

prompt Installing core database objects...

-- 1) Strategy/config objects
@sql/ddl/install_script_strategy/oei_install_script_strategy.sql
@sql/ddl/install_script_strategy/oei_install_script_type_mode.sql

-- 2) Env Sync core tables
@sql/ddl/env_sync_capture/oei_env_sync_schema_objects.sql
@sql/ddl/env_sync_capture/oei_env_sync_snapshots.sql
@sql/ddl/env_sync_capture/oei_env_sync_releases.sql
@sql/ddl/env_sync_capture/oei_env_sync_install_log.sql
@sql/ddl/env_sync_capture/oei_env_sync_audit.sql
@sql/ddl/env_sync_capture/oei_env_sync_seed_tables.sql
@sql/ddl/env_sync_capture/oei_env_sync_object_exclude.sql

prompt Installing PL/SQL package (spec + body)...
@sql/modules/env_sync_capture/pck_oei_env_sync.pks
@sql/modules/env_sync_capture/pck_oei_env_sync.pkb

prompt Core install complete.

prompt ================================================================================
prompt Install finished successfully.
prompt ================================================================================
