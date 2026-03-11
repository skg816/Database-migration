spool logs/dp-0.log

drop table q#contracts
/

create table q#contracts
 (
  client_no                  varchar2(50),
  account_no                 varchar2(50),
  contract_no                varchar2(15),
  current_art                varchar2(25),
  contract_date              varchar2(20),
  plan_close                 varchar2(20),
  art_date                   varchar2(20),
  amount                     varchar2(20),
  interest                   varchar2(20),
  word                       varchar2(20),
  divs_no                    varchar2(20),
  user_name                  varchar2(20),
  layer_code                 varchar2(30),
  currency                   varchar2(10)
 )
 pctfree    10
 pctused    40
 initrans   1
 maxtrans   255
 tablespace users
 storage   (
      initial     4096k
      next        1024k
      pctincrease 50
      minextents  1
      maxextents  2147483645
   )
/

@data/dp.sql

commit
/

analyze table q#contracts COMPUTE STATISTICS
/

spool off
exit
