@echo off
cd /d "L:\GitHub\Arcade-Darius2WarriorBlade_MiSTer_Private"
echo === Darius2WarriorBlade Build ===
echo Start: %date% %time%
echo.
"C:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe" --flow compile Darius2WarriorBlade 2>&1 | findstr /i "error warning successful elapsed"
echo.
echo === Result ===
echo End: %date% %time%
if exist output_files\Darius2WarriorBlade.rbf (
    echo RBF:
    dir /tc output_files\Darius2WarriorBlade.rbf | findstr "Darius2WarriorBlade.rbf"
) else (
    echo NO RBF GENERATED
)
echo.
pause
