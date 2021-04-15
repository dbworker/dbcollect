---------------------------------------
-- misc.out used by dumping alertlog, create awr report
--   alert path, sid
--   lastmonth's year / month (Abbr.) / month(01..12)
--   1/0 as uniform_log_timestamp_format parameter is 'TRUE' or not
--   log mode
--   is rac?

set heading off
spool misc.out

-- alert path
-- 10g,           lookup background_dump_dest
-- 11g and after, lookup v$diag_info
col value for a80
variable v_vernum number;
variable v_alertpath varchar2(100);
exec select to_number(substr(version,1,4)) into :v_vernum from v$instance;
exec select value into :v_alertpath from v$parameter where name='background_dump_dest';
exec if :v_vernum >10 then select value into :v_alertpath from v$diag_info where name='Diag Trace'; end if;
print :v_alertpath
select 'alert_' || instance_name || '.log' name from v$instance;

-- calculate last-month's literal, for seek alert's time string
select to_char(trunc(sysdate-30,'MONTH'), 'YYYY') ||chr(10)||
       to_char(trunc(sysdate-30,'MONTH'), 'Mon')  ||chr(10)||
       to_char(trunc(sysdate-30,'MONTH'), 'MM') val from dual;

-- after oracle 12c, alert's time string format changed
col cnt for 99
select count(1) cnt from v$parameter where name='uniform_log_timestamp_format'
    and value='TRUE';

select log_mode from v$database;

select parallel from v$instance;

spool off
