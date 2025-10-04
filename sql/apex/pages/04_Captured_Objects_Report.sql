-- Page: Captured Objects Report (suggested Page 4)
-- Purpose: Lists captured objects with filters and quick actions.
-- How to use in APEX:
--   1) Create a new Interactive Report page named "Captured Objects" (Page 4)
--   2) Add a Text Field item P4_SCHEMA_NAME (Default: UPPER(:APP_USER) or USER)
--   3) Set the report region source to the SQL below
--   4) Optionally add a link column to open the Generate page with object preselected

-- Region Source (Interactive Report or Interactive Grid as preferred):
select
  schema_name,
  object_type,
  object_name,
  captured_on,
  dbms_lob.getlength(payload) as payload_length
from oei_env_sync_schema_objects
where (:P4_SCHEMA_NAME is null or schema_name = upper(:P4_SCHEMA_NAME))
order by object_type, object_name;
/

-- Optional: Add an Action Menu link to recapture a selected object (Dynamic Action "Execute PL/SQL"):
--   PL/SQL Code:
--     begin
--       pck_oei_env_sync.p_capture_object(
--         in_schema_name => :P4_SCHEMA_NAME,
--         in_object_type => :OBJECT_TYPE,
--         in_object_name => :OBJECT_NAME
--       );
--     end;
--   Items to Submit: P4_SCHEMA_NAME, OBJECT_TYPE, OBJECT_NAME
--   Show Success Message: Enabled
