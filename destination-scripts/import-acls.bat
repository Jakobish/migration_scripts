@echo off
set in=D:\ACL-Export
for %%F in ("%in%\*.acl") do (
  icacls "D:\Domains" /restore "%%F"
)
echo Done.
