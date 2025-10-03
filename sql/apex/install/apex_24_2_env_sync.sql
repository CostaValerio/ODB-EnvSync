prompt ================================================================================
prompt APEX 24.2 Install: Env Sync Capture Pages
prompt ================================================================================
prompt Parameters required: WORKSPACE, APP_ID
prompt Example: 
prompt   define WORKSPACE = MY_WORKSPACE
prompt   define APP_ID    = 123

-- Ensure required subs are defined
column WORKSPACE new_value WORKSPACE
column APP_ID    new_value APP_ID

prompt Using workspace: &WORKSPACE.
prompt Target application: &APP_ID.

declare
  l_ws_id number;
begin
  -- Switch to target workspace
  l_ws_id := apex_util.find_security_group_id(p_workspace => '&WORKSPACE.');
  if l_ws_id is null then
    raise_application_error(-20000, 'Workspace not found: &WORKSPACE.');
  end if;
  apex_util.set_security_group_id(l_ws_id);
end;
/

--------------------------------------------------------------------------------
-- Authorization Schemes (DB roles based)
--------------------------------------------------------------------------------
begin
  apex_application_api.create_security_scheme(
    p_id                 => apex_application_api.id(9001),
    p_flow_id            => &APP_ID.,
    p_name               => 'Can Capture',
    p_scheme_type        => 'NATIVE_FUNCTION_BODY',
    p_attribute_01       => q'[return exists (select 1 from session_roles where role = 'OEI_ENV_CAPTURE_ROLE');]',
    p_error_message      => 'Not authorized to capture.');

  apex_application_api.create_security_scheme(
    p_id                 => apex_application_api.id(9002),
    p_flow_id            => &APP_ID.,
    p_name               => 'Can Release',
    p_scheme_type        => 'NATIVE_FUNCTION_BODY',
    p_attribute_01       => q'[return exists (select 1 from session_roles where role = 'OEI_ENV_RELEASE_ROLE');]',
    p_error_message      => 'Not authorized to release.');
end;
/

--------------------------------------------------------------------------------
-- Helper: safely remove a page if it exists
--------------------------------------------------------------------------------
declare
  procedure drop_page(p_app_id in number, p_page_id in number) is
  begin
    apex_application_api.remove_page(
      p_flow_id => p_app_id,
      p_page_id => p_page_id);
  exception
    when others then null; -- ignore if page does not exist
  end;
begin
  drop_page(&APP_ID., 1);
  drop_page(&APP_ID., 2);
  drop_page(&APP_ID., 3);
  drop_page(&APP_ID., 4);
  drop_page(&APP_ID., 5);
  drop_page(&APP_ID., 6);
  drop_page(&APP_ID., 7);
  drop_page(&APP_ID., 8);
end;
/

--------------------------------------------------------------------------------
-- Page 1: Capture Schema
--------------------------------------------------------------------------------
begin
  -- Create page
  apex_application_api.create_page(
    p_id                => 1,
    p_flow_id           => &APP_ID.,
    p_name              => 'Capture Schema',
    p_step_title        => 'Capture Schema',
    p_warn_on_unsaved_changes => 'Y',
    p_autocomplete_on_off     => 'ON');

  -- Region
  apex_application_api.create_page_plug(
    p_id                 => apex_application_api.id(1),
    p_flow_id            => &APP_ID.,
    p_page_id            => 1,
    p_plug_name          => 'Capture Schema',
    p_region_template_options => '#DEFAULT#',
    p_plug_display_sequence  => 10,
    p_plug_source_type       => 'NATIVE_STATIC');

  -- Items
  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(2),
    p_flow_id            => &APP_ID.,
    p_page_id            => 1,
    p_name               => 'P1_SCHEMA_NAME',
    p_item_sequence      => 10,
    p_item_plug_id       => apex_application_api.id(1),
    p_prompt             => 'Schema Name',
    p_display_as         => 'NATIVE_TEXT_FIELD',
    p_cSize              => 30,
    p_is_required        => 'Y',
    p_source_type        => 'STATIC',
    p_source             => 'USER');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(3),
    p_flow_id            => &APP_ID.,
    p_page_id            => 1,
    p_name               => 'P1_MESSAGE',
    p_item_sequence      => 90,
    p_item_plug_id       => apex_application_api.id(1),
    p_prompt             => 'Message',
    p_display_as         => 'NATIVE_DISPLAY_ONLY');

  -- Button
  apex_application_api.create_page_button(
    p_id                 => apex_application_api.id(4),
    p_flow_id            => &APP_ID.,
    p_page_id            => 1,
    p_button_sequence    => 20,
    p_button_plug_id     => apex_application_api.id(1),
    p_button_name        => 'P1_CAPTURE',
    p_button_action      => 'SUBMIT',
    p_button_is_hot      => 'Y',
    p_button_image_alt   => 'Capture');

  -- Process
  apex_application_api.create_page_process(
    p_id                 => apex_application_api.id(5),
    p_flow_id            => &APP_ID.,
    p_page_id            => 1,
    p_process_sequence   => 10,
    p_process_point      => 'AFTER_SUBMIT',
    p_process_type       => 'NATIVE_PLSQL',
    p_process_name       => 'PRC_CAPTURE_SCHEMA',
    p_process_sql_clob   => q'[
declare
  l_schema varchar2(128) := coalesce(:P1_SCHEMA_NAME, user);
begin
  oei_env_sync_capture_pkg.p_capture_schema(l_schema);
  :P1_MESSAGE := 'Capture completed for ' || upper(l_schema);
exception
  when others then
    :P1_MESSAGE := 'Error: ' || sqlerrm;
    raise;
end;]');
end;
/

