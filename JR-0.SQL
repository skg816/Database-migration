spool logs/jr-0.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

drop table q#journal
/

create table q#journal
 (
  contract_no                varchar2(15),
  amount                     varchar2(20),
  create_date                varchar2(20),
  transaction_date           varchar2(20),
  user_name                  varchar2(20),
  divs_no                    varchar2(20),
  kind                       varchar2(20),
  layer_code                 varchar2(30)
 )
 pctfree    10
 pctused    40
 initrans   1
 maxtrans   255
 tablespace users
 storage   (
      initial     52428800
      next        52428800
      pctincrease 0
      minextents  1
      maxextents  2147483645
   )
/

create index idx_journal_lc
 on q#journal
  ( layer_code  )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace idx
 storage (
   initial     10m
   next        10m
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
NOLOGGING
/

create index idx_journal_cn
 on q#journal
  ( contract_no  )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace idx
 storage (
   initial     10m
   next        10m
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
NOLOGGING
/

@data/jr.sql

commit
/

analyze table q#journal COMPUTE STATISTICS
/
analyze index idx_journal_lc COMPUTE STATISTICS
/
analyze index idx_journal_cn COMPUTE STATISTICS
/

spool off
exit
