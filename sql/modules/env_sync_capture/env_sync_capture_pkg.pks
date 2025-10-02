create or replace package env_sync_capture_pkg as
    subtype t_owner is varchar2(128);
    subtype t_object_type is varchar2(30);
    subtype t_object_name is varchar2(128);

    procedure capture_schema(in_schema_name in t_owner default user);
    procedure capture_object(in_schema_name in t_owner,
                             in_object_type in t_object_type,
                             in_object_name in t_object_name);

    function get_sequence_json(in_schema_name in t_owner,
                               in_sequence_name in t_object_name) return clob;

    function get_table_json(in_schema_name in t_owner,
                            in_table_name in t_object_name) return clob;

    function get_view_json(in_schema_name in t_owner,
                           in_view_name in t_object_name) return clob;

    function get_program_unit_json(in_schema_name in t_owner,
                                   in_object_type in t_object_type,
                                   in_object_name in t_object_name) return clob;

    function get_trigger_json(in_schema_name in t_owner,
                              in_trigger_name in t_object_name) return clob;

    function get_index_json(in_schema_name in t_owner,
                            in_index_name in t_object_name) return clob;

    procedure generate_install_script(in_schema_name in t_owner,
                                      in_compare_json in clob default null,
                                      out_script out clob);
end env_sync_capture_pkg;
/