--------------------------------------------------------------------------------
-- Page 2: Capture Object
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 2,
    p_flow_id           => &APP_ID.,
    p_name              => 'Capture Object',
    p_step_title        => 'Capture Object',
    p_warn_on_unsaved_changes => 'Y',
    p_autocomplete_on_off     => 'ON');

  apex_application_api.create_page_plug(
    p_id                 => apex_application_api.id(20),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_plug_name          => 'Parameters',
    p_region_template_options => '#DEFAULT#',
    p_plug_display_sequence  => 10,
    p_plug_source_type       => 'NATIVE_STATIC');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(21),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_name               => 'P2_SCHEMA_NAME',
    p_item_sequence      => 10,
    p_item_plug_id       => apex_application_api.id(20),
    p_prompt             => 'Schema Name',
    p_display_as         => 'NATIVE_TEXT_FIELD',
    p_cSize              => 30,
    p_is_required        => 'Y',
    p_source_type        => 'STATIC',
    p_source             => 'USER');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(22),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_name               => 'P2_OBJECT_TYPE',
    p_item_sequence      => 20,
    p_item_plug_id       => apex_application_api.id(20),
    p_prompt             => 'Object Type',
    p_display_as         => 'NATIVE_SELECT_LIST',
    p_lov                => 'STATIC2:SEQUENCE;SEQUENCE,TABLE;TABLE,VIEW;VIEW,PROCEDURE;PROCEDURE,FUNCTION;FUNCTION,PACKAGE;PACKAGE,PACKAGE BODY;PACKAGE BODY,TRIGGER;TRIGGER,INDEX;INDEX',
    p_is_required        => 'Y');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(23),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_name               => 'P2_OBJECT_NAME',
    p_item_sequence      => 30,
    p_item_plug_id       => apex_application_api.id(20),
    p_prompt             => 'Object Name',
    p_display_as         => 'NATIVE_TEXT_FIELD',
    p_cSize              => 40,
    p_is_required        => 'Y');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(24),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_name               => 'P2_MESSAGE',
    p_item_sequence      => 90,
    p_item_plug_id       => apex_application_api.id(20),
    p_prompt             => 'Message',
    p_display_as         => 'NATIVE_DISPLAY_ONLY');

  apex_application_api.create_page_button(
    p_id                 => apex_application_api.id(25),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_button_sequence    => 40,
    p_button_plug_id     => apex_application_api.id(20),
    p_button_name        => 'P2_CAPTURE',
    p_button_action      => 'SUBMIT',
    p_button_is_hot      => 'Y',
    p_button_image_alt   => 'Capture');

  apex_application_api.create_page_process(
    p_id                 => apex_application_api.id(26),
    p_flow_id            => &APP_ID.,
    p_page_id            => 2,
    p_process_sequence   => 10,
    p_process_point      => 'AFTER_SUBMIT',
    p_process_type       => 'NATIVE_PLSQL',
    p_process_name       => 'PRC_CAPTURE_OBJECT',
    p_process_sql_clob   => q'[
declare
  l_schema varchar2(128) := coalesce(:P2_SCHEMA_NAME, user);
  l_type   varchar2(30)  := :P2_OBJECT_TYPE;
  l_name   varchar2(128) := :P2_OBJECT_NAME;
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
end;]');
end;
/

