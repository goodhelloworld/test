@echo off  
color 0a  
   
GOTO MENU  
:MENU  
echo.=-=-=-=-=VMware 手工启动批处理=-=-=-=-=  
echo.    1  启动VMware各项服务  
echo.    2  关闭VMware各项服务  
echo.    3  exit  
echo  请输入选择项目的序号：  
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
