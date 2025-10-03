prompt Creating demo objects for ODB-EnvSync

-- Sequence
create sequence demo_seq start with 1 increment by 1;
/

-- Table + PK + FK example
create table demo_parent (
  id        number primary key,
  name      varchar2(100)
);
/

create table demo_child (
  id         number primary key,
  parent_id  number not null,
  descr      varchar2(200),
  constraint fk_demo_child_parent foreign key (parent_id)
    references demo_parent (id)
);
/

-- Index
create index idx_demo_child_parent on demo_child(parent_id);
/

-- View
create or replace view demo_child_v as
select c.id, c.parent_id, p.name as parent_name, c.descr
  from demo_child c
  join demo_parent p on p.id = c.parent_id;
/

-- Simple function
create or replace function demo_fn_count_children(p_parent_id number)
  return number
as
  l_cnt number;
begin
  select count(*) into l_cnt from demo_child where parent_id = p_parent_id;
  return l_cnt;
end;
/

-- Simple procedure
create or replace procedure demo_pr_add_parent(p_id number, p_name varchar2) as
begin
  insert into demo_parent(id, name) values (p_id, p_name);
end;
/

-- Trigger
create or replace trigger trg_demo_child_biu
before insert or update on demo_child
for each row
begin
  if inserting and :new.id is null then
    select demo_seq.nextval into :new.id from dual;
  end if;
end;
/

-- Sample data
insert into demo_parent(id, name) values (1, 'Parent A');
insert into demo_child(id, parent_id, descr) values (null, 1, 'Child A1');
commit;