--------------------------------------------------------------------------------
-- Page 3: Generate Install Script
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 3,
    p_flow_id           => &APP_ID.,
    p_name              => 'Generate Install Script',
    p_step_title        => 'Generate Install Script',
    p_warn_on_unsaved_changes => 'Y',
    p_autocomplete_on_off     => 'ON');

  apex_application_api.create_page_plug(
    p_id                 => apex_application_api.id(30),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_plug_name          => 'Parameters',
    p_region_template_options => '#DEFAULT#',
    p_plug_display_sequence  => 10,
    p_plug_source_type       => 'NATIVE_STATIC');

  apex_application_api.create_page_plug(
    p_id                 => apex_application_api.id(31),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_plug_name          => 'Script',
    p_region_template_options => '#DEFAULT#',
    p_plug_display_sequence  => 20,
    p_plug_source_type       => 'NATIVE_STATIC');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(32),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_name               => 'P3_SCHEMA_NAME',
    p_item_sequence      => 10,
    p_item_plug_id       => apex_application_api.id(30),
    p_prompt             => 'Schema Name',
    p_display_as         => 'NATIVE_TEXT_FIELD',
    p_cSize              => 30,
    p_is_required        => 'Y',
    p_source_type        => 'STATIC',
    p_source             => 'USER');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(33),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_name               => 'P3_COMPARE_JSON',
    p_item_sequence      => 20,
    p_item_plug_id       => apex_application_api.id(30),
    p_prompt             => 'Compare JSON (optional)',
    p_display_as         => 'NATIVE_TEXTAREA',
    p_cHeight            => 10,
    p_cSize              => 80);

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(34),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_name               => 'P3_SCRIPT',
    p_item_sequence      => 10,
    p_item_plug_id       => apex_application_api.id(31),
    p_prompt             => 'Script',
    p_display_as         => 'NATIVE_DISPLAY_ONLY',
    p_attribute_01       => 'Y' -- escape special characters: Y/N; keep Y to avoid HTML issues
  );

  apex_application_api.create_page_button(
    p_id                 => apex_application_api.id(35),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_button_sequence    => 30,
    p_button_plug_id     => apex_application_api.id(30),
    p_button_name        => 'P3_GENERATE',
    p_button_action      => 'SUBMIT',
    p_button_is_hot      => 'Y',
    p_button_image_alt   => 'Generate');

  apex_application_api.create_page_process(
    p_id                 => apex_application_api.id(36),
    p_flow_id            => &APP_ID.,
    p_page_id            => 3,
    p_process_sequence   => 10,
    p_process_point      => 'AFTER_SUBMIT',
    p_process_type       => 'NATIVE_PLSQL',
    p_process_name       => 'PRC_GENERATE_SCRIPT',
    p_process_sql_clob   => q'[
declare
  l_script clob;
  l_schema varchar2(128) := coalesce(:P3_SCHEMA_NAME, user);
begin
  oei_env_sync_capture_pkg.p_generate_install_script(
    in_schema_name   => l_schema,
    in_compare_json  => :P3_COMPARE_JSON,
    out_script       => l_script
  );

  :P3_SCRIPT := l_script;

  if l_script is null then
    apex_application.g_print_success_message := 'No statements to generate.';
  else
    apex_application.g_print_success_message := 'Script generated.';
  end if;
exception
  when others then
    :P3_SCRIPT := 'Error: ' || sqlerrm;
    raise;
end;]');
end;
/

--------------------------------------------------------------------------------
-- Page 4: Captured Objects Report
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 4,
    p_flow_id           => &APP_ID.,
    p_name              => 'Captured Objects',
    p_step_title        => 'Captured Objects',
    p_warn_on_unsaved_changes => 'N',
    p_autocomplete_on_off     => 'ON');

  apex_application_api.create_page_plug(
    p_id                 => apex_application_api.id(40),
    p_flow_id            => &APP_ID.,
    p_page_id            => 4,
    p_plug_name          => 'Captured Objects',
    p_region_template_options => '#DEFAULT#',
    p_plug_display_sequence  => 10,
    p_plug_source_type       => 'NATIVE_IR',
    p_plug_source            => q'[
select
  schema_name,
  object_type,
  object_name,
  captured_on,
  dbms_lob.getlength(payload) as payload_length
from oei_env_sync_schema_objects
where (:P4_SCHEMA_NAME is null or schema_name = upper(:P4_SCHEMA_NAME))
order by object_type, object_name]');

  apex_application_api.create_page_item(
    p_id                 => apex_application_api.id(41),
    p_flow_id            => &APP_ID.,
    p_page_id            => 4,
    p_name               => 'P4_SCHEMA_NAME',
    p_item_sequence      => 5,
    p_item_plug_id       => apex_application_api.id(40),
    p_prompt             => 'Schema Name',
    p_display_as         => 'NATIVE_TEXT_FIELD',
    p_cSize              => 30);
