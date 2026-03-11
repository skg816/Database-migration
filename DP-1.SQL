spool logs/dp-1.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

update q#contracts
   set client_no     = ltrim(rtrim(client_no)),
       account_no    = ltrim(rtrim(account_no)),
       contract_no   = ltrim(rtrim(contract_no)),
       current_art   = ltrim(rtrim(current_art)),
       contract_date = ltrim(rtrim(contract_date)),
       amount        = ltrim(rtrim(amount)),
       interest      = ltrim(rtrim(interest)),
       plan_close    = ltrim(rtrim(plan_close)),
       art_date      = ltrim(rtrim(art_date)),
       word          = ltrim(rtrim(word)),
       divs_no       = ltrim(rtrim(divs_no)),
       user_name     = ltrim(rtrim(user_name)),
       layer_code    = ltrim(rtrim(layer_code)),
       currency      = ltrim(rtrim(currency))
/

alter table q#contracts add
 (
  c_amount                   number default null,
  c_interest                 number default null,
  c_currency_ref             number default null,
  c_client_ref               number default null,
  c_journal                  number default null,
  c_user_ref                 number default null,
  c_divs_ref                 number default null,
  c_cls_params_ref           number default null,
  c_layer_ref                number default null,
  c_dp_ref                   number default null,
  c_close_date               date   default null,
  c_processed                char(5) default 'N'
 )
/

create unique index idx_contracts_no
 on q#contracts
  ( contract_no  )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace users
 storage (
   initial     50k
   next        50k
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
/
create index idx_contracts_ref
 on q#contracts
  ( c_dp_ref  )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace users
 storage (
   initial     50k
   next        50k
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
/

analyze index idx_contracts_no COMPUTE STATISTICS
/
analyze index idx_contracts_ref COMPUTE STATISTICS
/

alter session set nls_numeric_characters = '.,'
/

commit
/


update q#contracts u
   set u.c_client_ref     = (select s.id from z#client        s where s.c_num_id      = u.client_no),
       u.c_user_ref       = (select s.id from z#user          s where s.c_username    = u.user_name),
       u.c_divs_ref       = (select s.id from z#divisions     s where s.c_retail_num  = u.divs_no),
       u.c_cls_params_ref = (select s.id from z#cls_dp_params s where s.c_code        = u.current_art),
       u.c_currency_ref   = (select s.id from z#currency      s where s.c_cur_short   = u.currency),
       u.c_dp_ref         = seq_id.nextval,
       u.c_amount         = to_number(amount),
       u.c_interest       = to_number(interest),
       u.c_close_date     = to_date(plan_close, 'dd/mm/yyyy'),
       u.c_processed      = 'N'
/

commit
/


update q#contracts
   set c_processed        = '-C'
   where c_currency_ref is null
/

update q#contracts
   set c_processed        = '-A'
   where c_cls_params_ref is null
/

commit
/

update q#contracts u
   set u.c_journal     = seq_id.nextval
/

commit
/

prompt Список договоров, которые не будут обработаны

select c_processed, contract_no from q#contracts where c_processed != 'N'
/

commit
/

analyze table q#contracts COMPUTE STATISTICS
/

spool off
exit
