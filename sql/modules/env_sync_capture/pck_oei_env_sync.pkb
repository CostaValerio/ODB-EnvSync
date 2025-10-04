-- canonical file name for package body (renamed to pck_oei_env_sync.pkb)
create or replace package body pck_oei_env_sync as

    /*
      Package body implementing environment sync capture utilities.
      Responsibilities:
        - Configure DBMS_METADATA output for consistent DDL
        - Extract metadata for supported object types as JSON
        - Persist captured payloads into OEI_ENV_SYNC_SCHEMA_OBJECTS
        - Generate install scripts from captured objects (optionally diffed)
      Naming convention:
        - Procedures: p_*
        - Functions:  f_*
    */

    -- Configure DBMS_METADATA session transforms for readable DDL output
    procedure p_configure_metadata_transform is
    begin
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,
                                          'SQLTERMINATOR', true);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,
                                          'PRETTY', true);
    end p_configure_metadata_transform;

    -- Normalize DDL to a canonical form to improve hash stability
    function f_normalize_ddl(in_ddl in clob) return clob is
        l_ddl clob := in_ddl;
    begin
        if l_ddl is null then
            return null;
        end if;
        -- Remove trailing SQL*Plus delimiter '/'
        l_ddl := regexp_replace(l_ddl, '/\s*$', '');
        -- Remove trailing semicolon terminator
        l_ddl := regexp_replace(l_ddl, ';\s*$', '');
        -- Replace newlines with spaces
        l_ddl := replace(replace(l_ddl, chr(13), ' '), chr(10), ' ');
        -- Collapse excessive whitespace
        l_ddl := regexp_replace(l_ddl, '\s+', ' ');
        -- Trim
        l_ddl := trim(l_ddl);
        return l_ddl;
    end f_normalize_ddl;

    -- Compute SHA-256 hash (hex, lowercase) of normalized DDL
    function f_ddl_hash(in_ddl in clob) return varchar2 is
        l_norm      clob;
        l_hash_hex  varchar2(64);
    begin
        if in_ddl is null then
            return null;
        end if;
        l_norm := f_normalize_ddl(in_ddl);
        if l_norm is null then
            return null;
        end if;
        -- Try STANDARD_HASH via dynamic block (handles versions without compile-time symbol)
        begin
            execute immediate 'begin :x := lower(rawtohex(standard_hash(:p,''SHA256''))); end;'
                using out l_hash_hex, in dbms_lob.substr(l_norm, 32767, 1);
        exception when others then
            l_hash_hex := null;
        end;
        if l_hash_hex is not null then
            return l_hash_hex;
        end if;
        -- Fallback to DBMS_CRYPTO over a VARCHAR2 slice (best-effort on older DBs)
        begin
            execute immediate 'begin :x := lower(rawtohex(dbms_crypto.hash(utl_raw.cast_to_raw(:p), dbms_crypto.hash_sh256))); end;'
                using out l_hash_hex, in dbms_lob.substr(l_norm, 32767, 1);
        exception when others then
            l_hash_hex := null;
        end;
        return l_hash_hex;
    end f_ddl_hash;

    -- Internal: compute current object DDL hash for a given object
    function f_compute_object_hash(in_schema_name in t_owner,
                                   in_object_type in t_object_type,
                                   in_object_name in t_object_name) return varchar2 is
        l_ddl clob;
    begin
        l_ddl := f_get_object_ddl(in_schema_name => in_schema_name,
                                  in_object_type => in_object_type,
                                  in_object_name => in_object_name);
        return f_ddl_hash(l_ddl);
    exception
        when others then
            return null;
    end f_compute_object_hash;

    -- Retrieve per-type generation mode from config table, defaulting as needed
    function f_get_type_mode(in_object_type in t_object_type) return varchar2 is
        l_mode varchar2(20);
    begin
        select generation_mode
          into l_mode
          from oei_install_script_type_mode
         where object_type = upper(in_object_type);
        return l_mode;
    exception
        when no_data_found then
            -- Defaults: DIFF for TABLE and INDEX; DDL otherwise
            if upper(in_object_type) in ('TABLE','INDEX') then
                return 'DIFF';
            else
                return 'DDL';
            end if;
        when others then
            return 'DDL';
    end f_get_type_mode;

    -- Produce ALTER statements to transform target object into source, when supported
    function f_diff_object(in_src_schema in t_owner,
                           in_tgt_schema in t_owner,
                           in_object_type in t_object_type,
                           in_object_name in t_object_name) return clob is
        l_type varchar2(30) := case upper(in_object_type)
                                   when 'PACKAGE BODY' then 'PACKAGE_BODY'
                                   else upper(in_object_type)
                               end;
        l_alter clob;
    begin
        p_configure_metadata_transform;
        -- Best-effort call; if unsupported, return NULL
        l_alter := dbms_metadata_diff.compare_alter(
                      object_type => l_type,
                      name1       => upper(in_object_name),
                      name2       => upper(in_object_name),
                      schema1     => upper(in_src_schema),
                      schema2     => upper(in_tgt_schema));
        return l_alter;
    exception
        when others then
            return null;
    end f_diff_object;

    -- Build a JSON array of changes between captured source schema and provided target snapshot
    function f_list_changes(in_schema_name in t_owner,
                            in_compare_json in clob) return clob is
        l_json clob;
    begin
        if in_compare_json is null or dbms_lob.getlength(in_compare_json) = 0 then
            -- No compare: everything is considered ADDED
            select json_arrayagg(
                       json_object(
                           'schema_name' value upper(in_schema_name),
                           'object_type' value so.object_type,
                           'object_name' value so.object_name,
                           'change_type' value 'ADDED'
                           returning clob)
                       order by so.object_type, so.object_name)
              into l_json
              from oei_env_sync_schema_objects so
             where so.schema_name = upper(in_schema_name);
            return l_json;
        end if;

        with cmp as (
            select upper(nvl(c.schema_name, in_schema_name)) schema_name,
                   upper(c.object_type) object_type,
                   upper(c.object_name) object_name
              from json_table(in_compare_json format json, '$[*]'
                   columns (
                     schema_name varchar2(128) path '$.schema_name',
                     object_type varchar2(30)  path '$.object_type',
                     object_name varchar2(128) path '$.object_name'
                   )) c
        ), src as (
            select so.object_type, so.object_name, so.ddl_hash
              from oei_env_sync_schema_objects so
             where so.schema_name = upper(in_schema_name)
        ), added as (
            select upper(in_schema_name) schema_name, s.object_type, s.object_name, 'ADDED' change_type
              from src s
             where not exists (
                   select 1 from cmp c
                    where c.object_type = s.object_type and c.object_name = s.object_name)
        ), dropped as (
            select c.schema_name, c.object_type, c.object_name, 'DROPPED' change_type
              from cmp c
             where not exists (
                   select 1 from src s
                    where s.object_type = c.object_type and s.object_name = c.object_name)
        ), modified as (
            select upper(in_schema_name) schema_name,
                   s.object_type,
                   s.object_name,
                   'MODIFIED' change_type
              from src s
              join cmp c
                on c.object_type = s.object_type and c.object_name = s.object_name
             where (select f_compute_object_hash(c.schema_name, s.object_type, s.object_name) from dual) != s.ddl_hash
        ), unchanged as (
            select upper(in_schema_name) schema_name,
                   s.object_type,
                   s.object_name,
                   'UNCHANGED' change_type
              from src s
              join cmp c
                on c.object_type = s.object_type and c.object_name = s.object_name
             where (select f_compute_object_hash(c.schema_name, s.object_type, s.object_name) from dual) = s.ddl_hash
        )
        select json_arrayagg(
                   json_object(
                       'schema_name' value schema_name,
                       'object_type' value object_type,
                       'object_name' value object_name,
                       'change_type' value change_type
                       returning clob)
                   order by change_type, object_type, object_name)
          into l_json
          from (
                select * from added
                union all
                select * from modified
                union all
                select * from dropped
                union all
                select * from unchanged
               );
        return l_json;
    exception
        when others then
            return null;
    end f_list_changes;

    -- Inserts or updates a captured JSON payload for a given object
    procedure p_upsert_payload(in_schema_name in t_owner,
                             in_object_type in t_object_type,
                             in_object_name in t_object_name,
                             in_payload in clob) is
        l_hash varchar2(64);
    begin
        -- Compute current DDL hash for the object (when retrievable)
        l_hash := f_compute_object_hash(in_schema_name, in_object_type, in_object_name);
        -- Merge ensures idempotent persistence by primary key (schema, type, name)
        merge into oei_env_sync_schema_objects tgt
        using (select in_schema_name schema_name,
                      in_object_type object_type,
                      in_object_name object_name
                 from dual) src
           on (tgt.schema_name = src.schema_name
               and tgt.object_type = src.object_type
               and tgt.object_name = src.object_name)
        when matched then
            -- Update payload on re-capture
            update set payload = in_payload,
                       ddl_hash = l_hash,
                       captured_on = systimestamp
        when not matched then
            -- Insert new object payload
            insert (schema_name, object_type, object_name, payload, ddl_hash)
            values (in_schema_name, in_object_type, in_object_name, in_payload, l_hash);
    end p_upsert_payload;

    -- Produce JSON describing a single sequence
    function f_get_sequence_json(in_schema_name in t_owner,
                               in_sequence_name in t_object_name) return clob is
        l_json clob;
    begin
        -- Build a single JSON object with sequence properties
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
            -- Not found: return NULL to signal absence
            return null;
    end f_get_sequence_json;

    -- Produce JSON describing a single table and its dependent metadata
    function f_get_table_json(in_schema_name in t_owner,
                            in_table_name in t_object_name) return clob is
        l_json clob;
    begin
        -- Build a JSON object with table attributes and nested collections
        select json_object(
                   'schema' value t.owner,
                   'table_name' value t.table_name,
                   'tablespace_name' value t.tablespace_name,
                   'temporary' value t.temporary,
                   'nested' value t.nested,
                   'partitioned' value t.partitioned,
                   -- Array of column definitions
                   'columns' value (
                       select json_arrayagg(
                                  json_object(
                                      'column_name' value c.column_name,
                                      'data_type' value c.data_type,
                                      'data_length' value c.data_length,
                                      'data_precision' value c.data_precision,
                                      'data_scale' value c.data_scale,
                                      'nullable' value c.nullable,
                                      'default_on_null' value c.default_on_null
                                  returning clob)
                                  order by c.column_id)
                         from all_tab_columns c
                        where c.owner = t.owner
                          and c.table_name = t.table_name),
                   -- Array of table constraints with columns and references
                   'constraints' value (
                       select json_arrayagg(
                                  json_object(
                                      'constraint_name' value uc.constraint_name,
                                      'constraint_type' value uc.constraint_type,
                                      'status' value uc.status,
                                      'deferrable' value uc.deferrable,
                                      'deferred' value uc.deferred,
                                      -- Array of constrained columns in order
                                      'columns' value (
                                          select json_arrayagg(
                                                     json_object(
                                                         'column_name' value ucc.column_name,
                                                         'position' value ucc.position
                                                     returning clob)
                                                     order by ucc.position)
                                            from all_cons_columns ucc
                                           where ucc.owner = uc.owner
                                             and ucc.constraint_name = uc.constraint_name
                                             and ucc.table_name = uc.table_name),
                                      -- Optional referenced constraint (FK)
                                      'reference' value json_object(
                                          'r_owner' value uc.r_owner,
                                          'r_constraint_name' value uc.r_constraint_name
                                          returning clob)
                                  returning clob)
                                  order by uc.constraint_name)
                         from all_constraints uc
                        where uc.owner = t.owner
                          and uc.table_name = t.table_name),
                   -- Array of indexes defined on the table with indexed columns
                   'indexes' value (
                       select json_arrayagg(
                                  json_object(
                                      'index_name' value ui.index_name,
                                      'uniqueness' value ui.uniqueness,
                                      'status' value ui.status,
                                      'tablespace_name' value ui.tablespace_name,
                                      -- Array of index column list in order
                                      'columns' value (
                                          select json_arrayagg(
                                                     json_object(
                                                         'column_name' value uic.column_name,
                                                         'column_position' value uic.column_position,
                                                         'descend' value uic.descend
                                                     returning clob)
                                                     order by uic.column_position)
                                             from all_ind_columns uic
                                            where uic.index_name = ui.index_name
                                              and uic.index_owner = ui.owner)
                                  returning clob)
                                  order by ui.index_name)
                         from all_indexes ui
                        where ui.table_owner = t.owner
                          and ui.table_name = t.table_name
                          and not exists (
                                select 1
                                  from oei_env_sync_object_exclude ex
                                 where (ex.object_type is null or ex.object_type = 'INDEX')
                                   and upper(ui.index_name) like upper(ex.name_like)
                              )),
                   -- Array of triggers defined on the table with trigger text
                   'triggers' value (
                       select json_arrayagg(
                                  json_object(
                                      'trigger_name' value trg.trigger_name,
                                      'trigger_type' value trg.trigger_type,
                                      'triggering_event' value trg.triggering_event,
                                      'status' value trg.status,
                                      'description' value trg.description
                                  returning clob)
                                  order by trg.trigger_name)
                         from all_triggers trg
                        where trg.table_owner = t.owner
                          and trg.table_name = t.table_name
                          and not exists (
                                select 1
                                  from oei_env_sync_object_exclude ex
                                 where (ex.object_type is null or ex.object_type = 'TRIGGER')
                                   and upper(trg.trigger_name) like upper(ex.name_like)
                              ))
                   returning clob)
          into l_json
          from all_tables t
         where t.owner = upper(in_schema_name)
           and t.table_name = upper(in_table_name);
        return l_json;
    exception
        when no_data_found then
            -- Not found: return NULL to signal absence
            return null;
    end f_get_table_json;

    -- Produce JSON describing a single view and its columns
    function f_get_view_json(in_schema_name in t_owner,
                           in_view_name in t_object_name) return clob is
        l_json clob;
    begin
        -- Build a JSON object with view attributes and columns
        select json_object(
                   'schema' value owner,
                   'view_name' value view_name,
                   'read_only' value read_only,
                   'text_length' value text_length,
                   -- omit VIEW TEXT (LONG) for compatibility
                   -- Array of columns exposed by the view
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
            -- Not found: return NULL to signal absence
            return null;
    end f_get_view_json;

    -- Produce JSON containing the DDL for program units
    function f_get_program_unit_json(in_schema_name in t_owner,
                                   in_object_type in t_object_type,
                                   in_object_name in t_object_name) return clob is
        l_ddl clob;
        l_type varchar2(30) := upper(in_object_type);
    begin
        -- Ensure DDL is pretty-printed and terminated
        p_configure_metadata_transform;

        l_ddl := dbms_metadata.get_ddl(object_type => l_type,
                                       name        => upper(in_object_name),
                                       schema      => upper(in_schema_name));

        -- Package the DDL into a JSON payload for consistency
        return json_object(
                   'schema' value upper(in_schema_name),
                   'object_type' value l_type,
                   'object_name' value upper(in_object_name),
                   'ddl' value dbms_lob.substr(l_ddl, 32767, 1)
                   returning clob);
    exception
        when others then
            -- On error (e.g., privileges), emit JSON with error message
            return json_object(
                       'schema' value upper(in_schema_name),
                       'object_type' value l_type,
                       'object_name' value upper(in_object_name),
                       'error' value sqlerrm
                       returning clob);
    end f_get_program_unit_json;

    -- Convenience wrapper to get trigger DDL via program unit helper
    function f_get_trigger_json(in_schema_name in t_owner,
                              in_trigger_name in t_object_name) return clob is
    begin
        return f_get_program_unit_json(in_schema_name, 'TRIGGER', in_trigger_name);
    end f_get_trigger_json;

    -- Produce JSON describing a single index and its columns
    function f_get_index_json(in_schema_name in t_owner,
                            in_index_name in t_object_name) return clob is
        l_json clob;
    begin
        -- Build a JSON object with index attributes and list of columns
        select json_object(
                   'schema' value idx.owner,
                   'index_name' value index_name,
                   'table_name' value table_name,
                   'table_owner' value table_owner,
                   'uniqueness' value uniqueness,
                   'tablespace_name' value tablespace_name,
                   'status' value status,
                   -- Array of indexed columns with position/order
                   'columns' value (
                       select json_arrayagg(
                                  json_object(
                                      'column_name' value column_name,
                                      'column_position' value column_position,
                                      'descend' value descend
                                  returning clob)
                                  order by column_position)
                         from all_ind_columns c
                        where c.index_name = idx.index_name
                          and c.index_owner = idx.owner)
                   returning clob)
          into l_json
          from all_indexes idx
         where idx.owner = upper(in_schema_name)
           and idx.index_name = upper(in_index_name);
        return l_json;
    exception
        when no_data_found then
            -- Not found: return NULL to signal absence
            return null;
    end f_get_index_json;

    -- Internal helper: retrieve raw DDL for a generic object type
    function f_get_object_ddl(in_schema_name in t_owner,
                            in_object_type in t_object_type,
                            in_object_name in t_object_name) return clob is
        l_metadata_type varchar2(30);
    begin
        -- Ensure consistent DDL output
        p_configure_metadata_transform;

        -- DBMS_METADATA expects PACKAGE_BODY for package body type
        l_metadata_type := case upper(in_object_type)
                                when 'PACKAGE BODY' then 'PACKAGE_BODY'
                                when 'MATERIALIZED VIEW' then 'MATERIALIZED_VIEW'
                                when 'MATERIALIZED VIEW LOG' then 'MATERIALIZED_VIEW_LOG'
                                when 'TYPE BODY' then 'TYPE_BODY'
                                else upper(in_object_type)
                            end;

        return dbms_metadata.get_ddl(object_type => l_metadata_type,
                                     name        => upper(in_object_name),
                                     schema      => upper(in_schema_name));
    exception
        when others then
            -- On errors (unsupported or privilege), return NULL
            return null;
    end f_get_object_ddl;

    -- Capture a single object into the persistence table based on its type
    procedure p_capture_object(in_schema_name in t_owner,
                             in_object_type in t_object_type,
                             in_object_name in t_object_name) is
        l_payload clob;
        l_type varchar2(30) := upper(in_object_type);
    begin
        -- Route to the appropriate JSON producer by object type
        case l_type
            when 'SEQUENCE' then
                l_payload := f_get_sequence_json(in_schema_name, in_object_name);
            when 'TABLE' then
                l_payload := f_get_table_json(in_schema_name, in_object_name);
            when 'VIEW' then
                l_payload := f_get_view_json(in_schema_name, in_object_name);
            when 'MATERIALIZED VIEW' then
                l_payload := f_get_program_unit_json(in_schema_name, 'MATERIALIZED_VIEW', in_object_name);
            when 'DIRECTORY' then
                l_payload := f_get_program_unit_json(in_schema_name, 'DIRECTORY', in_object_name);
            when 'PROCEDURE' then
                l_payload := f_get_program_unit_json(in_schema_name, 'PROCEDURE', in_object_name);
            when 'FUNCTION' then
                l_payload := f_get_program_unit_json(in_schema_name, 'FUNCTION', in_object_name);
            when 'PACKAGE' then
                l_payload := f_get_program_unit_json(in_schema_name, 'PACKAGE', in_object_name);
            when 'PACKAGE BODY' then
                l_payload := f_get_program_unit_json(in_schema_name, 'PACKAGE_BODY', in_object_name);
            when 'TYPE' then
                l_payload := f_get_program_unit_json(in_schema_name, 'TYPE', in_object_name);
            when 'TYPE BODY' then
                l_payload := f_get_program_unit_json(in_schema_name, 'TYPE_BODY', in_object_name);
            when 'TRIGGER' then
                l_payload := f_get_trigger_json(in_schema_name, in_object_name);
            when 'INDEX' then
                l_payload := f_get_index_json(in_schema_name, in_object_name);
            when 'JOB' then
                l_payload := f_get_program_unit_json(in_schema_name, 'JOB', in_object_name);
            else
                raise_application_error(-20001, 'Unsupported object type ' || l_type);
        end case;

        -- Persist only when we have a payload
        if l_payload is not null then
            p_upsert_payload(upper(in_schema_name), l_type, upper(in_object_name), l_payload);
        end if;
    end p_capture_object;

    -- Capture all supported objects from a schema in a stable order
    procedure p_capture_schema(in_schema_name in t_owner default user) is
    begin
        -- Iterate over the object list sorted to respect typical dependencies
        for obj in (
            select object_type, object_name
              from all_objects
             where owner = upper(in_schema_name)
               and object_type in (
                   'SEQUENCE',
                    'DIRECTORY',
                    'TYPE',
                    'TYPE BODY',
                    'TABLE',
                    'VIEW',
                    'MATERIALIZED VIEW',
                    'PROCEDURE',
                    'FUNCTION',
                    'PACKAGE',
                    'PACKAGE BODY',
                     'TRIGGER',
                     'INDEX')
               and not exists (
                     select 1
                       from oei_env_sync_object_exclude ex
                      where (ex.object_type is null or ex.object_type = object_type)
                        and upper(object_name) like upper(ex.name_like)
                   )
             order by case object_type
                         when 'SEQUENCE' then 1
                         when 'DIRECTORY' then 2
                         when 'TYPE' then 3
                         when 'TYPE BODY' then 4
                         when 'TABLE' then 5
                         when 'INDEX' then 6
                         when 'TRIGGER' then 7
                         when 'VIEW' then 8
                         when 'MATERIALIZED VIEW' then 9
                         when 'PACKAGE' then 10
                         when 'PACKAGE BODY' then 11
                         when 'PROCEDURE' then 12
                         when 'FUNCTION' then 13
                         else 100
                      end,
                      object_name)
        loop
            p_capture_object(in_schema_name => in_schema_name,
                             in_object_type => obj.object_type,
                             in_object_name => obj.object_name);
        end loop;

        -- Additional objects not listed in ALL_OBJECTS: Directories and Scheduler Jobs
        for d in (
            select directory_name
              from all_directories
             where owner = upper(in_schema_name)
               and not exists (
                     select 1
                       from oei_env_sync_object_exclude ex
                      where (ex.object_type is null or ex.object_type = 'DIRECTORY')
                        and upper(directory_name) like upper(ex.name_like)
                   )
        ) loop
            p_capture_object(in_schema_name => in_schema_name,
                             in_object_type => 'DIRECTORY',
                             in_object_name => d.directory_name);
        end loop;

        for j in (
            select job_name
              from all_scheduler_jobs
             where owner = upper(in_schema_name)
               and not exists (
                     select 1
                       from oei_env_sync_object_exclude ex
                      where (ex.object_type is null or ex.object_type = 'JOB')
                        and upper(job_name) like upper(ex.name_like)
                   )
        ) loop
            p_capture_object(in_schema_name => in_schema_name,
                             in_object_type => 'JOB',
                             in_object_name => j.job_name);
        end loop;
    end p_capture_schema;

    -- Generate a concatenated install script from captured objects
    procedure p_generate_install_script(in_schema_name in t_owner,
                                      in_compare_json in clob default null,
                                      out_script out clob) is
        -- Append a single DDL statement to the output CLOB with proper separators
        procedure p_append_ddl(in_ddl in clob, in_type in t_object_type) is
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
                -- Add SQL*Plus style delimiter after program unit DDL
                dbms_lob.writeappend(out_script, 2, '/' || chr(10));
            end if;

            dbms_lob.writeappend(out_script, 1, chr(10));
        end p_append_ddl;

        -- Append object base DDL and dependent DDL (grants, synonyms) when available
        procedure p_append_object_with_dependents(in_schema in t_owner,
                                                  in_type   in t_object_type,
                                                  in_name   in t_object_name) is
            l_base  clob;
            l_dep   clob;
        begin
            l_base := f_get_object_ddl(in_schema, in_type, in_name);
            p_append_ddl(l_base, in_type);
            -- Object grants
            l_dep := f_get_dependent_ddl(in_schema, in_type, in_name, 'OBJECT_GRANT');
            if l_dep is not null and dbms_lob.getlength(l_dep) > 0 then
                p_append_ddl(l_dep, in_type);
            end if;
            -- Synonyms
            l_dep := f_get_dependent_ddl(in_schema, in_type, in_name, 'SYNONYM');
            if l_dep is not null and dbms_lob.getlength(l_dep) > 0 then
                p_append_ddl(l_dep, in_type);
            end if;
        end p_append_object_with_dependents;

        -- When a compare JSON is provided, emit only objects not present in the JSON
        procedure p_process_missing_objects is
        begin
            for obj in (
                select so.object_type, so.object_name, so.ddl_hash
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
                -- Skip unchanged objects when current hash equals stored hash
                declare
                    l_current_hash varchar2(64);
                    l_ddl clob;
                begin
                    l_current_hash := f_compute_object_hash(in_schema_name, obj.object_type, obj.object_name);
                    if l_current_hash is not null and obj.ddl_hash is not null and l_current_hash = obj.ddl_hash then
                        null; -- unchanged, skip
                    else
                        p_append_object_with_dependents(in_schema_name, obj.object_type, obj.object_name);
                    end if;
                end;
            end loop;
        end p_process_missing_objects;

        -- When a compare JSON is provided, emit ALTERs for existing objects when changed
        procedure p_process_existing_objects is
        begin
            for obj in (
                select cmp.schema_name as tgt_schema,
                       so.object_type,
                       so.object_name,
                       so.ddl_hash
                  from oei_env_sync_schema_objects so
                  join (
                        select x.schema_name, x.object_type, x.object_name
                          from json_table(in_compare_json format json, '$[*]'
                               columns (
                                   schema_name varchar2(128) path '$.schema_name',
                                   object_type varchar2(30)  path '$.object_type',
                                   object_name varchar2(128) path '$.object_name'
                               )) x
                       ) cmp
                    on upper(cmp.object_type) = so.object_type
                   and upper(cmp.object_name) = so.object_name
                 where so.schema_name = upper(in_schema_name)
                 order by so.object_type, so.object_name)
            loop
                declare
                    l_mode varchar2(20) := f_get_type_mode(obj.object_type);
                    l_current_hash varchar2(64);
                    l_alter clob;
                    l_ddl clob;
                begin
                    -- Skip when unchanged by hash
                    l_current_hash := f_compute_object_hash(in_schema_name, obj.object_type, obj.object_name);
                    if l_current_hash is not null and obj.ddl_hash is not null and l_current_hash = obj.ddl_hash then
                        null;
                    else
                        if l_mode = 'DIFF' and obj.tgt_schema is not null then
                            l_alter := f_diff_object(in_src_schema   => in_schema_name,
                                                     in_tgt_schema   => obj.tgt_schema,
                                                     in_object_type  => obj.object_type,
                                                     in_object_name  => obj.object_name);
                        end if;

                        if l_alter is not null and dbms_lob.getlength(l_alter) > 0 then
                            p_append_ddl(l_alter, obj.object_type);
                        else
                            -- Fallback to full DDL
                            l_ddl := f_get_object_ddl(in_schema_name => in_schema_name,
                                                      in_object_type => obj.object_type,
                                                      in_object_name => obj.object_name);
                            p_append_ddl(l_ddl, obj.object_type);
                        end if;
                    end if;
                end;
            end loop;
        end p_process_existing_objects;

    begin
        -- Create a temporary CLOB to accumulate the BODY of the script
        dbms_lob.createtemporary(out_script, true);

        if in_compare_json is not null and dbms_lob.getlength(in_compare_json) > 0 then
            -- First, update existing target objects (attempt DIFF), then create missing
            p_process_existing_objects;
            p_process_missing_objects;
        else
            -- No compare payload: export all captured objects for the schema
            for obj in (
                select so.object_type, so.object_name, so.ddl_hash
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
                -- Skip unchanged objects when current hash equals stored hash
                declare
                    l_current_hash varchar2(64);
                    l_ddl clob;
                begin
                    l_current_hash := f_compute_object_hash(in_schema_name, obj.object_type, obj.object_name);
                    if l_current_hash is not null and obj.ddl_hash is not null and l_current_hash = obj.ddl_hash then
                        null; -- unchanged, skip
                    else
                        p_append_object_with_dependents(in_schema_name, obj.object_type, obj.object_name);
                    end if;
                end;
            end loop;
        end if;

        -- If nothing was appended, free the LOB and return NULL
        if dbms_lob.getlength(out_script) = 0 then
            dbms_lob.freetemporary(out_script);
            out_script := null;
        else
            -- Prepend header and append footer to produce a robust runnable script
            declare
                l_final  clob;
                l_line   varchar2(4000);
            begin
                dbms_lob.createtemporary(l_final, true);

                -- Header
                l_line := 'set define off';
                dbms_lob.writeappend(l_final, length(l_line||chr(10)), l_line||chr(10));
                l_line := 'whenever sqlerror exit failure';
                dbms_lob.writeappend(l_final, length(l_line||chr(10)), l_line||chr(10));
                l_line := 'alter session set current_schema = ' || upper(in_schema_name) || ';';
                dbms_lob.writeappend(l_final, length(l_line||chr(10)||chr(10)), l_line||chr(10)||chr(10));

                -- Body
                dbms_lob.append(l_final, out_script);

                -- Seed config data (if a target schema is provided via compare JSON)
                declare
                    l_target_schema varchar2(128);
                    l_seeds clob;
                begin
                    if in_compare_json is not null and dbms_lob.getlength(in_compare_json) > 0 then
                        begin
                            select max(schema_name)
                              into l_target_schema
                              from json_table(in_compare_json format json, '$[*]'
                                   columns (schema_name varchar2(128) path '$.schema_name'))
                             where rownum = 1;
                        exception when others then l_target_schema := null; end;
                    end if;
                    if l_target_schema is not null then
                        l_seeds := f_generate_seed_merges(in_schema_name, l_target_schema);
                        if l_seeds is not null then
                            dbms_lob.writeappend(l_final, 1, chr(10));
                            l_line := '-- Data seeds (MERGE) from '||upper(in_schema_name)||' to '||upper(l_target_schema);
                            dbms_lob.writeappend(l_final, length(l_line||chr(10)), l_line||chr(10));
                            dbms_lob.append(l_final, l_seeds);
                        end if;
                    end if;
                end;

                -- Footer: optional recompile step
                dbms_lob.writeappend(l_final, 1, chr(10));
                dbms_lob.writeappend(l_final, 1, chr(10));
                l_line := '-- Optional: recompile invalid objects';
                dbms_lob.writeappend(l_final, length(l_line||chr(10)), l_line||chr(10));
                l_line := 'begin utl_recomp.recomp_serial(schema => '''||upper(in_schema_name)||'''); end;';
                dbms_lob.writeappend(l_final, length(l_line||chr(10)), l_line||chr(10));
                dbms_lob.writeappend(l_final, 2, '/'||chr(10));

                -- Replace out_script with final
                dbms_lob.freetemporary(out_script);
                out_script := l_final;
            end;
        end if;
    exception
        when others then
            -- Ensure we don't leak temporary LOBs on error
            if dbms_lob.istemporary(out_script) = 1 then
                dbms_lob.freetemporary(out_script);
            end if;
            out_script := null;
            raise;
    end p_generate_install_script;

    -- Return dependent DDL as a CLOB for the given dep type (OBJECT_GRANT, SYNONYM, etc.)
    function f_get_dependent_ddl(in_schema_name in t_owner,
                                 in_object_type in t_object_type,
                                 in_object_name in t_object_name,
                                 in_dep_type    in varchar2) return clob is
        l_meta_type varchar2(30);
    begin
        l_meta_type := case upper(in_object_type)
                           when 'PACKAGE BODY' then 'PACKAGE_BODY'
                           when 'MATERIALIZED VIEW' then 'MATERIALIZED_VIEW'
                           when 'MATERIALIZED VIEW LOG' then 'MATERIALIZED_VIEW_LOG'
                           when 'TYPE BODY' then 'TYPE_BODY'
                           else upper(in_object_type)
                       end;
        -- Use dynamic block to avoid compile-time signature mismatch across versions
        declare
            l_out clob;
        begin
            execute immediate 'begin :o := dbms_metadata.get_dependent_ddl(:t, :n, :s); end;'
               using out l_out, in upper(in_dep_type), in upper(in_object_name), in upper(in_schema_name);
            return l_out;
        exception when others then
            return null;
        end;
    end f_get_dependent_ddl;

    -- Generate MERGE statements for configured seed tables from source to target
    function f_generate_seed_merges(in_src_schema in t_owner,
                                    in_tgt_schema in t_owner) return clob is
        l_out      clob;
    begin
        dbms_lob.createtemporary(l_out, true);
        for t in (
            select upper(table_name) table_name,
                   where_clause,
                   enabled
              from oei_env_sync_seed_tables
             where enabled = 'Y'
        ) loop
            declare
                l_pk_cols      varchar2(4000);
                l_all_cols     varchar2(4000);
                l_non_pk       varchar2(4000);
                l_sql          clob;
                l_pk_join      varchar2(32767);
                l_update_set   varchar2(32767);
                l_values_list  varchar2(32767);
            begin
                -- PK columns list
                select listagg(cc.column_name, ',') within group(order by cc.position)
                  into l_pk_cols
                  from all_constraints c
                  join all_cons_columns cc
                    on cc.owner = c.owner and cc.table_name = c.table_name and cc.constraint_name = c.constraint_name
                 where c.owner = upper(in_src_schema)
                   and c.table_name = t.table_name
                   and c.constraint_type = 'P';

                -- All columns
                select listagg(column_name, ',') within group(order by column_id)
                  into l_all_cols
                  from all_tab_columns
                 where owner = upper(in_src_schema)
                   and table_name = t.table_name
                   and hidden_column = 'NO';

                -- Non-PK columns
                select listagg(column_name, ',') within group(order by column_id)
                  into l_non_pk
                  from all_tab_columns
                 where owner = upper(in_src_schema)
                   and table_name = t.table_name
                   and hidden_column = 'NO'
                   and (l_pk_cols is null or instr(','||l_pk_cols||',', ','||column_name||',') = 0);

                if l_all_cols is null or l_pk_cols is null then
                    continue;
                end if;

                -- Build join predicate for PK columns
                select listagg('tgt.'||c||'=src.'||c, ' and ')
                  into l_pk_join
                  from (
                        select regexp_substr(l_pk_cols, '[^,]+', 1, level) c
                          from dual
                        connect by regexp_substr(l_pk_cols, '[^,]+', 1, level) is not null
                       );

                -- Build update-set list for non-PK columns
                if l_non_pk is not null then
                    select listagg('tgt.'||c||'=src.'||c, ',')
                      into l_update_set
                      from (
                            select regexp_substr(l_non_pk, '[^,]+', 1, level) c
                              from dual
                            connect by regexp_substr(l_non_pk, '[^,]+', 1, level) is not null
                           );
                else
                    l_update_set := null;
                end if;

                -- Build values list for insert
                select listagg('src.'||c, ',')
                  into l_values_list
                  from (
                        select regexp_substr(l_all_cols, '[^,]+', 1, level) c
                          from dual
                        connect by regexp_substr(l_all_cols, '[^,]+', 1, level) is not null
                       );

                -- Assemble MERGE statement
                l_sql := 'merge into '||upper(in_tgt_schema)||'.'||t.table_name||' tgt'||chr(10)||
                         'using ('||chr(10)||
                         '  select '||l_all_cols||' from '||upper(in_src_schema)||'.'||t.table_name||
                         case when t.where_clause is not null then ' where '||t.where_clause else '' end||chr(10)||
                         ') src'||chr(10)||
                         'on ('||l_pk_join||')'||chr(10);

                if l_update_set is not null then
                    l_sql := l_sql || 'when matched then update set '||l_update_set||chr(10);
                end if;

                l_sql := l_sql || 'when not matched then insert ('||l_all_cols||') values ('||l_values_list||');'||chr(10);

                dbms_lob.append(l_out, l_sql);
                dbms_lob.writeappend(l_out, 2, '/'||chr(10));
                dbms_lob.writeappend(l_out, 1, chr(10));
            exception
                when others then null; -- skip table if metadata is incomplete
            end;
        end loop;
        if dbms_lob.getlength(l_out) = 0 then
            dbms_lob.freetemporary(l_out);
            return null;
        end if;
        return l_out;
    end f_generate_seed_merges;

    -- Export baseline with hashes for all supported objects in a schema
    function f_export_baseline(in_schema_name in t_owner) return clob is
        l_json clob;
    begin
        select json_arrayagg(
                   json_object(
                       'schema_name' value upper(in_schema_name),
                       'object_type' value object_type,
                       'object_name' value object_name,
                       'ddl_hash'    value f_compute_object_hash(in_schema_name, object_type, object_name)
                       returning clob)
                   order by object_type, object_name)
          into l_json
          from (
                select object_type, object_name
                  from all_objects
                 where owner = upper(in_schema_name)
                   and object_type in (
                        'SEQUENCE','DIRECTORY','TYPE','TYPE BODY','TABLE','VIEW','MATERIALIZED VIEW',
                        'PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','TRIGGER','INDEX')
                   and not exists (
                         select 1 from oei_env_sync_object_exclude ex
                          where (ex.object_type is null or ex.object_type = object_type)
                            and upper(object_name) like upper(ex.name_like)
                       )
               );
        return l_json;
    exception when others then
        return null;
    end f_export_baseline;

    -- Compare a DEV baseline JSON against a target schema by computing target hashes
    function f_compare_baseline_to_schema(in_target_schema in t_owner,
                                          in_baseline_json in clob) return clob is
        l_json clob;
    begin
        with base as (
            select upper(nvl(b.schema_name, in_target_schema)) dev_schema,
                   upper(b.object_type) object_type,
                   upper(b.object_name) object_name,
                   b.ddl_hash dev_hash
              from json_table(in_baseline_json format json, '$[*]'
                   columns (
                     schema_name varchar2(128) path '$.schema_name',
                     object_type varchar2(30)  path '$.object_type',
                     object_name varchar2(128) path '$.object_name',
                     ddl_hash    varchar2(64)  path '$.ddl_hash'
                   )) b
        ), tgt as (
            select object_type, object_name,
                   f_compute_object_hash(in_target_schema, object_type, object_name) as tgt_hash
              from (
                    select object_type, object_name
                      from all_objects
                     where owner = upper(in_target_schema)
                   )
        ), joined as (
            select b.object_type,
                   b.object_name,
                   b.dev_hash,
                   t.tgt_hash,
                   case when t.tgt_hash is null then 'MISSING'
                        when b.dev_hash is null or b.dev_hash != t.tgt_hash then 'MODIFIED'
                        else 'UNCHANGED'
                   end change_type
              from base b
              left join tgt t
                on t.object_type = b.object_type
               and t.object_name = b.object_name
        )
        select json_arrayagg(
                   json_object(
                       'schema_name' value upper(in_target_schema),
                       'object_type' value object_type,
                       'object_name' value object_name,
                       'change_type' value change_type,
                       'dev_hash'    value dev_hash,
                       'tgt_hash'    value tgt_hash
                       returning clob)
                   order by change_type, object_type, object_name)
          into l_json
          from joined;
        return l_json;
    exception when others then
        return null;
    end f_compare_baseline_to_schema;

    -- Generate CREATE OR REPLACE for code objects from a JSON list (skip tables/indexes)
    procedure p_generate_replace_script_for(in_schema_name in t_owner,
                                            in_objects_json in clob,
                                            out_script out clob) is
    begin
        dbms_lob.createtemporary(out_script, true);
        for r in (
            select upper(nvl(o.schema_name, in_schema_name)) schema_name,
                   upper(o.object_type) object_type,
                   upper(o.object_name) object_name
              from json_table(in_objects_json format json, '$[*]'
                   columns (
                     schema_name varchar2(128) path '$.schema_name',
                     object_type varchar2(30)  path '$.object_type',
                     object_name varchar2(128) path '$.object_name'
                   )) o
        ) loop
            if r.object_type in ('PACKAGE','PACKAGE BODY','PROCEDURE','FUNCTION','TRIGGER','VIEW','MATERIALIZED VIEW','TYPE','TYPE BODY','JOB','DIRECTORY') then
                declare
                    l_ddl clob;
                begin
                    l_ddl := f_get_object_ddl(r.schema_name, r.object_type, r.object_name);
                    if l_ddl is not null then
                        if dbms_lob.getlength(out_script) > 0 then
                            dbms_lob.writeappend(out_script, 1, chr(10));
                        end if;
                        dbms_lob.append(out_script, l_ddl);
                        dbms_lob.writeappend(out_script, 1, chr(10));
                        if r.object_type in ('PACKAGE','PACKAGE BODY','PROCEDURE','FUNCTION','TRIGGER') then
                            dbms_lob.writeappend(out_script, 2, '/'||chr(10));
                        end if;
                        dbms_lob.writeappend(out_script, 1, chr(10));
                    end if;
                end;
            else
                null; -- skip TABLE/INDEX and structural types not safe for replace across DBs
            end if;
        end loop;
        if dbms_lob.getlength(out_script) = 0 then
            dbms_lob.freetemporary(out_script);
            out_script := null;
        end if;
    exception when others then
        if dbms_lob.istemporary(out_script) = 1 then
            dbms_lob.freetemporary(out_script);
        end if;
        out_script := null;
        raise;
    end p_generate_replace_script_for;

end pck_oei_env_sync;
/
 
-- Display compilation errors (for SQL*Plus/SQLcl usage)
show errors package pck_oei_env_sync;
show errors package body pck_oei_env_sync;
