prompt ================================================================================
prompt ODB-EnvSync - Main Installer (Core + optional APEX pages)
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
@sql/ddl/env_sync_capture/oei_env_sync_scheduler.sql
@sql/ddl/env_sync_capture/oei_env_sync_seed_tables.sql

prompt Installing PL/SQL package (spec + body)...
@sql/modules/env_sync_capture/oei_sync_capture_pkg.pks
@sql/modules/env_sync_capture/oei_sync_capture_pkg.pkb

prompt Core install complete.

prompt ----------------------------------------------------------------
prompt APEX pages install (APEX 24.2) is commented out for now.
prompt   - When ready, uncomment the lines below to install the APEX pages.
prompt   - Set the workspace and application id accordingly.
prompt ----------------------------------------------------------------

-- define WORKSPACE = YOUR_WORKSPACE
-- define APP_ID    = 100

-- prompt Installing APEX pages into &WORKSPACE., app &APP_ID.
-- @sql/apex/install/apex_24_2_env_sync.sql

prompt ================================================================================
prompt Install finished successfully.
prompt ================================================================================
