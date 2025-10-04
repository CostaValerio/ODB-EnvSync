Oracle APEX integration (readable SQL snippets)

This folder provides readable, copy‑paste friendly SQL/PLSQL snippets to build a simple APEX frontend for the Env Sync Capture package. The goal is to help you quickly compose pages without relying on version‑specific APEX export files.

What’s included
- Pages for: Capture Schema, Capture Object, Generate Install Script, and Captured Objects Report
- Each page file describes the regions, items, buttons, and the exact PL/SQL process code to paste into APEX.

How to use
1) Create a new APEX application (Universal Theme is fine).
2) For each page below, add a new blank page (or appropriate page type) and copy the SQL/PLSQL from the corresponding file under `sql/apex/pages/`.
3) Ensure the parsing schema of the APEX app has execute privileges on `PCK_OEI_ENV_SYNC` and read access to `OEI_ENV_SYNC_SCHEMA_OBJECTS`.

Required privileges
- The parsing schema must be able to select from metadata views used by the package (ALL_* / USER_*). Grant as needed per your security policy.

Pages
- 01_Capture_Schema.sql: Inputs a schema name and triggers a full capture.
- 02_Capture_Object.sql: Inputs schema, object type and name to capture a single object.
- 03_Generate_Install_Script.sql: Generates the installation script; optionally filters by a compare JSON.
- 04_Captured_Objects_Report.sql: Lists captured objects for a schema with quick filters.

Notes
- Item names (P1_* / P2_* etc.) assume page numbers 1–4; adjust if you choose different page numbers.
- For production, consider adding authorization, confirmation dialogs, and logging.
