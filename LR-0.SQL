spool logs/lr-0.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

drop table q#layers
/

create table q#layers
 (
  contract_no                varchar2(10),
  current_art                varchar2(25),
  user_name                  varchar2(20),
  art_date                   varchar2(20),
  layer_code                 varchar2(30),
  divs_no                    varchar2(20)
 )
 tablespace users
 storage   (
      initial     8192k
      next        2048k
      pctincrease 50
      minextents  1
      maxextents  2147483645
   )
/
@data/lr.sql


commit
/

analyze table q#layers COMPUTE STATISTICS
/

spool off

exit
