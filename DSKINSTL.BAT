echo off
REM ***************************************************************************
REM **  This batch file automatically installs the dsk software on your c:\  **
REM **  drive. It creates the C:\DSK directory and two sub-directories named **
REM **  \APPS and \ROM.                                                      **
REM ***************************************************************************
c:\
md dsk
cd dsk
xcopy %1 c:\dsk /s
