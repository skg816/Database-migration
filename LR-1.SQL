define cur_date='30/11/2001'

spool logs/lr-1.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/


prompt Найдено слоев для закрытия договоров

select count(1) from q#layers where current_art = '+CLOSE'
/

alter table q#layers add
 (
  c_dp_ref                   number default null,
  c_journal                  number default null,
  c_booking_ref              number default null,
  c_user_ref                 number default null,
  c_cls_params_ref           number default null,
  c_layer_ref                number default null,
  c_transaction_date         date   default null,
  c_processed                char(5) default 'N'
 )
/
create index idx_layers_code
 on q#layers
  ( layer_code  )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace idx
 storage (
   initial     50k
   next        50k
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
/

create index idx_current_art
 on q#layers
  ( current_art  )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace idx
 storage (
   initial     50k
   next        50k
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
/

create index idx_layers_ref
 on q#layers
  ( c_layer_ref )
  pctfree    10
  initrans   2
  maxtrans   255
  tablespace idx
 storage (
   initial     50k
   next        50k
   pctincrease 0
   minextents  1
   maxextents  2147483645
   )
/

CREATE INDEX OLE.IDX_LAYERS_DATE
    ON OLE.Q#LAYERS(C_TRANSACTION_DATE)
PCTFREE 10
INITRANS 2
MAXTRANS 255
TABLESPACE IDX
STORAGE(INITIAL 64K
        NEXT 128K
        MINEXTENTS 1
        MAXEXTENTS 4096
        PCTINCREASE 0)
/

CREATE INDEX OLE.IDX_LAYER_CONTR_NO
    ON OLE.Q#LAYERS(CONTRACT_NO)
PCTFREE 10
INITRANS 2
MAXTRANS 255
TABLESPACE IDX
STORAGE(INITIAL 64K
        NEXT 128K
        MINEXTENTS 1
        MAXEXTENTS 4096
        PCTINCREASE 0)
/

CREATE BITMAP INDEX OLE.IDX_LAYERS_PROCESS
    ON OLE.Q#LAYERS(C_PROCESSED)
PCTFREE 10
INITRANS 2
MAXTRANS 255
TABLESPACE IDX
STORAGE(INITIAL 64K
        NEXT 128K
        MINEXTENTS 1
        MAXEXTENTS 4096
        PCTINCREASE 0)
/

update  q#layers 
   set c_transaction_date = trunc(to_date(art_date, 'dd/mm/yyyy hh24:mi:ss')),
       c_layer_ref        = seq_id.nextval
/

commit
/

update  q#layers
   set c_cls_params_ref   = null,
       c_dp_ref           = null
/

commit
/

update q#layers u
   set u.c_cls_params_ref   = (select s.id         from z#cls_dp_params s where s.c_code        = u.current_art),
       u.c_dp_ref           = (select a1.id        from z#dp a1, z#product a2
                               where a1.id = a2.id and a2.c_cls_states_ref = 107625484
                                     and a1.c_contract_no = u.contract_no),
       u.c_journal          = (select a1.c_journal from z#dp a1, z#product a2
                               where a1.id = a2.id and a2.c_cls_states_ref = 107625484
                                     and a1.c_contract_no = u.contract_no),
       u.c_user_ref         = (select s.id         from z#user          s where s.c_username    = u.user_name),
       u.divs_no            = (select s.id         from z#divisions s where s.c_retail_num  = u.divs_no),
       u.c_booking_ref      = (select a1.id        from z#dp_booking a1, z#cls_dp_params a2, z#currency a3
                                                   where a1.collection_id = a2.c_books_array and a1.c_currency_ref = a3.id
                                                     and a2.c_code = u.current_art
                                                     and a3.c_cur_short = (select b5.currency
                                                                           from q#contracts b5
                                                                           where u.contract_no = b5.contract_no)
                                                     and a1.c_is_resident = nvl((select b3.c_resident
                                                                                 from q#contracts b2, z#client b3
                                                                                 where u.contract_no = b2.contract_no and b2.client_no = b3.c_num_id), 1)
                              )
/

commit
/

update  q#layers
   set c_processed = '-A'
   where c_cls_params_ref is null and c_processed = 'N' and  current_art != '+CLOSE'
/

update  q#layers
   set c_processed = '-C'
   where c_dp_ref is null  and c_processed = 'N'
/

commit
/

analyze table q#layers COMPUTE STATISTICS
/
analyze index idx_layers_code COMPUTE STATISTICS
/
analyze index idx_current_art COMPUTE STATISTICS
/
analyze index idx_layers_ref COMPUTE STATISTICS
/
prompt Список слоев, которые не будут обработаны

select c_processed, layer_code from q#layers where c_processed != 'N'
/

spool off
exit
