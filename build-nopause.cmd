@echo off
REM 把所有参数转发给 build.bat，并将标准输入接到 nul，让 build.bat 结尾的 pause 立即读到 EOF 返回。
REM 非交互调用（agent、脚本、CI）不再卡在等按键；退出码由 build.bat 的 exit /b 原样保留。
REM 用法：build-nopause.cmd --only-pck   等价于 build.bat --only-pck 但不停在 pause。
"%~dp0build.bat" %* < nul
