prompt ================================================================================
prompt ODB-EnvSync - Uninstall (Core only)
prompt ================================================================================
set define on
set echo on
set termout on
set serveroutput on size unlimited
whenever sqlerror continue


prompt Dropping audit trigger and helpers (if present)...
begin execute immediate 'drop trigger oei_env_sync_audit_trg'; exception when others then null; end;
/
begin execute immediate 'drop procedure oei_env_sync_audit_enable'; exception when others then null; end;
/
begin execute immediate 'drop procedure oei_env_sync_audit_disable'; exception when others then null; end;
/

prompt Dropping package (spec and body)...
begin execute immediate 'drop package body oei_env_sync_capture_pkg'; exception when others then null; end;
/
begin execute immediate 'drop package oei_env_sync_capture_pkg'; exception when others then null; end;
/

prompt Dropping tables (child→parent order)...
begin execute immediate 'drop table oei_env_sync_install_log purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_env_sync_releases purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_env_sync_snapshots purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_env_sync_schema_objects purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_env_sync_audit purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_env_sync_seed_tables purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_install_script_strategy_naming purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_install_script_type_mode purge'; exception when others then null; end;
/
begin execute immediate 'drop table oei_install_script_strategy purge'; exception when others then null; end;
/


prompt ================================================================================
prompt Uninstall finished.
prompt ================================================================================
