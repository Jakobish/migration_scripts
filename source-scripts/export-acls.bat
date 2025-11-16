@echo off
set root=D:\Domains
set out=D:\ACL-Export
if not exist "%out%" mkdir "%out%"
for /d %%F in ("%root%\*") do (
  icacls "%%F" /save "%out%\%%~nF.acl" /t
)
echo Done.
