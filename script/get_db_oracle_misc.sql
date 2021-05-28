---------------------------------------
-- misc.out used by dumping alertlog, create awr report
--   1 alert path
--   2 sid
--   3,4,5: lastmonth's year / month (Abbr.) / month(01..12)
--   6: 1/0 as uniform_log_timestamp_format parameter is 'TRUE' or not
--   7: log mode
--   8: is rac?
--   9: version
set heading off

-- alert path
-- 10g,           lookup background_dump_dest
-- 11g and after, lookup v$diag_info
col value for a80
variable v_vernum number;
variable v_alertpath varchar2(100);
exec select to_number(substr(version,1,4)) into :v_vernum from v$instance;
exec select value into :v_alertpath from v$parameter where name='background_dump_dest';
exec if :v_vernum >=11.2 then select value into :v_alertpath from v$diag_info where name='Diag Trace'; end if;

spool misc.out

print :v_alertpath
select 'alert_' || instance_name || '.log' name from v$instance;

-- calculate last-month's literal, for seek alert's time string
select to_char(trunc(sysdate-30,'MONTH'), 'YYYY') ||chr(10)||
       to_char(trunc(sysdate-30,'MONTH'), 'Mon')  ||chr(10)||
       to_char(trunc(sysdate-30,'MONTH'), 'MM') val from dual;

-- start from 12.2, alert's time string format changed
col cnt for 99
select count(1) cnt from v$parameter where name='uniform_log_timestamp_format'
    and value='TRUE';

select log_mode from v$database;

select parallel from v$instance;
select substr(version, 1, 4) from v$instance;

spool off
