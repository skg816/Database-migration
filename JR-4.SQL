set serveroutput on
set linesize 150

spool logs/jr-4.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

declare
   counter                   integer := 0;
   v_layer_date              date;
   v_cls_params_ref          number;
   v_cls_kind_ref            number;
   v_interest_               number(32, 2);
   v_interest                number(32, 2);
   v_item_ref                number;
   v_item_date               date;
   v_saldo                   number(32, 2);
begin

   update z#dp
      set c_interest#saldo          = 0.00,
          c_interest#on_date_amount = null,
          c_interest#on_date_saldo  = null,
          c_interest#valid_on       = null
   where id in (select a1.id
                from z#dp a1, z#product a2
                where a1.id = a2.id and
                      a2.c_cls_states_ref = 107625484);

   dbms_output.enable(1000000);

   counter := 0;

   for r in (select a1.id, a1.c_contract_no, a1.c_journal, a1.c_layer_ref
             from z#dp a1, z#product a2
             where a1.id = a2.id and
                   a2.c_cls_states_ref = 107625484)

   loop

      counter := counter + 1;

      -- dbms_output.put_line(r.c_contract_no || ' <0> ');

      begin
         savepoint sp;

         delete from q#dates where (c_is_common = '0');

         select  trunc(c_transaction_date), c_cls_params_ref
            into v_layer_date,              v_cls_params_ref
            from z#dp_ji_layer
            where (id = r.c_layer_ref);
            
         if (v_cls_params_ref is not null) then
            select  c_cls_kind_ref
               into v_cls_kind_ref
               from z#cls_dp_params
               where (id = v_cls_params_ref);

            v_item_ref  := null;   

            if (v_cls_kind_ref != 124664503) then
               insert into q#dates
                  select trunc(c_transaction_date), '0'
                     from z#dp_ji_abstract
                     where (c_layer_ref = r.c_layer_ref) and (class_id = 'DP_JI_PAY_PCT');
  
               for d in (select distinct c_date from q#dates where (c_date >= v_layer_date) order by c_date)
               loop
                  z$cls_dp_params_run.process(r.id, r.c_layer_ref, d.c_date, FALSE, v_interest_, v_interest);

                  v_item_ref := z$dp_ji_abstract_lib_journal.add_percent(r.id, v_interest, sysdate + 300, FALSE);
                  
                  -- dbms_output.put_line(r.c_contract_no || ' <1> ' || v_interest);

                  if (v_item_ref is not null) then
                     update z#dp_ji_abstract
                        set c_transaction_date = d.c_date
                        where (id = v_item_ref);
                  end if;
               end loop;

               delete from q#dates where (c_is_common = '0');
            else
               z$cls_dp_params_run.process(r.id, r.c_layer_ref, v_layer_date, FALSE, v_interest_, v_interest);

               v_item_ref  := z$dp_ji_abstract_lib_journal.add_percent(r.id, v_interest, sysdate + 300, FALSE);

               -- dbms_output.put_line(r.c_contract_no || ' <2> ' || v_interest);

               select  min(c_transaction_date) - 1 / 24 / 60 / 60
                  into v_item_date
                  from z#dp_ji_abstract
                  where (c_layer_ref = r.c_layer_ref) and (class_id = 'DP_JI_PAY_PCT');

 
               if (v_item_ref is not null) then
                  update z#dp_ji_abstract
                     set c_transaction_date = nvl(v_item_date, v_layer_date)
                     where (id = v_item_ref);
               end if;
            end if;
         end if;
      exception
         when others then
            dbms_output.put_line(r.c_contract_no || ' ' || utils.error_stack);

            rollback to sp;
      end;

      if (mod(counter, 5000) = 0) then
         commit;
      end if;
   end loop;

   commit;

   counter := 0;

   for c in (select a1.id, a1.c_journal, a1.c_layer_ref, a1.c_contract_no
             from z#dp a1, z#product a2
             where a1.id = a2.id and
                   a2.c_cls_states_ref = 107625484)

   loop

      counter := counter + 1;
      v_saldo := 0;

      for r in (select * from z#dp_ji_abstract where (collection_id = c.c_journal) and (c_layer_ref = c.c_layer_ref) order by c_transaction_date, id)
      loop
         if (r.class_id = 'DP_JI_ADD_PCT') then
            v_saldo := v_saldo + r.c_amount;

            update z#dp_ji_abstract
               set c_saldo      = v_saldo,
                   c_saldo_kind = 'I'
               where (id = r.id);
         elsif (r.class_id = 'DP_JI_PAY_PCT') then
            v_saldo := v_saldo - r.c_amount;

            update z#dp_ji_abstract
               set c_saldo      = v_saldo,
                  c_saldo_kind = 'I'
               where (id = r.id);
         end if;
      end loop;

      update z#dp
         set c_interest#saldo = v_saldo
         where (id = c.id);

      if (mod(counter, 5000) = 0) then
         commit;
      end if;
   end loop;

   commit;
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


prompt Расхождения (более 1 тыин) с АМАНАТОМ (остаток счета начисленных процентов)

select * from
(
select a.contract_no, a.current_art amanat_current_art, a.c_interest amanat_interest, b.c_interest#saldo ibso_interest, a.c_interest -  b.c_interest#saldo dif, a.current_art ibso_current_art
   from q#contracts a, z#dp b
   where (a.c_dp_ref = b.id) and (b.c_interest#saldo != a.c_interest) and (a.c_processed = 'Y')
)
where abs(dif) > 0.01
/

commit
/

spool off
exit
