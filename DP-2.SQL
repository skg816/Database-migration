spool logs/dp-2.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

analyze table z#dp COMPUTE STATISTICS
/

declare
   v_rates_array             number;
   v_states_array            number;
   v_warrant                 number;
   v_days                    number;
   v_dp_id                   number;
   v_cls_state               number;
   n                         integer;
begin
   for r in (select * from q#contracts where c_processed = 'N')
   loop

      select seq_id.nextval into v_rates_array  from dual;
      select seq_id.nextval into v_states_array from dual;
      select seq_id.nextval into v_warrant      from dual;
      
      select c_days_max     into  v_days        from z#cls_dp_params where (id = r.c_cls_params_ref);

      insert into z#product   (id,         class_id, c_cls_states_ref, c_states_array)
          values              (r.c_dp_ref, 'DP',     107625484,        v_states_array);


      insert into z#agreement (id,         class_id, c_contract_no, c_contract_date, c_client_ref,   c_period#date_start, c_period#date_final)
          values              (r.c_dp_ref, 'DP',     r.contract_no, r.contract_date, r.c_client_ref, r.contract_date,     null);

      insert into z#dp        (id,         c_contract_no, c_days, c_currency_ref,   c_password, c_journal,   c_layer_ref, c_rates_array, c_warrant, c_dp_account, c_saldo)
          values              (r.c_dp_ref, r.contract_no, v_days, r.c_currency_ref, r.word,     r.c_journal, null,        v_rates_array, v_warrant, r.account_no, 0);

      update q#contracts
         set c_processed = 'Y'
         where (c_dp_ref = r.c_dp_ref);
   end loop;
end;
/

commit
/

analyze table z#dp COMPUTE STATISTICS
/
analyze table z#product COMPUTE STATISTICS
/
analyze table z#agreement COMPUTE STATISTICS
/

prompt Создано договоров

select count(a1.id) from z#dp a1, z#product a2
   where a1.id = a2.id and a2.c_cls_states_ref = 107625484
/

prompt Необработанные договоры

select c_processed, contract_no from q#contracts where c_processed != 'Y'
/

commit
/
spool off
exit