end;
/

prompt Done. Review pages 1-4 in application &APP_ID. within workspace &WORKSPACE.

--------------------------------------------------------------------------------
-- Page 5: Upload Snapshot
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 5,
    p_flow_id           => &APP_ID.,
    p_name              => 'Upload Snapshot',
    p_step_title        => 'Upload Snapshot',
    p_warn_on_unsaved_changes => 'Y');

  apex_application_api.create_page_plug(
    p_id                 => apex_application_api.id(50),
    p_flow_id            => &APP_ID.,
    p_page_id            => 5,
    p_plug_name          => 'Upload',
    p_plug_display_sequence  => 10,
    p_plug_source_type       => 'NATIVE_STATIC');

  apex_application_api.create_page_item(
    p_id => apex_application_api.id(51), p_flow_id=>&APP_ID., p_page_id=>5,
    p_name=>'P5_SNAPSHOT_NAME', p_item_plug_id=>apex_application_api.id(50), p_item_sequence=>10,
    p_prompt=>'Snapshot Name', p_display_as=>'NATIVE_TEXT_FIELD', p_is_required=>'Y');

  apex_application_api.create_page_item(
    p_id => apex_application_api.id(52), p_flow_id=>&APP_ID., p_page_id=>5,
    p_name=>'P5_TARGET_SCHEMA', p_item_plug_id=>apex_application_api.id(50), p_item_sequence=>20,
    p_prompt=>'Target Schema', p_display_as=>'NATIVE_TEXT_FIELD');

  apex_application_api.create_page_item(
    p_id => apex_application_api.id(53), p_flow_id=>&APP_ID., p_page_id=>5,
    p_name=>'P5_SOURCE_ENV', p_item_plug_id=>apex_application_api.id(50), p_item_sequence=>30,
    p_prompt=>'Source Env', p_display_as=>'NATIVE_TEXT_FIELD');

  apex_application_api.create_page_item(
    p_id => apex_application_api.id(54), p_flow_id=>&APP_ID., p_page_id=>5,
    p_name=>'P5_PAYLOAD', p_item_plug_id=>apex_application_api.id(50), p_item_sequence=>40,
    p_prompt=>'Payload (JSON)', p_display_as=>'NATIVE_TEXTAREA', p_cHeight=>15, p_cSize=>100);

  apex_application_api.create_page_item(
    p_id => apex_application_api.id(55), p_flow_id=>&APP_ID., p_page_id=>5,
    p_name=>'P5_MESSAGE', p_item_plug_id=>apex_application_api.id(50), p_item_sequence=>90,
    p_prompt=>'Message', p_display_as=>'NATIVE_DISPLAY_ONLY');

  apex_application_api.create_page_button(
    p_id=>apex_application_api.id(56), p_flow_id=>&APP_ID., p_page_id=>5,
    p_button_plug_id=>apex_application_api.id(50), p_button_sequence=>50,
    p_button_name=>'P5_UPLOAD', p_button_action=>'SUBMIT', p_button_is_hot=>'Y', p_button_image_alt=>'Upload');

  apex_application_api.create_page_process(
    p_id=>apex_application_api.id(57), p_flow_id=>&APP_ID., p_page_id=>5,
    p_process_sequence=>10, p_process_point=>'AFTER_SUBMIT', p_process_type=>'NATIVE_PLSQL',
    p_process_name=>'PRC_UPLOAD_SNAPSHOT', p_process_sql_clob=>q'[
declare
  l_dummy number;
begin
  select 1 into l_dummy
    from json_table(:P5_PAYLOAD format json, '$[0]'
           columns (object_type varchar2(30) path '$.object_type', object_name varchar2(128) path '$.object_name'));
  insert into oei_env_sync_snapshots (snapshot_name, target_schema, source_env, payload)
  values (:P5_SNAPSHOT_NAME, :P5_TARGET_SCHEMA, :P5_SOURCE_ENV, :P5_PAYLOAD);
  :P5_MESSAGE := 'Snapshot uploaded: ' || :P5_SNAPSHOT_NAME;
exception when others then
  :P5_MESSAGE := 'Error: ' || sqlerrm; raise;
end;]');
end;
/

