spool logs/jr-1.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

alter session set nls_numeric_characters = '.,'
/

alter table q#journal add
 (
  c_rank                     number,
  c_transaction_date         date    default null,
  c_amount                   number  default null,
  c_first_incoming           char(1) default 'N',
  c_item_ref                 number  default null,
  c_processed                char(5) default 'N'
 )
/

CREATE BITMAP INDEX OLE.IDX_JOURNAL_PROC
    ON OLE.Q#JOURNAL(C_PROCESSED)
TABLESPACE IDX
STORAGE(INITIAL 512K
        NEXT 128K
        MAXEXTENTS UNLIMITED
        BUFFER_POOL DEFAULT)
NOLOGGING
/

create index idx_journal
 on q#journal
  ( c_item_ref  )
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
/

update q#journal
   set c_transaction_date = trunc(to_date(transaction_date, 'dd/mm/yyyy hh24:mi:ss')),
       c_amount           = abs(to_number(ltrim(rtrim(amount)))),
       c_rank             = decode(kind, '+', 1, '%', 2, '+%', 3, '-', 4, 10),
       c_item_ref         = seq_id.nextval
/

commit
/

update q#journal u
   set u.c_first_incoming = 'Y'
   where u.kind = '+' and
         u.c_transaction_date = (select min(j.c_transaction_date) from q#journal j where j.contract_no = u.contract_no)
/

alter table q#journal add
 (
  c_create_date              date   default null,
  c_user_ref                 number default null,
  c_divs_ref                 number default null,
  c_dp_ref                   number default null,
  c_journal                  number default null,
  c_layer_ref                number default null
 )
/


update  q#journal j
   set j.c_processed  = '-C'
   where not exists (select 1 from q#contracts c where c.contract_no = j.contract_no and c.c_processed = 'Y')
/

commit
/

update  q#journal j
   set j.c_processed  = '-L'
   where not exists (select 1 from q#layers    l where l.layer_code  = j.layer_code  and l.c_processed = 'Y')
/

commit
/

update q#journal u
   set u.c_create_date      = to_date(u.create_date,      'dd/mm/yyyy hh24:mi:ss'),
       u.c_user_ref         = (select s.id          from z#user      s where s.c_username    = u.user_name),
       u.divs_no            = (select s.id         from z#divisions s where s.c_retail_num  = u.divs_no),
       u.c_divs_ref         = (select s.id          from z#divisions s where s.c_retail_num  = u.divs_no),
       u.c_dp_ref           = (select a1.id         from z#dp a1, z#product a2
                               where a1.id = a2.id and a2.c_cls_states_ref = 107625484
                                     and a1.c_contract_no = u.contract_no),
       u.c_layer_ref        = (select s.c_layer_ref from q#layers    s where u.layer_code    = s.layer_code and s.c_processed = 'Y')
/

commit
/

update q#journal u
   set u.c_journal = (select a1.c_journal from z#dp a1, z#product a2
                      where a1.id = a2.id and a2.c_cls_states_ref = 107625484
                            and a1.id = u.c_dp_ref)
/

commit
/

analyze table q#journal COMPUTE STATISTICS
/
analyze index idx_journal COMPUTE STATISTICS
/

prompt Список транзакций, которые не будут обработаны

select c_processed, contract_no, transaction_date, layer_code from q#journal where c_processed != 'N'
/

spool off
exit
