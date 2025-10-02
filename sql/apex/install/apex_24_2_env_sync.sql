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
