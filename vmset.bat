@echo off  
color 0a  
   
GOTO MENU  
:MENU  
echo.=-=-=-=-=VMware �ֹ�����������=-=-=-=-=  
echo.    1  ����VMware�������  
echo.    2  �ر�VMware�������  
echo.    3  exit  
echo  ������ѡ����Ŀ����ţ�  
set /p  ID=  
if "%id%"=="1"  goto start  
if "%id%"=="2" goto stop  
if "%id%"=="3" exit  
PAUSE  
   
:start  
net start "VMware USB Arbitration Service"  
net start "VMware Authorization Service"  
net start "VMware NAT Service"  
net start "VMware DHCP Service"  
  
   
goto MENU  
   
:stop  
rem net stop "VMware Registration Service"  
net stop "VMware USB Arbitration Service"  
net stop "VMware Authorization Service"  
net stop "VMware NAT Service"  
net stop "VMware DHCP Service"  
rem net stop "VMware Virtual Mount Manager Extended"  
  
goto MENU  
