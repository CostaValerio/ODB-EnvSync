-- Page: Create Release (suggested Page 7)
-- Purpose: Generate a release bundle (manifest + script) and store in OEI_ENV_SYNC_RELEASES with status DRAFT
-- Items: P7_SCHEMA_NAME (Text), P7_SNAPSHOT_ID (Select), P7_TITLE (Text), P7_SCRIPT (Display Only CLOB), P7_MESSAGE
-- Button: P7_GENERATE (Submit)

declare
  l_script   clob;
  l_manifest clob;
  l_hash     varchar2(64);
begin
  l_manifest := oei_env_sync_capture_pkg.f_list_changes(
                   in_schema_name  => :P7_SCHEMA_NAME,
                   in_compare_json => (select payload from oei_env_sync_snapshots where snapshot_id = :P7_SNAPSHOT_ID)
                 );

  oei_env_sync_capture_pkg.p_generate_install_script(
    in_schema_name   => :P7_SCHEMA_NAME,
    in_compare_json  => (select payload from oei_env_sync_snapshots where snapshot_id = :P7_SNAPSHOT_ID),
    out_script       => l_script
  );

  l_hash := oei_env_sync_capture_pkg.f_ddl_hash(l_script);

  insert into oei_env_sync_releases (status, release_title, manifest_json, script_clob, script_hash)
  values ('DRAFT', :P7_TITLE, l_manifest, l_script, l_hash);

  :P7_SCRIPT  := l_script;
  :P7_MESSAGE := 'Release created as DRAFT with hash ' || l_hash;
exception
  when others then
    :P7_MESSAGE := 'Error: ' || sqlerrm;
    raise;
end;
/

