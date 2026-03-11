spool logs/dp-1-2.log

alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

analyze table z#dp COMPUTE STATISTICS
/

delete from z#dp_interest_rate where collection_id not in
(
select c_rates_array from z#cls_dp_params
union all
select a1.c_rates_array from z#dp a1, z#product a2 where a1.id = a2.id and a2.c_cls_states_ref <> 107625484
)
/

commit
/

declare
   v_dp_id                   number;
   v_cls_state               number;
begin
   v_dp_id     := null;
   v_cls_state := null;

   for r in (select * from q#contracts where c_processed = 'N')
   loop

      begin
      select a1.id, a2.c_cls_states_ref
         into v_dp_id, v_cls_state
         from z#dp a1, z#product a2
         where a1.c_dp_account = r.account_no and a1.id = a2.id;
      exception when others
         then v_dp_id     := null;
              v_cls_state := null;
      end;

      if (v_dp_id is not null) then
         if (v_cls_state = 107625484) then
            begin                       
               YT_DP_KILL(v_dp_id);
            exception
               when others then 
                  update q#contracts
                     set c_processed = 'DP'
                     where (c_dp_ref = r.c_dp_ref);
            end;
         else
            update q#contracts
               set c_processed = 'DP'
               where (c_dp_ref = r.c_dp_ref);
         end if;
      end if;

   end loop;
end;
/
commit
/
spool off
exit
