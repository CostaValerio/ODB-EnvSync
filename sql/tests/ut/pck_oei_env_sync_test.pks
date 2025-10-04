create or replace package pck_oei_env_sync_test as
  --%suite(Env Sync Capture - Unit Tests)
  --%suitepath(oei.envsync)

  --%test(DDL normalization removes noise)
  procedure t_normalize_basic;

  --%test(DDL hash equal for semantically identical statements)
  procedure t_hash_equal_semantic;

  --%test(DDL hash differs for meaningful change)
  procedure t_hash_differs_on_change;

  --%test(f_diff_object does not raise and returns CLOB or NULL)
  procedure t_diff_object_smoke;
end pck_oei_env_sync_test;
/