--------------------------------------------------------------------------------
-- Page 6: Changes Review
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 6,
    p_flow_id           => &APP_ID.,
    p_name              => 'Changes Review',
    p_step_title        => 'Changes Review',
    p_warn_on_unsaved_changes => 'N');

  apex_application_api.create_page_plug(
    p_id=>apex_application_api.id(60), p_flow_id=>&APP_ID., p_page_id=>6,
    p_plug_name=>'Parameters', p_plug_display_sequence=>10, p_plug_source_type=>'NATIVE_STATIC');

  apex_application_api.create_page_plug(
    p_id=>apex_application_api.id(61), p_flow_id=>&APP_ID., p_page_id=>6,
    p_plug_name=>'Changes', p_plug_display_sequence=>20, p_plug_source_type=>'NATIVE_IR',
    p_plug_source=>q'[
with data as (
  select oei_env_sync_capture_pkg.f_list_changes(:P6_SCHEMA_NAME,
          (select payload from oei_env_sync_snapshots where snapshot_id = :P6_SNAPSHOT_ID)) j from dual
)
select t.change_type, t.object_type, t.object_name
  from data d,
       json_table(d.j, '$[*]'
         columns (
           change_type varchar2(20) path '$.change_type',
           object_type varchar2(30) path '$.object_type',
           object_name varchar2(128) path '$.object_name'
         )) t
 where :P6_FILTER is null or t.change_type = :P6_FILTER
 order by t.change_type, t.object_type, t.object_name]');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(62), p_flow_id=>&APP_ID., p_page_id=>6,
    p_name=>'P6_SCHEMA_NAME', p_item_plug_id=>apex_application_api.id(60), p_item_sequence=>10,
    p_prompt=>'Source Schema', p_display_as=>'NATIVE_TEXT_FIELD', p_is_required=>'Y');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(63), p_flow_id=>&APP_ID., p_page_id=>6,
    p_name=>'P6_SNAPSHOT_ID', p_item_plug_id=>apex_application_api.id(60), p_item_sequence=>20,
    p_prompt=>'Snapshot', p_display_as=>'NATIVE_SELECT_LIST',
    p_lov=>q'[select snapshot_name||' ('||created_by||')' d, snapshot_id r from oei_env_sync_snapshots order by created_on desc]');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(64), p_flow_id=>&APP_ID., p_page_id=>6,
    p_name=>'P6_FILTER', p_item_plug_id=>apex_application_api.id(60), p_item_sequence=>30,
    p_prompt=>'Filter Change Type', p_display_as=>'NATIVE_SELECT_LIST',
    p_lov=>'STATIC2:All;,'||'ADDED;ADDED,MODIFIED;MODIFIED,DROPPED;DROPPED,UNCHANGED;UNCHANGED');

  apex_application_api.create_page_button(
    p_id=>apex_application_api.id(65), p_flow_id=>&APP_ID., p_page_id=>6,
    p_button_plug_id=>apex_application_api.id(60), p_button_sequence=>40,
    p_button_name=>'P6_REFRESH', p_button_action=>'SUBMIT', p_button_image_alt=>'Refresh');
end;
/

