-- Page: Upload Snapshot (suggested Page 5)
-- Purpose: Store a target snapshot JSON into OEI_ENV_SYNC_SNAPSHOTS
-- Items:
--   P5_SNAPSHOT_NAME (Text), P5_TARGET_SCHEMA (Text), P5_SOURCE_ENV (Text), P5_PAYLOAD (Textarea CLOB), P5_MESSAGE (Display Only)
-- Button: P5_UPLOAD (Submit)
-- Process (After Submit): insert row, basic JSON validation

declare
  l_dummy number;
begin
  -- basic JSON validation: attempt to read first element
  select 1 into l_dummy
    from json_table(:P5_PAYLOAD format json, '$[0]'
           columns (object_type varchar2(30) path '$.object_type',
                    object_name varchar2(128) path '$.object_name'));

  insert into oei_env_sync_snapshots (snapshot_name, target_schema, source_env, payload)
  values (:P5_SNAPSHOT_NAME, :P5_TARGET_SCHEMA, :P5_SOURCE_ENV, :P5_PAYLOAD);

  :P5_MESSAGE := 'Snapshot uploaded: ' || :P5_SNAPSHOT_NAME;
exception
  when others then
    :P5_MESSAGE := 'Error: ' || sqlerrm;
    raise;
end;
/

