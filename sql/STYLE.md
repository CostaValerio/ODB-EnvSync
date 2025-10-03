SQL and PL/SQL Style Guide

- Naming
  - Packages: prefix with `oei_` and module name, public procedures `p_*`, public functions `f_*`.
  - Tables and columns: uppercase snake_case; constraints with clear prefixes (PK_, FK_, UQ_, CK_).
  - Variables: `l_` for locals, `g_` for package globals, `p_` for parameters.

- Formatting
  - Indentation: 4 spaces. No tabs.
  - One statement per line; terminate with `;`. Add `/` separator after PL/SQL units.
  - Align keywords in SQL (select, from, where), capitalize SQL keywords; lowercase identifiers unless quoting.
  - Use explicit column lists in INSERT/SELECT.

- JSON/LOB handling
  - Use `returning clob` in JSON_OBJECT/ARRAYAGG for consistent CLOB results.
  - Free temporary LOBs; check for `dbms_lob.getlength(...)` before appending.

- Error handling
  - Catch and rethrow only with added context; avoid swallowing errors broadly, except in optional best‑effort paths.

- Comments
  - Add block headers for packages and procedures explaining purpose and behavior.
  - Inline comments for non‑obvious logic or important decisions.

