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

    -- Generates a concatenated installation script (DDL) into out_script.
    -- If in_compare_json is provided, includes only objects missing from the JSON list.
    procedure p_generate_install_script(in_schema_name in t_owner,
                                      in_compare_json in clob default null,
                                      out_script out clob);
end oei_env_sync_capture_pkg;
/
