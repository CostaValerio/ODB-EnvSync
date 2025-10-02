create or replace package body env_sync_capture_pkg as

    procedure configure_metadata_transform is
    begin
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,
                                          'SQLTERMINATOR', true);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,
                                          'PRETTY', true);
    end configure_metadata_transform;

    procedure upsert_payload(in_schema_name in t_owner,
                             in_object_type in t_object_type,
                             in_object_name in t_object_name,
                             in_payload in clob) is
    begin
        merge into oei_env_sync_schema_objects tgt
        using (select in_schema_name schema_name,
                      in_object_type object_type,
                      in_object_name object_name
                 from dual) src
           on (tgt.schema_name = src.schema_name
               and tgt.object_type = src.object_type
               and tgt.object_name = src.object_name)
        when matched then
            update set payload = in_payload,
                       captured_on = systimestamp
        when not matched then
            insert (schema_name, object_type, object_name, payload)
            values (in_schema_name, in_object_type, in_object_name, in_payload);
    end upsert_payload;

    function get_sequence_json(in_schema_name in t_owner,
                               in_sequence_name in t_object_name) return clob is
        l_json clob;
    begin
        select json_object(
                   'schema' value sequence_owner,
                   'sequence_name' value sequence_name,
                   'min_value' value min_value,
                   'max_value' value max_value,
                   'increment_by' value increment_by,
                   'cycle_flag' value cycle_flag,
                   'order_flag' value order_flag,
                   'cache_size' value cache_size,
                   'last_number' value last_number
                   returning clob)
          into l_json
          from all_sequences
         where sequence_owner = upper(in_schema_name)
           and sequence_name = upper(in_sequence_name);
        return l_json;
    exception
        when no_data_found then
            return null;
    end get_sequence_json;

    function get_table_json(in_schema_name in t_owner,
                            in_table_name in t_object_name) return clob is
        l_json clob;
    begin
        select json_object(
                   'schema' value t.owner,
                   'table_name' value t.table_name,
                   'tablespace_name' value t.tablespace_name,
                   'temporary' value t.temporary,
                   'nested' value t.nested,
                   'partitioned' value t.partitioned,
                   'columns' value (
                       select json_arrayagg(
                                  json_object(
                                      'column_name' value c.column_name,
                                      'data_type' value c.data_type,
                                      'data_length' value c.data_length,
                                      'data_precision' value c.data_precision,
                                      'data_scale' value c.data_scale,
                                      'nullable' value c.nullable,
                                      'default_on_null' value c.default_on_null,
                                      'data_default' value c.data_default
                                  returning clob)
                                  order by c.column_id)
                         from all_tab_columns c
                        where c.owner = t.owner
                          and c.table_name = t.table_name),
                   'constraints' value (
                       select json_arrayagg(
                                  json_object(
                                      'constraint_name' value uc.constraint_name,
                                      'constraint_type' value uc.constraint_type,
                                      'status' value uc.status,
                                      'deferrable' value uc.deferrable,
                                      'deferred' value uc.deferred,
                                      'search_condition' value uc.search_condition,
                                      'columns' value (
                                          select json_arrayagg(
                                                     json_object(
                                                         'column_name' value ucc.column_name,
                                                         'position' value ucc.position
                                                     returning clob)
                                                     order by ucc.position)
                                            from user_cons_columns ucc
                                           where ucc.owner = uc.owner
                                             and ucc.constraint_name = uc.constraint_name),
                                      'reference' value json_object(
                                          'r_owner' value uc.r_owner,
                                          'r_constraint_name' value uc.r_constraint_name
                                          returning clob)
                                  returning clob)
                                  order by uc.constraint_name)
                         from user_constraints uc
                        where uc.owner = t.owner
                          and uc.table_name = t.table_name),
                   'indexes' value (
                       select json_arrayagg(
                                  json_object(
                                      'index_name' value ui.index_name,
                                      'uniqueness' value ui.uniqueness,
                                      'status' value ui.status,
                                      'tablespace_name' value ui.tablespace_name,
                                      'columns' value (
                                          select json_arrayagg(
                                                     json_object(
                                                         'column_name' value uic.column_name,
                                                         'column_position' value uic.column_position,
                                                         'descend' value uic.descend
                                                     returning clob)
                                                     order by uic.column_position)
                                            from user_ind_columns uic
                                           where uic.index_name = ui.index_name
                                             and uic.index_owner = ui.owner)
                                  returning clob)
                                  order by ui.index_name)
                         from user_indexes ui
                        where ui.table_owner = t.owner
                          and ui.table_name = t.table_name),
                   'triggers' value (
                       select json_arrayagg(
                                  json_object(
                                      'trigger_name' value trg.trigger_name,
                                      'trigger_type' value trg.trigger_type,
                                      'triggering_event' value trg.triggering_event,
                                      'status' value trg.status,
                                      'description' value trg.description,
                                      'body' value trg.trigger_body
                                  returning clob)
                                  order by trg.trigger_name)
                         from user_triggers trg
                        where trg.table_owner = t.owner
                          and trg.table_name = t.table_name)
                   returning clob)
          into l_json
          from all_tables t
         where t.owner = upper(in_schema_name)
           and t.table_name = upper(in_table_name);
        return l_json;
    exception
        when no_data_found then
            return null;
    end get_table_json;

    function get_view_json(in_schema_name in t_owner,
                           in_view_name in t_object_name) return clob is
        l_json clob;
    begin
        select json_object(
                   'schema' value owner,
                   'view_name' value view_name,
                   'read_only' value read_only,
                   'text_length' value text_length,
                   'text' value text,
                   'columns' value (
                       select json_arrayagg(
                                  json_object(
                                      'column_name' value c.column_name,
                                      'data_type' value c.data_type,
                                      'data_length' value c.data_length,
                                      'data_precision' value c.data_precision,
                                      'data_scale' value c.data_scale,
                                      'nullable' value c.nullable
                                  returning clob)
                                  order by c.column_id)
                         from all_tab_columns c
                        where c.owner = v.owner
                          and c.table_name = v.view_name)
                   returning clob)
          into l_json
          from all_views v
         where v.owner = upper(in_schema_name)
           and v.view_name = upper(in_view_name);
        return l_json;
    exception
        when no_data_found then
            return null;
    end get_view_json;

    function get_program_unit_json(in_schema_name in t_owner,
                                   in_object_type in t_object_type,
                                   in_object_name in t_object_name) return clob is
        l_ddl clob;
        l_type varchar2(30) := upper(in_object_type);
    begin
        configure_metadata_transform;

        l_ddl := dbms_metadata.get_ddl(object_type => l_type,
                                       name        => upper(in_object_name),
                                       schema      => upper(in_schema_name));

        return json_object(
                   'schema' value upper(in_schema_name),
                   'object_type' value l_type,
                   'object_name' value upper(in_object_name),
                   'ddl' value l_ddl
                   returning clob);
    exception
        when others then
            return json_object(
                       'schema' value upper(in_schema_name),
                       'object_type' value l_type,
                       'object_name' value upper(in_object_name),
                       'error' value sqlerrm
                       returning clob);
    end get_program_unit_json;

    function get_trigger_json(in_schema_name in t_owner,
                              in_trigger_name in t_object_name) return clob is
    begin
        return get_program_unit_json(in_schema_name, 'TRIGGER', in_trigger_name);
    end get_trigger_json;

    function get_index_json(in_schema_name in t_owner,
                            in_index_name in t_object_name) return clob is
        l_json clob;
    begin
        select json_object(
                   'schema' value owner,
                   'index_name' value index_name,
                   'table_name' value table_name,
                   'table_owner' value table_owner,
                   'uniqueness' value uniqueness,
                   'tablespace_name' value tablespace_name,
                   'status' value status,
                   'columns' value (
                       select json_arrayagg(
                                  json_object(
                                      'column_name' value column_name,
                                      'column_position' value column_position,
                                      'descend' value descend
                                  returning clob)
                                  order by column_position)
                         from user_ind_columns c
                        where c.index_name = idx.index_name
                          and c.index_owner = idx.owner)
                   returning clob)
          into l_json
          from user_indexes idx
         where idx.owner = upper(in_schema_name)
           and idx.index_name = upper(in_index_name);
        return l_json;
    exception
        when no_data_found then
            return null;
    end get_index_json;

    function get_object_ddl(in_schema_name in t_owner,
                            in_object_type in t_object_type,
                            in_object_name in t_object_name) return clob is
        l_metadata_type varchar2(30);
    begin
        configure_metadata_transform;

        l_metadata_type := case upper(in_object_type)
                               when 'PACKAGE BODY' then 'PACKAGE_BODY'
                               else upper(in_object_type)
                           end;

        return dbms_metadata.get_ddl(object_type => l_metadata_type,
                                     name        => upper(in_object_name),
                                     schema      => upper(in_schema_name));
    exception
        when others then
            return null;
    end get_object_ddl;

    procedure capture_object(in_schema_name in t_owner,
                             in_object_type in t_object_type,
                             in_object_name in t_object_name) is
        l_payload clob;
        l_type varchar2(30) := upper(in_object_type);
    begin
        case l_type
            when 'SEQUENCE' then
                l_payload := get_sequence_json(in_schema_name, in_object_name);
            when 'TABLE' then
                l_payload := get_table_json(in_schema_name, in_object_name);
            when 'VIEW' then
                l_payload := get_view_json(in_schema_name, in_object_name);
            when 'PROCEDURE' then
                l_payload := get_program_unit_json(in_schema_name, 'PROCEDURE', in_object_name);
            when 'FUNCTION' then
                l_payload := get_program_unit_json(in_schema_name, 'FUNCTION', in_object_name);
            when 'PACKAGE' then
                l_payload := get_program_unit_json(in_schema_name, 'PACKAGE', in_object_name);
            when 'PACKAGE BODY' then
                l_payload := get_program_unit_json(in_schema_name, 'PACKAGE_BODY', in_object_name);
            when 'TRIGGER' then
                l_payload := get_trigger_json(in_schema_name, in_object_name);
            when 'INDEX' then
                l_payload := get_index_json(in_schema_name, in_object_name);
            else
                raise_application_error(-20001, 'Unsupported object type ' || l_type);
        end case;

        if l_payload is not null then
            upsert_payload(upper(in_schema_name), l_type, upper(in_object_name), l_payload);
        end if;
    end capture_object;

    procedure capture_schema(in_schema_name in t_owner default user) is
    begin
        for obj in (
            select object_type, object_name
              from all_objects
             where owner = upper(in_schema_name)
               and object_type in (
                   'SEQUENCE',
                   'TABLE',
                   'VIEW',
                   'PROCEDURE',
                   'FUNCTION',
                   'PACKAGE',
                   'PACKAGE BODY',
                   'TRIGGER',
                   'INDEX')
             order by case object_type
                         when 'SEQUENCE' then 1
                         when 'TABLE' then 2
                         when 'INDEX' then 3
                         when 'TRIGGER' then 4
                         when 'VIEW' then 5
                         when 'PACKAGE' then 6
                         when 'PACKAGE BODY' then 7
                         when 'PROCEDURE' then 8
                         when 'FUNCTION' then 9
                         else 100
                      end,
                      object_name)
        loop
            capture_object(in_schema_name => in_schema_name,
                           in_object_type => obj.object_type,
                           in_object_name => obj.object_name);
        end loop;
    end capture_schema;

    procedure generate_install_script(in_schema_name in t_owner,
                                      in_compare_json in clob default null,
                                      out_script out clob) is
        procedure append_ddl(in_ddl in clob, in_type in t_object_type) is
            l_upper_type varchar2(30) := upper(in_type);
        begin
            if in_ddl is null then
                return;
            end if;

            if dbms_lob.getlength(out_script) > 0 then
                dbms_lob.writeappend(out_script, 1, chr(10));
            end if;

            dbms_lob.append(out_script, in_ddl);
            dbms_lob.writeappend(out_script, 1, chr(10));

            if l_upper_type in ('PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TRIGGER') then
                dbms_lob.writeappend(out_script, 2, '/' || chr(10));
            end if;

            dbms_lob.writeappend(out_script, 1, chr(10));
        end append_ddl;

        procedure process_missing_objects is
        begin
            for obj in (
                select so.object_type, so.object_name
                  from oei_env_sync_schema_objects so
                 where so.schema_name = upper(in_schema_name)
                   and not exists (
                           select 1
                             from json_table(in_compare_json format json, '$[*]'
                                  columns (
                                      schema_name varchar2(128) path '$.schema_name',
                                      object_type varchar2(30)  path '$.object_type',
                                      object_name varchar2(128) path '$.object_name'
                                  )) cmp
                            where so.schema_name = upper(nvl(cmp.schema_name, in_schema_name))
                              and so.object_type = upper(cmp.object_type)
                              and so.object_name = upper(cmp.object_name))
                 order by case so.object_type
                             when 'SEQUENCE' then 1
                             when 'TABLE' then 2
                             when 'INDEX' then 3
                             when 'TRIGGER' then 4
                             when 'VIEW' then 5
                             when 'PACKAGE' then 6
                             when 'PACKAGE BODY' then 7
                             when 'PROCEDURE' then 8
                             when 'FUNCTION' then 9
                             else 100
                          end,
                          so.object_name)
            loop
                append_ddl(get_object_ddl(in_schema_name => in_schema_name,
                                          in_object_type => obj.object_type,
                                          in_object_name => obj.object_name),
                           obj.object_type);
            end loop;
        end process_missing_objects;

    begin
        dbms_lob.createtemporary(out_script, true);

        if in_compare_json is not null and dbms_lob.getlength(in_compare_json) > 0 then
            process_missing_objects;
        else
            for obj in (
                select so.object_type, so.object_name
                  from oei_env_sync_schema_objects so
                 where so.schema_name = upper(in_schema_name)
                 order by case so.object_type
                             when 'SEQUENCE' then 1
                             when 'TABLE' then 2
                             when 'INDEX' then 3
                             when 'TRIGGER' then 4
                             when 'VIEW' then 5
                             when 'PACKAGE' then 6
                             when 'PACKAGE BODY' then 7
                             when 'PROCEDURE' then 8
                             when 'FUNCTION' then 9
                             else 100
                          end,
                          so.object_name)
            loop
                append_ddl(get_object_ddl(in_schema_name => in_schema_name,
                                          in_object_type => obj.object_type,
                                          in_object_name => obj.object_name),
                           obj.object_type);
            end loop;
        end if;

        if dbms_lob.getlength(out_script) = 0 then
            dbms_lob.freetemporary(out_script);
            out_script := null;
        end if;
    exception
        when others then
            if dbms_lob.istemporary(out_script) = 1 then
                dbms_lob.freetemporary(out_script);
            end if;
            out_script := null;
            raise;
    end generate_install_script;

end env_sync_capture_pkg;
/

show errors package env_sync_capture_pkg;
show errors package body env_sync_capture_pkg;

