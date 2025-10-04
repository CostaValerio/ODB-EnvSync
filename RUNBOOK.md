Env Sync — DEV→PROD Runbook

Use this simple runbook to install the tool, capture from DEV, export a PROD snapshot, generate the install script in DEV, and apply it to PROD. Commands are SQL*Plus/SQLcl friendly and work in SQL Developer too.

Prereqs
- Connect as the schema that owns your objects (or a deployment schema with the right privileges).
- Metadata access: execute `DBMS_METADATA` (and `DBMS_METADATA_DIFF` if you want DIFFs).
- Optional: APEX 24.2 if you intend to use the UI later (not required for the PL/SQL flow).

One‑Time Install (DEV and/or PROD)
1) Open SQL Developer/SQLcl, connect to the target schema.
2) From the project root, run:
   @install_all.sql
3) APEX install is commented out by default; you can enable it later when needed.

Daily DEV Workflow
1) Capture current DEV schema objects
   begin
     pck_oei_env_sync.p_capture_schema('DEV_SCHEMA');
   end;
   /
   - Run after meaningful changes (or schedule nightly). This stores object payloads + DDL hash.

2) (Optional) Configure data seeds (rows to deploy with DDL)
   insert into oei_env_sync_seed_tables(table_name, where_clause)
   values ('MY_CONFIG_TABLE', 'IS_ACTIVE = ''Y''');
   commit;

Export Target Snapshot (PROD, repeat per target)
Purpose: produce a JSON list of objects that exist in the target schema.
1) Connect to each PROD database (target schema).
2) Run and save the JSON to a file (e.g., prod_snapshot.json):
   set long 2000000000 longchunksize 32767 pages 0 lines 32767 trimspool on
   spool prod_snapshot.json
   select json_arrayagg(
            json_object(
              'schema_name' value owner,
              'object_type' value object_type,
              'object_name' value object_name
              returning clob)
            order by object_type, object_name)
     from all_objects
    where owner = upper('PROD_SCHEMA')
      and object_type in (
        'SEQUENCE','DIRECTORY','TYPE','TYPE BODY','TABLE','VIEW','MATERIALIZED VIEW',
        'PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','TRIGGER','INDEX');
   spool off
   - This is your “compare JSON” for that PROD database.

Generate Install Script (DEV, per PROD snapshot)
Purpose: build a script that creates only what’s missing (and, where possible, alters what changed).
1) Open the PROD snapshot file and copy its JSON content to your clipboard.
2) In DEV, run the generator and spool the output:
   set serveroutput on size unlimited
   set long 2000000000 longchunksize 32767 pages 0 lines 32767 trimspool on
   var g_script clob
   declare
     l_script  clob;
     l_compare clob := q'[PASTE_PROD_JSON_HERE]';
   begin
     pck_oei_env_sync.p_generate_install_script(
       in_schema_name  => 'DEV_SCHEMA',
       in_compare_json => l_compare,
       out_script      => l_script);
     :g_script := l_script;
   end;
   /
   spool install_for_PROD_SCHEMA.sql
   print g_script
   spool off
   - The file `install_for_PROD_SCHEMA.sql` is your deployable script.
   - Behavior:
     - Emits CREATE statements for objects missing in PROD.
     - Attempts ALTERs (DIFF) for supported types when source+target schemas are in the same DB and the compare JSON includes the target schema name per row.
     - Skips unchanged objects (based on stored DDL hash in DEV capture).
     - Appends configured data seeds (MERGE) if a target schema can be determined from the compare JSON.

Detect Modified Objects Across Different Databases (Hash‑based)
When DEV and PROD are in different databases, use the baseline/compare helpers to reliably identify MODIFIED vs UNCHANGED without DIFF.

1) DEV: Export DEV baseline with hashes
   set long 2000000000 longchunksize 32767 pages 0 lines 32767 trimspool on
   spool dev_baseline.json
  select pck_oei_env_sync.f_export_baseline('DEV_SCHEMA') from dual;
   spool off

2) PROD: Compare DEV baseline to PROD schema
   var dev_json clob
   declare l_clob clob := q'[PASTE_DEV_BASELINE_JSON_HERE]'; begin :dev_json := l_clob; end; /
   spool prod_diff.json
  select pck_oei_env_sync.f_compare_baseline_to_schema('PROD_SCHEMA', :dev_json) from dual;
   spool off
   - Output includes change_type for each object: MISSING, MODIFIED, UNCHANGED (plus dev_hash/tgt_hash).

3) DEV: Generate CREATE OR REPLACE script for modified code objects only (safe)
   var g_code clob
   declare
     l_code clob;
     l_modified clob := q'[PASTE_ONLY_MODIFIED_ARRAY_JSON_HERE]';
   begin
     pck_oei_env_sync.p_generate_replace_script_for(
       in_schema_name  => 'DEV_SCHEMA',
       in_objects_json => l_modified,
       out_script      => l_code);
     :g_code := l_code;
   end; /
   spool install_modified_code_for_PROD.sql
   print g_code
   spool off
   - This script covers code units (PACKAGE/PROC/FUNC/TRIGGER/VIEW/TYPE...), not tables/indexes.

Install Script in PROD
1) Review the script (it includes safety headers and a recompile block).
2) Connect to the PROD database (target schema) and run:
   @install_for_PROD_SCHEMA.sql

Tips and Variations
- Different databases (DEV and PROD): DIFF‑based ALTERs require both schemas accessible in the same DB. If DEV and PROD are separate, the script will still create missing objects and use CREATE OR REPLACE for code where applicable; table ALTERs may fall back to full DDL. For precise ALTERs, compare DEV against a local clone of PROD in the same database.
- Reruns: recapture in DEV (step “Daily DEV Workflow”) after changes to keep hashes current; regenerate per target snapshot.
- Multiple PRODs: repeat the “Export Target Snapshot” and “Generate Install Script” steps per PROD.

Optional APEX Flow (later)
- Upload Snapshot (Page 5): paste the PROD JSON into the app and save.
- Changes Review (Page 6): inspect ADDED/MODIFIED/DROPPED/UNCHANGED and preview DDL.
- Generate Install Script (Page 3): builds and shows the script from DEV capture vs selected snapshot.
- Create Release (Page 7): stores manifest + script with a hash for auditability.

Troubleshooting
- Missing privileges on metadata: ensure access to ALL_* or USER_* views and `DBMS_METADATA*` packages.
- Large output truncated: ensure `set long` and `print` usage as shown above; avoid relying on DBMS_OUTPUT for big CLOBs.
- Scheduler/audit are optional—safe to skip in PROD if not needed.
