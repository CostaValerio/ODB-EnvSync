-- Page: Capture Schema (suggested Page 1)
-- Purpose: Captures metadata for all supported objects in a schema.
-- How to use in APEX:
--   1) Create a new Blank page named "Capture Schema" (Page 1)
--   2) Add a region "Capture Schema"
--   3) Add a text field item P1_SCHEMA_NAME (Default: UPPER(:APP_USER) or USER)
--   4) Add a display‑only item P1_MESSAGE (escape special characters = Yes)
--   5) Add a button P1_CAPTURE (Action: Submit)
--   6) Create a Process (After Submit) with the PL/SQL code below
--   7) Optional: Set the page "Success Message" to "Capture completed for &P1_SCHEMA_NAME." to show a green banner

-- Validation (optional): ensure the schema exists
-- Example SQL for a page-level validation (Function returning boolean):
--   return exists (
--     select 1 from all_users where username = upper(:P1_SCHEMA_NAME)
--   );

-- After Submit Process: Capture schema
-- Name: PRC_CAPTURE_SCHEMA
-- Type: PL/SQL Code
-- Code:
declare
  l_schema t_owner := coalesce(:P1_SCHEMA_NAME, user);
begin
  pck_oei_env_sync.p_capture_schema(l_schema);
  :P1_MESSAGE := 'Capture completed for ' || upper(l_schema);
exception
  when others then
    :P1_MESSAGE := 'Error: ' || sqlerrm;
    raise;
end;
/
