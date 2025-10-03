create or replace package body oei_env_sync_capture_pkg_test as

  procedure t_normalize_basic is
    l_in  clob := 'create table t (id number);'||chr(10)||'  '; 
    l_out clob;
  begin
    l_out := oei_env_sync_capture_pkg.f_normalize_ddl(l_in);
    ut.expect(l_out).to_equal('create table t (id number)');
  end;

  procedure t_hash_equal_semantic is
    l_a   clob := 'create  table  t (id number) ;';
    l_b   clob := chr(10)||'create table t (id number)'||chr(10)||'/';
    h_a   varchar2(64);
    h_b   varchar2(64);
  begin
    h_a := oei_env_sync_capture_pkg.f_ddl_hash(l_a);
    h_b := oei_env_sync_capture_pkg.f_ddl_hash(l_b);
    ut.expect(h_a).to_equal(h_b);
  end;

  procedure t_hash_differs_on_change is
    h_a varchar2(64);
    h_b varchar2(64);
  begin
    h_a := oei_env_sync_capture_pkg.f_ddl_hash('create table t (id number)');
    h_b := oei_env_sync_capture_pkg.f_ddl_hash('create table t (id number, c2 number)');
    ut.expect(h_a).to_not_equal(h_b);
  end;

  procedure t_diff_object_smoke is
    l_out clob;
  begin
    -- Not asserting exact content; just that it doesn't raise and returns something sensible
    l_out := oei_env_sync_capture_pkg.f_diff_object(user, user, 'TABLE', 'NO_SUCH_TABLE');
    ut.expect(1).to_equal(1); -- reached here without raising
  exception
    when others then
      ut.fail('f_diff_object raised: '||sqlerrm);
  end;

end oei_env_sync_capture_pkg_test;
/
