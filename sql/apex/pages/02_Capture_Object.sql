-- Page: Capture Object (suggested Page 2)
-- Purpose: Captures metadata for a single object by type and name.
-- How to use in APEX:
--   1) Create a new Blank page named "Capture Object" (Page 2)
--   2) Add a region "Capture Object"
--   3) Add items:
--      - P2_SCHEMA_NAME: Text field (Default: UPPER(:APP_USER) or USER)
--      - P2_OBJECT_TYPE: Select list (Static values)
--            Static LOV:
--              SEQUENCE;SEQUENCE
--              TABLE;TABLE
--              VIEW;VIEW
--              PROCEDURE;PROCEDURE
--              FUNCTION;FUNCTION
--              PACKAGE;PACKAGE
--              PACKAGE BODY;PACKAGE BODY
--              TRIGGER;TRIGGER
--              INDEX;INDEX
--      - P2_OBJECT_NAME: Text field
--      - P2_MESSAGE: Display‑only (for feedback)
--   4) Add a button P2_CAPTURE (Action: Submit)
--   5) Create a Process (After Submit) with the PL/SQL code below

-- Optional validations:
--  - Ensure object exists in the given schema and type
--  - Ensure object name is not null

-- After Submit Process: Capture object
-- Name: PRC_CAPTURE_OBJECT
-- Type: PL/SQL Code
-- Code:
declare
  l_schema t_owner := coalesce(:P2_SCHEMA_NAME, user);
  l_type   t_object_type := :P2_OBJECT_TYPE;
  l_name   t_object_name := :P2_OBJECT_NAME;
begin
  oei_env_sync_capture_pkg.p_capture_object(
    in_schema_name => l_schema,
    in_object_type => l_type,
    in_object_name => l_name
  );
  :P2_MESSAGE := 'Captured ' || upper(l_type) || ' ' || upper(l_name) || ' in ' || upper(l_schema);
exception
  when others then
    :P2_MESSAGE := 'Error: ' || sqlerrm;
    raise;
end;
/