prompt Done. Review pages 1-6 in application &APP_ID. within workspace &WORKSPACE.
--------------------------------------------------------------------------------
-- Page 7: Create Release
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 7,
    p_flow_id           => &APP_ID.,
    p_name              => 'Create Release',
    p_step_title        => 'Create Release',
    p_warn_on_unsaved_changes => 'Y');

  apex_application_api.create_page_plug(
    p_id=>apex_application_api.id(70), p_flow_id=>&APP_ID., p_page_id=>7,
    p_plug_name=>'Create Release', p_plug_display_sequence=>10, p_plug_source_type=>'NATIVE_STATIC');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(71), p_flow_id=>&APP_ID., p_page_id=>7,
    p_name=>'P7_SCHEMA_NAME', p_item_plug_id=>apex_application_api.id(70), p_item_sequence=>10,
    p_prompt=>'Source Schema', p_display_as=>'NATIVE_TEXT_FIELD', p_is_required=>'Y');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(72), p_flow_id=>&APP_ID., p_page_id=>7,
    p_name=>'P7_SNAPSHOT_ID', p_item_plug_id=>apex_application_api.id(70), p_item_sequence=>20,
    p_prompt=>'Target Snapshot', p_display_as=>'NATIVE_SELECT_LIST',
    p_lov=>q'[select snapshot_name||' ('||created_by||')' d, snapshot_id r from oei_env_sync_snapshots order by created_on desc]');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(73), p_flow_id=>&APP_ID., p_page_id=>7,
    p_name=>'P7_TITLE', p_item_plug_id=>apex_application_api.id(70), p_item_sequence=>25,
    p_prompt=>'Release Title', p_display_as=>'NATIVE_TEXT_FIELD');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(74), p_flow_id=>&APP_ID., p_page_id=>7,
    p_name=>'P7_SCRIPT', p_item_plug_id=>apex_application_api.id(70), p_item_sequence=>80,
    p_prompt=>'Script', p_display_as=>'NATIVE_DISPLAY_ONLY');

  apex_application_api.create_page_item(
    p_id=>apex_application_api.id(75), p_flow_id=>&APP_ID., p_page_id=>7,
    p_name=>'P7_MESSAGE', p_item_plug_id=>apex_application_api.id(70), p_item_sequence=>90,
    p_prompt=>'Message', p_display_as=>'NATIVE_DISPLAY_ONLY');

  apex_application_api.create_page_button(
    p_id=>apex_application_api.id(76), p_flow_id=>&APP_ID., p_page_id=>7,
    p_button_plug_id=>apex_application_api.id(70), p_button_sequence=>60,
    p_button_name=>'P7_GENERATE', p_button_action=>'SUBMIT', p_button_is_hot=>'Y', p_button_image_alt=>'Generate Release');

  apex_application_api.create_page_process(
    p_id=>apex_application_api.id(77), p_flow_id=>&APP_ID., p_page_id=>7,
    p_process_sequence=>10, p_process_point=>'AFTER_SUBMIT', p_process_type=>'NATIVE_PLSQL',
    p_process_name=>'PRC_CREATE_RELEASE', p_process_sql_clob=>q'[
declare
  l_script   clob;
  l_manifest clob;
  l_hash     varchar2(64);
begin
  l_manifest := oei_env_sync_capture_pkg.f_list_changes(
                   in_schema_name  => :P7_SCHEMA_NAME,
                   in_compare_json => (select payload from oei_env_sync_snapshots where snapshot_id = :P7_SNAPSHOT_ID)
                 );

  oei_env_sync_capture_pkg.p_generate_install_script(
    in_schema_name   => :P7_SCHEMA_NAME,
    in_compare_json  => (select payload from oei_env_sync_snapshots where snapshot_id = :P7_SNAPSHOT_ID),
    out_script       => l_script
  );

  l_hash := oei_env_sync_capture_pkg.f_ddl_hash(l_script);

  insert into oei_env_sync_releases (status, release_title, manifest_json, script_clob, script_hash)
  values ('DRAFT', :P7_TITLE, l_manifest, l_script, l_hash);

  :P7_SCRIPT  := l_script;
  :P7_MESSAGE := 'Release created as DRAFT with hash ' || l_hash;
exception when others then
  :P7_MESSAGE := 'Error: ' || sqlerrm; raise;
end;]');
end;
/

--------------------------------------------------------------------------------
-- Page 8: Promotion History
--------------------------------------------------------------------------------
begin
  apex_application_api.create_page(
    p_id                => 8,
    p_flow_id           => &APP_ID.,
    p_name              => 'Promotion History',
    p_step_title        => 'Promotion History');

  apex_application_api.create_page_plug(
    p_id=>apex_application_api.id(80), p_flow_id=>&APP_ID., p_page_id=>8,
    p_plug_name=>'Releases', p_plug_display_sequence=>10, p_plug_source_type=>'NATIVE_IR',
    p_plug_source=>q'[
select r.release_id,
       r.status,
       r.release_title,
       r.created_by,
       r.created_on,
       r.script_hash,
       dbms_lob.getlength(r.script_clob) as script_length
  from oei_env_sync_releases r
 order by r.release_id desc]');

  apex_application_api.create_page_plug(
    p_id=>apex_application_api.id(81), p_flow_id=>&APP_ID., p_page_id=>8,
    p_plug_name=>'Install Log', p_plug_display_sequence=>20, p_plug_source_type=>'NATIVE_IR',
    p_plug_source=>q'[
select l.install_id,
       l.release_id,
       l.target_schema,
       l.installed_by,
       l.installed_on,
       l.success,
       dbms_lob.getlength(l.log_clob) as log_length
  from oei_env_sync_install_log l
 order by l.install_id desc]');
end;
/

prompt Done. Review pages 1-8 in application &APP_ID. within workspace &WORKSPACE.
