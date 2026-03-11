alter session set nls_language='AMERICAN'
/

alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy hh24:mi:ss'
/

alter session set nls_numeric_characters = ',.'
/

drop table q#dates
/

create table q#dates
 (
  c_date                     date,
  c_is_common                varchar2(1)
 )
/

declare
   v_date                    date;
   v_date1                   date;
   n_Cnt		     number;
begin
   
   select count(*) into n_Cnt from q#dates;
   if n_Cnt > 0 then
      select max(c_date) into v_date from q#dates;
   else
      v_date := to_date('15/02/1968', 'dd/mm/yyyy');
   end if;
   v_date1 := to_date('01/07/2002', 'dd/mm/yyyy');

   loop
      v_date := add_months(last_day(v_date), 1);

      exit when (v_date > sysdate );

      insert into q#dates (c_date, c_is_common) values (v_date, '1');
   end loop;
end;
/

commit
/

exit
