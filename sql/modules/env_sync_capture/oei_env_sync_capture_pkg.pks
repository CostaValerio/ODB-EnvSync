-- canonical file name for package spec
create or replace package oei_env_sync_capture_pkg as
    /*
      Package specification for environment sync capture utilities.
      - Public procedures use prefix p_
      - Public functions use prefix f_
      Exposes operations to capture object metadata as JSON and generate
      install scripts from captured objects.
    */
    -- Common subtype aliases for clarity and consistency
    subtype t_owner is varchar2(128);
    subtype t_object_type is varchar2(30);
    subtype t_object_name is varchar2(128);

    -- Captures metadata for all supported objects within a schema
    procedure p_capture_schema(in_schema_name in t_owner default user);
    -- Captures metadata for a single object by type and name
    procedure p_capture_object(in_schema_name in t_owner,
                             in_object_type in t_object_type,
                             in_object_name in t_object_name);

    -- Returns JSON with sequence attributes
    function f_get_sequence_json(in_schema_name in t_owner,
                               in_sequence_name in t_object_name) return clob;

    -- Returns JSON with table attributes, columns, constraints, indexes and triggers
    function f_get_table_json(in_schema_name in t_owner,
                            in_table_name in t_object_name) return clob;

    -- Returns JSON with view attributes and columns
    function f_get_view_json(in_schema_name in t_owner,
                           in_view_name in t_object_name) return clob;

    -- Returns JSON with DDL for program units (PACKAGE, PACKAGE_BODY, PROCEDURE, FUNCTION)
    function f_get_program_unit_json(in_schema_name in t_owner,
                                   in_object_type in t_object_type,
                                   in_object_name in t_object_name) return clob;

    -- Returns JSON with trigger DDL via program unit helper
    function f_get_trigger_json(in_schema_name in t_owner,
                              in_trigger_name in t_object_name) return clob;

    -- Returns JSON with index attributes and columns
    function f_get_index_json(in_schema_name in t_owner,
                            in_index_name in t_object_name) return clob;

    -- Normalize DDL for consistent hashing (trim, remove terminators, collapse whitespace)
    function f_normalize_ddl(in_ddl in clob) return clob;

    -- Hash DDL using SHA-256 over normalized content; returns lowercase hex
    function f_ddl_hash(in_ddl in clob) return varchar2;

    -- Generates a concatenated installation script (DDL) into out_script.
    -- If in_compare_json is provided, includes only objects missing from the JSON list.
    procedure p_generate_install_script(in_schema_name in t_owner,
                                      in_compare_json in clob default null,
                                      out_script out clob);

    -- Attempt to produce ALTER statements to transform target object into source
    -- Only works when both schemas are accessible in the same database and supported by DBMS_METADATA_DIFF
    function f_diff_object(in_src_schema in t_owner,
                           in_tgt_schema in t_owner,
                           in_object_type in t_object_type,
                           in_object_name in t_object_name) return clob;

    -- List changes between captured objects of in_schema and a target snapshot JSON.
    -- Returns JSON array with fields: schema_name, object_type, object_name, change_type
    -- change_type ∈ ('ADDED','MODIFIED','DROPPED','UNCHANGED')
    function f_list_changes(in_schema_name in t_owner,
                            in_compare_json in clob) return clob;

    -- Generate MERGE DML statements for configured seed tables from source to target schema
    function f_generate_seed_merges(in_src_schema in t_owner,
                                    in_tgt_schema in t_owner) return clob;

    -- Retrieve dependent DDL for an object (e.g., OBJECT_GRANT, SYNONYM)
    function f_get_dependent_ddl(in_schema_name in t_owner,
                                 in_object_type in t_object_type,
                                 in_object_name in t_object_name,
                                 in_dep_type    in varchar2) return clob;
end oei_env_sync_capture_pkg;
/
