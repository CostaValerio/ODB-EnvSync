-- Page: Generate Install Script (suggested Page 3)
-- Purpose: Builds a concatenated DDL/script from captured objects.
-- How to use in APEX:
--   1) Create a new Blank page named "Generate Install Script" (Page 3)
--   2) Add a region "Parameters" and items:
--      - P3_SCHEMA_NAME: Text field (Default: UPPER(:APP_USER) or USER)
--      - P3_COMPARE_JSON: Text area (CLOB) – optional
--        Hint: Provide JSON array of {schema_name, object_type, object_name}
--   3) Add a region "Script" with a Display‑only item P3_SCRIPT (Escape special characters = No),
--      or use a Rich Text Editor/Code display component
--   4) Add a button P3_GENERATE (Action: Submit)
--   5) Create a Process (After Submit) with the PL/SQL code below
--   6) Optionally add a download button using APEX "File/Blob" tricks or a DA to trigger download

-- After Submit Process: Generate script
-- Name: PRC_GENERATE_SCRIPT
-- Type: PL/SQL Code
-- Code:
declare
  l_script clob;
  l_schema t_owner := coalesce(:P3_SCHEMA_NAME, user);
begin
  env_sync_capture_pkg.p_generate_install_script(
    in_schema_name   => l_schema,
    in_compare_json  => :P3_COMPARE_JSON,
    out_script       => l_script
  );

  :P3_SCRIPT := l_script;

  if l_script is null then
    apex_util.set_session_state('P3_SCRIPT', '');
    apex_application.g_print_success_message := 'No statements to generate.';
  else
    apex_application.g_print_success_message := 'Script generated.';
  end if;
exception
  when others then
    :P3_SCRIPT := 'Error: ' || sqlerrm;
    raise;
end;
/

-- Optional: Classic Report region as an alternative presentation
--   Query: select dbms_lob.substr(:P3_SCRIPT, 4000, (level-1)*4000+1) as chunk
--          from dual
--          connect by level <= ceil(nvl(dbms_lob.getlength(:P3_SCRIPT),0)/4000)

