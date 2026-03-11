set serveroutput on
set linesize 150

spool logs/jr-2.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

declare
   v_next_art_date           date;
begin
   dbms_output.enable(1000000);

   for c in (select contract_no from q#contracts where (c_processed = 'Y'))
   loop
      for l in (select layer_code, c_transaction_date from q#layers where (contract_no = c.contract_no) and (c_processed = 'Y') order by c_transaction_date)
      loop
         begin
            select  c_transaction_date
               into v_next_art_date
               from q#layers
               where (contract_no = c.contract_no) and (c_processed = 'Y') and (c_transaction_date >= l.c_transaction_date) and (layer_code != l.layer_code);
         exception      
            when others then
               v_next_art_date := constant.date_max;
         end;      
            
         for j in (select * from q#journal where (layer_code = l.layer_code) and ((c_transaction_date < l.c_transaction_date) or (c_transaction_date > v_next_art_date)))
         loop
             dbms_output.put_line('l_date=' || to_char(l.c_transaction_date, 'dd/mm/yyyy hh24:mi:ss') || ' ' ||
                                  'r_date=' || to_char(v_next_art_date,      'dd/mm/yyyy hh24:mi:ss') || ' ' ||
                                  't_date=' || to_char(j.c_transaction_date, 'dd/mm/yyyy hh24:mi:ss'));

             update q#journal 
                set c_processed = '-J'
                where (c_item_ref = j.c_item_ref);
         end loop;
      end loop;
   end loop;
end;
/

prompt Нарушение слоев

select count(1)  from q#journal where c_processed = '-J'
/

prompt Список транзакций, которые не будут обработаны по причине нарушения слоев

select c_processed, contract_no, transaction_date, layer_code from q#journal where c_processed = '-J'
/

commit
/

analyze table q#journal COMPUTE STATISTICS
/
analyze index idx_journal COMPUTE STATISTICS
/

spool off
exit
