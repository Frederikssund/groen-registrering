"C:\Program Files\PostgreSQL\9.6\bin\pg_dump" -h localhost -p 5432 -U backadm -W -d groenreg -F c > %~dp0/groenreg_%date:~-4,4%_%date:~-7,2%_%date:~-10,2%.backup