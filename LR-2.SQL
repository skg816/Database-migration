spool logs/lr-2.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

declare
   v_id                      number;
   v_prev_layer_ref          number;
begin
   for r in (select * from q#layers where c_processed = 'N' order by c_dp_ref, c_transaction_date, layer_code)
   loop
      select  seq_id.nextval 
         into v_id 
         from dual;

      select c_layer_ref
         into v_prev_layer_ref
         from z#dp
         where (id = r.c_dp_ref);

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
                                    'DP_JI_LAYER',
                                    r.c_journal,
                                    null,
                                    r.c_transaction_date,
                                    '0',
                                    null,
                                    r.c_transaction_date,
                                    r.c_user_ref,
                                    r.divs_no,
                                    r.layer_code,
                                    107514717,
                                    null,
                                    null);


      insert into z#dp_ji_layer    (id,    collection_id, c_cls_params_ref,   c_prev_layer_ref, c_transaction_date  , c_booking_ref  , c_is_planned)
         values                    (v_id,  r.c_journal,   r.c_cls_params_ref, v_prev_layer_ref, r.c_transaction_date, r.c_booking_ref, '0');

      update z#dp_ji_abstract
         set c_layer_ref = v_id
         where (id = v_id);

      update z#dp
         set c_layer_ref = v_id
         where (id = r.c_dp_ref);

      update q#layers
         set c_processed = 'Y',
             c_layer_ref = v_id
         where (c_layer_ref = r.c_layer_ref);
   commit;
   end loop;
end;
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

prompt Создано слоев

select count(1)  from  z#dp_ji_layer 
/

prompt Список слоев, которые не были обработаны

select c_processed, layer_code from q#layers where c_processed != 'Y'
/

spool off
exit
