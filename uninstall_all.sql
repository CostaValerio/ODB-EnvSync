prompt ================================================================================
prompt ODB-EnvSync - Uninstall (Core + optional APEX pages)
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

prompt ----------------------------------------------------------------
prompt Optional: Remove APEX pages (APEX 24.2)
prompt   - When ready, uncomment and set WORKSPACE and APP_ID below.
prompt ----------------------------------------------------------------
-- define WORKSPACE = YOUR_WORKSPACE
-- define APP_ID    = 100
-- declare
--   l_ws_id number;
-- begin
--   l_ws_id := apex_util.find_security_group_id(p_workspace => '&WORKSPACE.');
--   if l_ws_id is not null then
--     apex_util.set_security_group_id(l_ws_id);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 1);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 2);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 3);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 4);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 5);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 6);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 7);
--     apex_application_api.remove_page(p_flow_id => &APP_ID., p_page_id => 8);
--   end if;
-- end;
-- /

prompt ================================================================================
prompt Uninstall finished.
prompt ================================================================================
