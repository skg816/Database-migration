set serveroutput on
set linesize 150

spool logs/jr-3.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

declare
   v_counter                 integer := 0;
   v_id                      number;
   v_class_id                varchar2(30);
   v_prev_layer_ref          number;
   v_transaction_date        date;
begin
   v_counter := 0;
   for r in (select * from q#journal where c_processed = 'N' order by contract_no, c_transaction_date, c_rank)
   loop
      select  seq_id.nextval 
         into v_id 
         from dual;

      v_class_id := null;
      v_transaction_date := r.c_transaction_date;

      if (r.kind = '+') then
         v_class_id := 'DP_JI_INCOMING';
      elsif (r.kind = '+%') then
         v_class_id := 'DP_JI_CAP_PCT';
         v_transaction_date := v_transaction_date + 20 / 24 / 60 / 60;
      elsif (r.kind = '%') then
         v_class_id := 'DP_JI_PAY_PCT';
         v_transaction_date := v_transaction_date + 10 / 24 / 60 / 60;
      elsif (r.kind = '-') then                                 
         v_class_id := 'DP_JI_OUTGOING';
      elsif (r.kind = '-%') then
         v_class_id := 'DP_JI_CAP_PCT';
         r.c_amount :=  - r.c_amount ;
         v_transaction_date := v_transaction_date + 20 / 24 / 60 / 60;
      else
         message.app_error( 'Invalid Oper Type = <'||r.kind ||'>' , 'ContractN='||r.contract_no||', Date='||to_char(r.c_transaction_date,'dd/mm/yyyy') );
      end if;

      begin
      insert into z#dp_ji_abstract (id,
                                    class_id,
                                    collection_id,
                                    c_layer_ref,
                                    c_transaction_date,
                                    c_is_planned,
                                    c_amount,
                                    c_audit_mark#date_time,
                                    c_audit_mark#user_ref,
                                    c_audit_mark#division_ref,
                                    c_audit_mark#reason,
                                    c_cls_states_ref,
                                    c_saldo_kind,
                                    c_saldo)
         values                    (v_id,
                                    v_class_id,
                                    r.c_journal,
                                    r.c_layer_ref,
                                    v_transaction_date,
                                    '0',
                                    r.c_amount,
                                    r.c_transaction_date,
                                    r.c_user_ref,
                                    r.divs_no,
                                    r.layer_code,
                                    107514717,
                                    null,
                                    null);

      exception when others then
         message.app_error( 'Invalid Values' , 'ContractN='||r.contract_no||', Date='||to_char(r.c_transaction_date,'dd/mm/yyyy')||' '||sqlerrm );
      end;
      if (r.kind = '+') then
         insert into z#dp_ji_incoming (id,    collection_id)
            values                    (v_id,  r.c_journal);
      elsif (r.kind = '+%') then
         insert into z#dp_ji_cap_pct  (id,   collection_id)
            values                    (v_id, r.c_journal);
      elsif (r.kind = '%') then
         insert into z#dp_ji_pay_pct  (id,   c_cy_expense, collection_id)
            values                    (v_id, 0,   r.c_journal);
      elsif (r.kind = '-') then
         insert into z#dp_ji_outgoing (id,   collection_id)
            values                    (v_id,        r.c_journal);
      elsif (r.kind = '-%') then
         insert into z#dp_ji_cap_pct  (id,   collection_id)
            values                    (v_id, r.c_journal);
      end if;

      update q#journal
         set c_processed = 'Y',
             c_item_ref  = v_id    
         where (c_item_ref = r.c_item_ref);

      commit;

   end loop;
end;
/

analyze table z#dp_ji_abstract COMPUTE STATISTICS
/
analyze table z#dp_ji_incoming COMPUTE STATISTICS
/
analyze table z#dp_ji_cap_pct COMPUTE STATISTICS
/
analyze table z#dp_ji_pay_pct COMPUTE STATISTICS
/
analyze table z#dp_ji_outgoing COMPUTE STATISTICS
/
analyze table z#dp_ji_cap_pct COMPUTE STATISTICS
/

prompt Список транзакций, которые не были обработаны

select c_processed, contract_no, transaction_date, layer_code from q#journal where c_processed != 'Y'
/

declare
   v_saldo                   number(32, 2);
begin

   for c in (select a1.*
             from z#dp a1, z#product a2
             where a1.id = a2.id and
                   a2.c_cls_states_ref = 107625484)
   loop
      v_saldo := 0;

      for l in (select * from z#dp_ji_layer where (collection_id = c.c_journal) order by c_transaction_date, id)
      loop
         for r in (select * from z#dp_ji_abstract where (collection_id = c.c_journal) and (c_layer_ref = l.id) order by c_transaction_date, id)
         loop
            if (r.class_id = 'DP_JI_INCOMING') then
               v_saldo := v_saldo + r.c_amount;

               update z#dp_ji_abstract
                  set c_saldo      = v_saldo,
                      c_saldo_kind = 'D'
                  where (id = r.id);
            elsif (r.class_id = 'DP_JI_OUTGOING') then
               v_saldo := v_saldo - r.c_amount;

               update z#dp_ji_abstract
                  set c_saldo      = v_saldo,
                      c_saldo_kind = 'D'
                  where (id = r.id);
            elsif (r.class_id = 'DP_JI_CAP_PCT') then
               v_saldo := v_saldo + r.c_amount;

                 update z#dp_ji_abstract
                  set c_saldo      = v_saldo,
                      c_saldo_kind = 'D'
                  where (id = r.id);
            elsif (r.class_id = 'DP_JI_LAYER') then
               v_saldo := 0.00;
/*
               update z#dp_ji_abstract
                  set c_saldo      = v_saldo,
                      c_amount     = null,
                      c_saldo_kind = 'D'
                  where (id = r.id);
*/
            end if;
         end loop;
      end loop;

      update z#dp
         set c_saldo = v_saldo
         where (id = c.id);
   end loop;
end;
/

prompt Отрицательный остаток после операции

select class_id, c_saldo, c_saldo_kind, (select c_contract_no from z#dp where c_journal=collection_id) contract_no from z#dp_ji_abstract where c_saldo < 0
/

commit
/

prompt Расхождения с АМАНАТОМ (остаток депозитного счета)

select a.contract_no, a.current_art, a.c_amount, b.c_saldo, a.c_amount -  b.c_saldo dif, a.current_art
   from q#contracts a, z#dp b
   where (a.c_dp_ref = b.id) and (b.c_saldo != a.c_amount) and (a.c_processed = 'Y')
/

commit
/

analyze table z#dp COMPUTE STATISTICS
/

analyze table z#dp_ji_abstract COMPUTE STATISTICS
/
analyze table z#dp_ji_incoming COMPUTE STATISTICS
/
analyze table z#dp_ji_cap_pct COMPUTE STATISTICS
/
analyze table z#dp_ji_pay_pct COMPUTE STATISTICS
/
analyze table z#dp_ji_outgoing COMPUTE STATISTICS
/
analyze table z#dp_ji_cap_pct COMPUTE STATISTICS
/

spool off
exit
