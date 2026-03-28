@echo off
setlocal EnableDelayedExpansion

set "dk_args=%*"
set "dk_auto_mode="
set "dk_restart_choice="

:dk_parse_args
if "%~1"=="" goto :dk_admin_check
if /i "%~1"=="--continue" set "dk_auto_mode=continue"
if /i "%~1"=="--revert" set "dk_auto_mode=revert"
if /i "%~1"=="--restart-now" set "dk_restart_choice=1"
if /i "%~1"=="--restart-later" set "dk_restart_choice=2"
shift
goto :dk_parse_args

:dk_admin_check
fltmc >nul 2>&1
if errorlevel 1 (
    echo.
    echo This script requires administrator privileges.
	echo.
	echo A UAC prompt will appear. Please click "Yes".
	echo.
	powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '!dk_args!' -Verb RunAs"
    exit /b
)

:dk_setvar

set "SysPath=%SystemRoot%\System32"
set "ps=%SysPath%\WindowsPowerShell\v1.0\powershell.exe"
set "psc=%ps% -nop -c"
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "cYellow=%ESC%[40;93m"
set "cGreen=%ESC%[42;97m"
set "cRed=%ESC%[31m"
set "cRedHL=%ESC%[41;97m"
set "cBlueHL=%ESC%[44;97m"
set "cGreyHL=%ESC%[100;97m"
set "cReset=%ESC%[0m"

call :dk_sysinfo

set "_NCS=1"
if !winbuild! LSS 10586 set "_NCS=0"
if !winbuild! GEQ 10586 reg query "HKCU\Console" /v ForceV2 >nul 2>&1 | find /i "0x0" >nul 2>&1 && set "_NCS=0"
for /f "tokens=3" %%A in ('reg query "HKCU\Console" /v VirtualTerminalLevel 2^>nul') do if "%%A"=="0x0" set "_NCS=0"
if "!_NCS!"=="0" (
    set "cYellow="
    set "cGreen="
    set "cRed="
    set "cRedHL="
    set "cBlueHL="
    set "cGreyHL="
    set "cReset="
)

:title

cls
title VBS 1.1
if not defined terminal (
    %psc% "&{$W=$Host.UI.RawUI.WindowSize;$B=$Host.UI.RawUI.BufferSize;$W.Height=33;$B.Height=300;$Host.UI.RawUI.WindowSize=$W;$Host.UI.RawUI.BufferSize=$B;}" >nul 2>&1
)

:dk_prompt

echo.
echo  %cGreen%Notes:%cReset%
echo.
echo  - This script disables the Windows hypervisor, Virtualization-based Security ^(VBS^) and its
echo  dependent features including Memory Integrity, Credential Guard, System Guard and the Windows
echo  Hello protection. Only features that are currently active will be modified.
echo.
echo  - On older Intel CPUs ^(and rarely, older AMD CPUs^), KVA Shadow will also be disabled as it
echo  conflicts with our syscall hook implementation.
echo.
echo  %cRedHL%- Disable Windows Hello ^(PIN, fingerprint or facial recognition^) before continuing.%cReset%
echo  %cRedHL%Failure to do so may require it to be set up again after the script runs.%cReset%
echo.
echo  %cRedHL%- Most kernel anti-cheats do not function with driver signature enforcement disabled.%cReset%
echo  %cRedHL%Vanguard may trigger a BSOD after disabling driver signature enforcement. FACEIT AC%cReset%
echo  %cRedHL%may also prevent the driver from starting. Most kernel anti-cheats do not function with DSE disabled.%cReset%
echo.
echo  %cBlueHL%- If affected, it is recommended to uninstall the problematic anti-cheat.%cReset%
echo.
echo  - This script must be run before each play session, as driver signature enforcement
echo  is only disabled for one boot cycle.
echo.
echo  %cGreen%- All changes can be fully reverted using the Revert Changes option.%cReset%
echo( ________________________________________________________________________
echo.
echo  - Save your work before continuing, as you will be asked to restart.
echo.
echo  - When restarting, you will need to disable driver signature enforcement by pressing F7 on your keyboard
echo  within the Startup Settings.
echo( ________________________________________________________________________
echo.
if /i "!dk_auto_mode!"=="continue" goto :dk_showosinfo
if /i "!dk_auto_mode!"=="revert" goto :dk_revert
choice /C:123 /N /M "[1] Continue [2] Exit [3] Revert Changes:
if !errorlevel!==2 exit /b
if !errorlevel!==3 goto :dk_revert

:dk_showosinfo

cls

set "haderror=0"

echo.
echo Checking OS Info                        [!winos! ^| !fullbuild! ^| !osarch!]
echo Initiating Diagnostic Tests...

:: This check is not always reliable, as the Windows hypervisor and other silicon assisted security features, such as Virtualization-based security (VBS), also use the CPU's virtualization extensions. See https://devblogs.microsoft.com/oldnewthing/20201216-00/?p=104550

set "vtx=0"
set "hvpresent=0"
for /f "delims=" %%s in ('powershell -nop -c "(gcim Win32_ComputerSystem).HypervisorPresent"') do (
    if /i "%%s"=="True" set "hvpresent=1"
)
for /f "delims=" %%s in ('powershell -nop -c "(Get-CimInstance -ClassName Win32_Processor).VirtualizationFirmwareEnabled"') do (
    if /i "%%s"=="True" set "vtx=1"
)

if "!hvpresent!"=="1" set "vtx=1"

if "!vtx!"=="1" (
    echo.
    echo Checking Virtualization                 %cGreen%[Enabled]%cReset%
) else (
    echo.
    echo %cRedHL%Virtualization ^(VT-x/SVM^) is not enabled in BIOS.%cReset%
	echo.
    echo %cRedHL%Please enable it in your BIOS/UEFI settings.%cReset%
    echo.
    echo %cYellow%Press any key to exit...%cReset%
    pause >nul
    exit /b
)

set "dgquery="
for /f "delims=" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /s 2^>nul') do set "dgquery=1"

:: This script does not support disabling security features that are UEFI locked or configured to run in mandatory mode.

:: Windows Hello, if enabled on Windows 11 while Virtualization-based Security, Credential Guard, Device Guard, or other silicon assisted security features are enabled and running, will be protected. Disabling this protection while Windows Hello is active will result in a "Something happened and your PIN isn't available. Click to set up your PIN again." message on the next login, in the case of a PIN. A slightly different, but similar message also appears for fingerprint and facial recognition.

:: This disables Virtualization-based Security. Setting the EnableVirtualizationBasedSecurity value to 0 under HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard usually turns it off.

:: This disables System Guard Secure Launch. Setting the Enabled value to 0 under HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard usually turns it off.

:: This disables Memory Integrity, also known as Hypervisor-protected Code Integrity. Setting the Enabled value to 0 under HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity usually turns it off.

:: This disables Credential Guard. Setting the LsaCfgFlags value to 0 under HKLM\SYSTEM\CurrentControlSet\Control\Lsa and HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard usually turns it off. Setting the CredGuardEnabled value to 0 under HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KeyGuard\Status prevents it from turning back on.

:: None of the aforementioned features will be modified if they are detected as not running or unsupported. For example, System Guard Secure Launch is only available on Windows Pro or higher and requires Intel vPro processors starting with Intel Coffee Lake / Whiskey Lake or AMD processors starting with Zen 2 or later silicon, as mentioned in https://learn.microsoft.com/en-us/windows/security/hardware-security/how-hardware-based-root-of-trust-helps-protect-windows?source=recommendations#windows-edition-and-licensing-requirements

:: This behavior is well acknowledged by Microsoft, which documents that virtualization applications may not work correctly when Hyper-V, Device Guard, or Credential Guard are enabled. Microsoft provides guidance on disabling these features when required. https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v

:: Broadcom, through its VMware lineup, also provides an article with steps to disable these security features, as they are not compatible with their virtualization software. https://knowledge.broadcom.com/external/article/315385

if defined dgquery (

    set "vbslocked="
    set "hvcilocked="
    set "cglocked="
    set "mandatorylocked="
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v Locked 2^>nul') do if "%%A"=="0x1" set "vbslocked=1"
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Locked 2^>nul') do if "%%A"=="0x1" set "hvcilocked=1"
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags 2^>nul') do if "%%A"=="0x1" set "cglocked=1"
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v Mandatory 2^>nul') do if "%%A"=="0x1" set "mandatorylocked=1"

	set "anylocked="
    if defined vbslocked set "anylocked=1"
    if defined hvcilocked set "anylocked=1"
    if defined cglocked set "anylocked=1"
    if defined anylocked (
	
        set "uefiagreed="
        reg query "HKLM\SOFTWARE\ManageVBS" /v UEFILockAgreed >nul 2>&1
        if "!errorlevel!"=="0" set "uefiagreed=1"
		if not defined uefiagreed (
            echo.
            echo %cRedHL%One or more security features are protected by a UEFI lock.%cReset%
            echo %cRedHL%Only proceed on personal devices. Do not proceed on work, school or managed devices.%cReset%
            echo %cRedHL%Removing UEFI locks may violate your organization's security policies.%cReset%
            echo.
            choice /C:12 /N /M "[1] Continue [2] Exit:
            if !errorlevel!==2 exit /b
			%psc% "$k=Add-Type -PassThru -MemberDefinition '[DllImport(\"kernel32.dll\")]public static extern bool SetConsoleMode(IntPtr h,uint m);[DllImport(\"kernel32.dll\")]public static extern IntPtr GetStdHandle(int h);' -Name k -Namespace w;$k::SetConsoleMode($k::GetStdHandle(-11),7)" >nul 2>&1
            reg add "HKLM\SOFTWARE\ManageVBS" /v UEFILockAgreed /t REG_DWORD /d 1 /f >nul 2>&1
        )
		
		cls
		
        if not exist "%SystemRoot%\System32\SecConfig.efi" (
            echo.
            echo %cRedHL%SecConfig.efi was not found on this system.%cReset%
            echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
            echo.
            echo %cYellow%Press any key to exit...%cReset%
            pause >nul
            exit /b
        )
		
        set "freedrive="
        for %%D in (S T U V W X Y Z) do (
            if not defined freedrive (
                if not exist %%D:\ set "freedrive=%%D:"
            )
        )
		
        if not defined freedrive (
            echo.
            echo %cRedHL%No available drive letter found for EFI partition mount.%cReset%
            echo %cRedHL%Please unmount a drive assigned to a letter between S and Z and try again.%cReset%
            echo.
            echo %cYellow%Press any key to exit...%cReset%
            pause >nul
            exit /b
        )
		
    )

    if defined vbslocked (
        echo.
        echo %cYellow%Virtualization-based Security ^(VBS^) is protected by a UEFI lock.%cReset%
        echo %cYellow%Attempting to disable via SecConfig.efi...%cReset%
        echo.
        echo %cYellow%VBS protected by a UEFI lock can only be disabled for one boot cycle on managed devices.%cReset%

        set "secfailed="

        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v EnableVirtualizationBasedSecurity /f >nul 2>&1
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v RequirePlatformSecurityFeatures /f >nul 2>&1
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /f >nul 2>&1
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /f >nul 2>&1

        mountvol !freedrive! /s >nul 2>&1 || set "secfailed=1"
        copy "%SystemRoot%\System32\SecConfig.efi" "!freedrive!\EFI\Microsoft\Boot\SecConfig.efi" >nul 2>&1 || set "secfailed=1"

        if not defined secfailed (
            bcdedit /delete {0cb3b571-2f2e-4343-a879-d86a476d7215} >nul 2>&1
            bcdedit /create {0cb3b571-2f2e-4343-a879-d86a476d7215} /d "DGOptOut" /application osloader >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} path "\EFI\Microsoft\Boot\SecConfig.efi" >nul 2>&1 || set "secfailed=1"
            bcdedit /set {bootmgr} bootsequence {0cb3b571-2f2e-4343-a879-d86a476d7215} >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} loadoptions DISABLE-LSA-ISO,DISABLE-VBS >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} device partition=!freedrive! >nul 2>&1 || set "secfailed=1"
        )

        mountvol !freedrive! /d >nul 2>&1

        if not defined secfailed (
            echo.
            echo %cGreen%UEFI lock will be cleared on next boot via SecConfig.efi.%cReset%
            echo %cYellow%You will need to confirm the opt-out prompt during the next boot.%cReset%
            reg add "HKLM\SOFTWARE\ManageVBS" /v VBSLocked /t REG_DWORD /d 1 /f >nul 2>&1
        ) else (
            echo.
            echo %cRedHL%Failed to set up SecConfig.efi. VBS UEFI lock could not be cleared.%cReset%
            echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
            echo.
            echo %cYellow%Press any key to exit...%cReset%
            pause >nul
            exit /b
        )
    )

    if defined hvcilocked (
        echo.
        echo %cYellow%Memory Integrity ^(HVCI^) is protected by a UEFI lock.%cReset%
        echo %cYellow%Attempting to disable via SecConfig.efi...%cReset%
        echo.
        echo %cYellow%HVCI protected by a UEFI lock can only be disabled for one boot cycle on managed devices.%cReset%

        set "secfailed="

        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /f >nul 2>&1

        mountvol !freedrive! /s >nul 2>&1 || set "secfailed=1"
        copy "%SystemRoot%\System32\SecConfig.efi" "!freedrive!\EFI\Microsoft\Boot\SecConfig.efi" >nul 2>&1 || set "secfailed=1"

        if not defined secfailed (
            bcdedit /delete {0cb3b571-2f2e-4343-a879-d86a476d7215} >nul 2>&1
            bcdedit /create {0cb3b571-2f2e-4343-a879-d86a476d7215} /d "DGOptOut" /application osloader >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} path "\EFI\Microsoft\Boot\SecConfig.efi" >nul 2>&1 || set "secfailed=1"
            bcdedit /set {bootmgr} bootsequence {0cb3b571-2f2e-4343-a879-d86a476d7215} >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} loadoptions DISABLE-LSA-ISO,DISABLE-VBS >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} device partition=!freedrive! >nul 2>&1 || set "secfailed=1"
        )

        mountvol !freedrive! /d >nul 2>&1

        if not defined secfailed (
            echo.
            echo %cGreen%UEFI lock will be cleared on next boot via SecConfig.efi.%cReset%
            echo %cYellow%You will need to confirm the opt-out prompt during the next boot.%cReset%
            reg add "HKLM\SOFTWARE\ManageVBS" /v HVCILocked /t REG_DWORD /d 1 /f >nul 2>&1
        ) else (
            echo.
            echo %cRedHL%Failed to set up SecConfig.efi. HVCI UEFI lock could not be cleared.%cReset%
            echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
            echo.
            echo %cYellow%Press any key to exit...%cReset%
            pause >nul
            exit /b
        )
    )

    if defined cglocked (
        echo.
        echo %cYellow%Credential Guard is protected by a UEFI lock.%cReset%
        echo %cYellow%Attempting to disable via SecConfig.efi...%cReset%

        set "secfailed="

        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /f >nul 2>&1
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v LsaCfgFlags /f >nul 2>&1

        mountvol !freedrive! /s >nul 2>&1 || set "secfailed=1"
        copy "%SystemRoot%\System32\SecConfig.efi" "!freedrive!\EFI\Microsoft\Boot\SecConfig.efi" >nul 2>&1 || set "secfailed=1"

        if not defined secfailed (
            bcdedit /delete {0cb3b571-2f2e-4343-a879-d86a476d7215} >nul 2>&1
            bcdedit /create {0cb3b571-2f2e-4343-a879-d86a476d7215} /d "DGOptOut" /application osloader >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} path "\EFI\Microsoft\Boot\SecConfig.efi" >nul 2>&1 || set "secfailed=1"
            bcdedit /set {bootmgr} bootsequence {0cb3b571-2f2e-4343-a879-d86a476d7215} >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} loadoptions DISABLE-LSA-ISO >nul 2>&1 || set "secfailed=1"
            bcdedit /set {0cb3b571-2f2e-4343-a879-d86a476d7215} device partition=!freedrive! >nul 2>&1 || set "secfailed=1"
        )

        mountvol !freedrive! /d >nul 2>&1

        if not defined secfailed (
            echo.
            echo %cGreen%UEFI lock will be cleared on next boot via SecConfig.efi.%cReset%
            echo %cYellow%You will need to confirm the opt-out prompt during the next boot.%cReset%
            reg add "HKLM\SOFTWARE\ManageVBS" /v CGLocked /t REG_DWORD /d 1 /f >nul 2>&1
        ) else (
            echo.
            echo %cRedHL%Failed to set up SecConfig.efi. Credential Guard UEFI lock could not be cleared.%cReset%
            echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
            echo.
            echo %cYellow%Press any key to exit...%cReset%
            pause >nul
            exit /b
        )
    )

    if defined mandatorylocked (
        echo.
        echo %cYellow%VBS and HVCI are running in mandatory mode.%cReset%
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v Mandatory /t REG_DWORD /d 0 /f >nul 2>&1
        if "!errorlevel!"=="0" (
            echo.
            echo %cGreen%Mandatory mode disabled successfully.%cReset%
        ) else (
            echo.
            echo %cRedHL%Failed to disable mandatory mode.%cReset%
            echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
            echo.
            echo %cYellow%Press any key to exit...%cReset%
            pause >nul
            exit /b
        )
    )

    set "winhello="
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled 2^>nul') do (
        if "%%A"=="0x1" set "winhello=1"
    )
    if defined winhello (
	    echo.
        echo Checking Windows Hello Protection       %cYellow%[Found]%cReset%
        reg add "HKLM\SOFTWARE\ManageVBS" /v WindowsHello /t REG_DWORD /d 1 /f >nul
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 0 /f >nul
        if "!errorlevel!"=="0" (
            echo Disabling Windows Hello Protection      %cGreen%[Successful]%cReset%
        ) else (
            echo Disabling Windows Hello Protection      %cRed%[Failed]%cReset%
            reg delete "HKLM\SOFTWARE\ManageVBS" /v WindowsHello /f >nul 2>&1
			set "haderror=1"
        )
    )
	
	set "secbio="
	for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureBiometrics" /v Enabled 2^>nul') do (
		if "%%A"=="0x1" set "secbio=1"
	)
	if defined secbio (
	    echo.
		echo Checking Enhanced Sign-in Security      %cYellow%[Found]%cReset%
		reg add "HKLM\SOFTWARE\ManageVBS" /v SecureBiometrics /t REG_DWORD /d 1 /f >nul 2>&1
		reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureBiometrics" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
		if "!errorlevel!"=="0" (
			echo Disabling Enhanced Sign-in Security     %cGreen%[Successful]%cReset%
		) else (
			echo Disabling Enhanced Sign-in Security     %cRed%[Failed]%cReset%
			reg delete "HKLM\SOFTWARE\ManageVBS" /v SecureBiometrics /f >nul 2>&1
			set "haderror=1"
		)
	)

    set "vbsstate="
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity 2^>nul') do (
        set "vbsstate=%%A"
    )
    if "!vbsstate!"=="0x1" (
	    echo.
        echo Checking Virtualization-based Security  %cYellow%[Found]%cReset%
        reg add "HKLM\SOFTWARE\ManageVBS" /v VBS /t REG_DWORD /d 1 /f >nul
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f >nul
        if "!errorlevel!"=="0" (
            echo Disabling Virtualization-based Security %cGreen%[Successful]%cReset%
        ) else (
            echo Disabling Virtualization-based Security %cRed%[Failed]%cReset%
            reg delete "HKLM\SOFTWARE\ManageVBS" /v VBS /f >nul 2>&1
			set "haderror=1"
        )
    )

    set "sysguard="
    for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard" /v Enabled 2^>nul') do (
        if "%%A"=="0x1" set "sysguard=1"
    )
    if defined sysguard (
	    echo.
        echo Checking System Guard                   %cYellow%[Found]%cReset%
        reg add "HKLM\SOFTWARE\ManageVBS" /v SystemGuard /t REG_DWORD /d 1 /f >nul
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard" /v Enabled /t REG_DWORD /d 0 /f >nul
        if "!errorlevel!"=="0" (
            echo Disabling System Guard                  %cGreen%[Successful]%cReset%
        ) else (
            echo Disabling System Guard                  %cRed%[Failed]%cReset%
            reg delete "HKLM\SOFTWARE\ManageVBS" /v SystemGuard /f >nul 2>&1
			set "haderror=1"
        )
    )

    set "hvcirunning=0"
    for /f "delims=" %%s in ('powershell -nop -c "(Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard).SecurityServicesRunning" 2^>nul') do (
        if "%%s"=="2" set "hvcirunning=1"
    )
    if "!hvcirunning!"=="1" (
	    echo.
        echo Checking Memory Integrity ^(HVCI^)        %cYellow%[Found]%cReset%
        reg add "HKLM\SOFTWARE\ManageVBS" /v HVCI /t REG_DWORD /d 1 /f >nul
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f >nul
        if "!errorlevel!"=="0" (
            echo Disabling Memory Integrity ^(HVCI^)       %cGreen%[Successful]%cReset%
        ) else (
            echo Disabling Memory Integrity ^(HVCI^)       %cRed%[Failed]%cReset%
            reg delete "HKLM\SOFTWARE\ManageVBS" /v HVCI /f >nul 2>&1
			set "haderror=1"
        )
    )

    set "cgrunning=0"
    for /f "delims=" %%s in ('powershell -nop -c "(Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard).SecurityServicesRunning" 2^>nul') do (
        if "%%s"=="1" set "cgrunning=1"
    )
    if "!cgrunning!"=="1" (
	    echo.
        echo Checking Credential Guard               %cYellow%[Found]%cReset%
        reg add "HKLM\SOFTWARE\ManageVBS" /v CredentialGuard /t REG_DWORD /d 1 /f >nul
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 0 /f >nul
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v LsaCfgFlags /t REG_DWORD /d 0 /f >nul
        if "!errorlevel!"=="0" (
            echo Disabling Credential Guard              %cGreen%[Successful]%cReset%
        ) else (
            echo Disabling Credential Guard              %cRed%[Failed]%cReset%
            reg delete "HKLM\SOFTWARE\ManageVBS" /v CredentialGuard /f >nul 2>&1
			set "haderror=1"
        )
    )
)

:: Disables KVA Shadow (Meltdown mitigation) by adding the override keys, as it conflicts with our syscall hook implementation.

:: This is for older Intel CPUs, and in some rare cases older AMD CPUs too, as newer ones are architecturally fixed against Meltdown.

:: This disables the Meltdown protection the same way InSpectre does, https://www.grc.com/inspectre.htm

:dk_kva
set "kvarequired="
set "kvafailed="
for /f "delims=" %%s in ('powershell -nop -c "$d=Add-Type -MemberDefinition '[DllImport(\"ntdll.dll\")] public static extern int NtQuerySystemInformation(uint a,IntPtr b,uint c,IntPtr d);' -Name n -Namespace w -PassThru;$p=[Runtime.InteropServices.Marshal]::AllocHGlobal(4);$r=[Runtime.InteropServices.Marshal]::AllocHGlobal(4);$ret=$d::NtQuerySystemInformation(196,$p,4,$r);if($ret -eq 0){$f=[uint32][Runtime.InteropServices.Marshal]::ReadInt32($p);if(($f -band 0x01)-ne 0 -or (($f -band 0x20)-ne 0 -and ($f -band 0x10)-ne 0)){Write-Output 1}else{Write-Output 0}}else{Write-Output 0}" 2^>nul') do (
    if "%%s"=="1" set "kvarequired=1"
)

if not defined kvarequired goto :dk_hypervisor

set "kvaalready="
set "kvaval1="
set "kvaval2="
for /f "tokens=3" %%A in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride 2^>nul') do set "kvaval1=%%A"
for /f "tokens=3" %%A in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask 2^>nul') do set "kvaval2=%%A"
if "!kvaval1!"=="0x2" if "!kvaval2!"=="0x3" set "kvaalready=1"

if not defined kvaalready (
    echo.
    echo Checking KVA Shadow                     %cYellow%[Found]%cReset%
    set "kvafailed="
    reg add "HKLM\SOFTWARE\ManageVBS" /v KVAShadow /t REG_DWORD /d 1 /f >nul 2>&1 || set "kvafailed=1"
    reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 2 /f >nul 2>&1 || set "kvafailed=1"
    reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f >nul 2>&1 || set "kvafailed=1"
    if not defined kvafailed (
        echo Disabling KVA Shadow                    %cGreen%[Successful]%cReset%
    ) else (
        echo Disabling KVA Shadow                    %cRed%[Failed]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v KVAShadow /f >nul 2>&1
        set "haderror=1"
    )
)

:: Disables the Windows Hypervisor using bcdedit /set hypervisorlaunchtype off

:dk_hypervisor
set "hypbcd="
set "hypneeded="
set "hypfailed="
for /f "tokens=2" %%A in ('bcdedit /enum {current} 2^>nul ^| findstr /i "hypervisorlaunchtype"') do set "hypbcd=%%A"

if not defined hypbcd (
    set "hypvbs="
    set "hyphyp="
    for /f "delims=" %%s in ('powershell -nop -c "(Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard).VirtualizationBasedSecurityStatus" 2^>nul') do (
        if "%%s"=="1" set "hypvbs=1"
        if "%%s"=="2" set "hypvbs=1"
    )
    for /f "delims=" %%s in ('powershell -nop -c "(Get-CimInstance Win32_ComputerSystem).HypervisorPresent" 2^>nul') do (
        if /i "%%s"=="True" set "hyphyp=1"
    )
    if defined hypvbs if defined hyphyp set "hypneeded=1"
) else (
    if /i "!hypbcd!"=="Auto" set "hypneeded=1"
    if /i "!hypbcd!"=="On" set "hypneeded=1"
)

if defined hypneeded (
    echo.
    echo Checking Windows Hypervisor             %cYellow%[Found]%cReset%
    reg add "HKLM\SOFTWARE\ManageVBS" /v Hypervisor /t REG_DWORD /d 1 /f >nul 2>&1 || set "hypfailed=1"
    if defined hypbcd (
        reg add "HKLM\SOFTWARE\ManageVBS" /v HypervisorLaunchType /t REG_SZ /d "!hypbcd!" /f >nul 2>&1
    )
    bcdedit /set hypervisorlaunchtype off >nul 2>&1 || set "hypfailed=1"
    if not defined hypfailed (
        echo Disabling Windows Hypervisor            %cGreen%[Successful]%cReset%
    ) else (
        echo Disabling Windows Hypervisor            %cRed%[Failed]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v Hypervisor /f >nul 2>&1
        reg delete "HKLM\SOFTWARE\ManageVBS" /v HypervisorLaunchType /f >nul 2>&1
        set "haderror=1"
    )
)

:: Warns the user if Smart App Control is enabled or in evaluation mode.

set "sacstate="
if !winbuild! GEQ 22621 (
    for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v VerifiedAndReputablePolicyState 2^>nul') do (
        set "sacstate=%%a"
    )
)

if defined sacstate (
    if "!sacstate!"=="0x1" (
	    echo.
        echo Checking Smart App Control              %cYellow%[Enabled]%cReset%
        echo.
        echo %cGreyHL%Smart App Control may block certain applications.%cReset%
        echo %cGreyHL%You may need to disable it in Windows Security.%cReset%
    )
    if "!sacstate!"=="0x2" (
	    echo.
        echo Checking Smart App Control              %cYellow%[Evaluation]%cReset%
        echo.
        echo %cGreyHL%Smart App Control may enable itself after evaluation.%cReset%
        echo %cGreyHL%It is recommended to disable it in Windows Security.%cReset%
    )
)

if "!haderror!"=="1" (
    echo.
    echo %cRedHL%Some errors were detected.%cReset%
    echo.
    echo %cRedHL%Run the "Revert Changes" option to restore the previous state.%cReset%
    echo.
    echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
    echo.
    echo %cYellow%Press any key to exit...%cReset%
    pause >nul
    exit /b
)
if "!cgrunning!"=="1" if !winbuild! LEQ 19045 goto :cg_reboot

:: Suspends BitLocker, if enabled, for one reboot to avoid recovery when booting into Startup Settings.

call :dk_bitlocker
if "!blprotected!"=="1" (
    manage-bde -protectors -disable %SystemDrive% -rebootcount 1 >nul 2>&1
    if "!errorlevel!"=="0" (
	    echo(________________________________________________________________________
		echo.
        echo %cBlueHL%BitLocker was detected on this system.%cReset%
        echo.
        echo %cBlueHL%To allow access to Startup Settings without requiring the recovery key, BitLocker protection has been temporarily%cReset%
		echo %cBlueHL%suspended for one reboot. Encryption is still active.%cReset%
    ) else (
        echo %cRedHL%Failed to suspend BitLocker. Aborting.%cReset%
        echo.
        echo %cRedHL%Run the "Revert Changes" option to restore the previous state.%cReset%
        echo.
		echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
		echo.
        echo %cYellow%Press any key to exit...%cReset%
        pause >nul
        exit /b
    )
)
echo(________________________________________________________________________
echo.
echo %cBlueHL%A restart is required to apply changes.%cReset%
echo.
echo %cBlueHL%When booting, you will need to disable driver signature enforcement by pressing F7 within the Startup Settings.%cReset%
echo(________________________________________________________________________
bcdedit /set {current} onetimeadvancedoptions on >nul
echo.
call :dk_restart_prompt
exit /b

:cg_reboot

:: Suspends BitLocker, if enabled, for two reboots to avoid recovery when booting into Startup Settings.

call :dk_bitlocker
if "!blprotected!"=="1" (
    manage-bde -protectors -disable %SystemDrive% -rebootcount 2 >nul 2>&1
    if "!errorlevel!"=="0" (
	    echo(________________________________________________________________________
		echo.
        echo %cBlueHL%BitLocker was detected on this system.%cReset%
        echo.
        echo %cBlueHL%To allow access to Startup Settings without requiring the recovery key, BitLocker protection has been temporarily%cReset%
		echo %cBlueHL%suspended for two reboots. Encryption is still active.%cReset%
    ) else (
        echo %cRedHL%Failed to suspend BitLocker. Aborting.%cReset%
        echo.
        echo %cRedHL%Run the "Revert Changes" option to restore the previous state.%cReset%
        echo.
		echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
		echo.
        echo %cYellow%Press any key to exit...%cReset%
        pause >nul
        exit /b
    )
)
echo(________________________________________________________________________
echo.
echo %cBlueHL%If Credential Guard is active on Windows 10, two system restarts are required to completely disable VBS.%cReset%
echo.
echo %cBlueHL%On the second boot, you will need to disable driver signature enforcement by pressing F7 within the Startup Settings.%cReset%
echo(________________________________________________________________________
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "Reboot1" /t REG_SZ /d "bcdedit /set {current} onetimeadvancedoptions on" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "Reboot2" /t REG_SZ /d "shutdown /r /t 0" /f >nul
echo.
call :dk_restart_prompt
exit /b

:: This section reverts the changes made by the primary part of the script. Only the security features that were previously disabled are re-enabled. Since not all hardware or Windows editions support the same silicon assisted security features, the script records any disabled features under HKLM\SOFTWARE\ManageVBS so it can restore only those settings. This is done because Windows does not always safely ignore unsupported registry keys.

:dk_revert

cls

set "haderror=0"

echo.
echo Checking OS Info                        [!winos! ^| !fullbuild! ^| !osarch!]
echo Reverting changes...

set "mvbs_hasvalues=0"
for /f "skip=2" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" 2^>nul') do set "mvbs_hasvalues=1"
if "!mvbs_hasvalues!"=="0" (
    echo.
    echo %cYellow%No changes have been made. Press any key to exit...%cReset%
    pause >nul
    exit /b
)

set "revert_vbslocked="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v VBSLocked 2^>nul') do set "revert_vbslocked=%%A"
if "!revert_vbslocked!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v Locked /t REG_DWORD /d 1 /f >nul 2>&1
    if "!errorlevel!"=="0" (
        echo.
        echo Enabling VBS UEFI Lock                  %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v VBSLocked /f >nul 2>&1
    ) else (
        echo.
        echo Enabling VBS UEFI Lock                  %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

set "revert_hvcilocked="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v HVCILocked 2^>nul') do set "revert_hvcilocked=%%A"
if "!revert_hvcilocked!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Locked /t REG_DWORD /d 1 /f >nul 2>&1
    if "!errorlevel!"=="0" (
        echo.
        echo Enabling HVCI UEFI Lock                 %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v HVCILocked /f >nul 2>&1
    ) else (
        echo.
        echo Enabling HVCI UEFI Lock                 %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

set "revert_cglocked="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v CGLocked 2^>nul') do set "revert_cglocked=%%A"
if "!revert_cglocked!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 3 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 1 /f >nul 2>&1
    if "!errorlevel!"=="0" (
        echo.
        echo Enabling Credential Guard UEFI Lock     %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v CGLocked /f >nul 2>&1
    ) else (
        echo.
        echo Enabling Credential Guard UEFI Lock     %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: Restores the Windows Hypervisor launch type to its original state via boot configuration.

:: If it was explicitly set before, it is restored to that value. If it was not set, the entry is deleted to return to the default state.

set "revert_hyp="
set "revert_hyptype="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v Hypervisor 2^>nul') do set "revert_hyp=%%A"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v HypervisorLaunchType 2^>nul') do set "revert_hyptype=%%A"
if "!revert_hyp!"=="0x1" (
	if "!revert_hyptype!"=="" (
		bcdedit /deletevalue {current} hypervisorlaunchtype >nul 2>&1
	) else (
		bcdedit /set hypervisorlaunchtype !revert_hyptype! >nul 2>&1
	)
    if "!errorlevel!"=="0" (
        echo.
        echo Enabling Windows Hypervisor             %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v Hypervisor /f >nul 2>&1
        reg delete "HKLM\SOFTWARE\ManageVBS" /v HypervisorLaunchType /f >nul 2>&1
    ) else (
        echo.
        echo Enabling Windows Hypervisor             %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: This is the official, documented method to enable Virtualization-based Security (VBS), as described by Microsoft under "To enable VBS only (no memory integrity):" at https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity?tabs=reg#enable-memory-integrity-using-registry

set "revert_vbs="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v VBS 2^>nul') do set "revert_vbs=%%A"
if "!revert_vbs!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f >nul
    if "!errorlevel!"=="0" (
	    echo.
        echo Enabling Virtualization-based Security  %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v VBS /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling Virtualization-based Security  %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: This is the official, documented method to enable memory integrity, as described by Microsoft under "To enable memory integrity:" at https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity?tabs=reg#enable-memory-integrity-using-registry

set "revert_hvci="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v HVCI 2^>nul') do set "revert_hvci=%%A"
if "!revert_hvci!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 1 /f >nul
    if "!errorlevel!"=="0" (
	    echo.
        echo Enabling Memory Integrity ^(HVCI^)        %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v HVCI /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling Memory Integrity ^(HVCI^)        %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: As mentioned before, Windows Hello, if enabled while Virtualization-based Security, Credential Guard, Device Guard, or any other silicon assisted security features are enabled and running, will remain protected. Disabling this protection while Windows Hello is active will result in a "Something happened and your PIN isn't available. Click to set up your PIN again." message on the next login, in the case of a PIN. A slightly different, but similar message also appears for fingerprint and facial recognition.

:: This does not re-enable Windows Hello itself, rather just its Device Guard registry key.

set "revert_wh="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v WindowsHello 2^>nul') do set "revert_wh=%%A"
if "!revert_wh!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 1 /f >nul
    if "!errorlevel!"=="0" (
	    echo.
        echo Enabling Windows Hello Protection       %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v WindowsHello /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling Windows Hello Protection       %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

set "revert_sb="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v SecureBiometrics 2^>nul') do set "revert_sb=%%A"
if "!revert_sb!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureBiometrics" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1
    if "!errorlevel!"=="0" (
	    echo.
        echo Enabling Enhanced Sign-in Security      %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v SecureBiometrics /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling Enhanced Sign-in Security      %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: System Guard Secure Launch is another of Microsoft's silicon assisted security features. This is the official, documented method to enable System Guard Secure Launch, as described by Microsoft at https://learn.microsoft.com/en-us/windows/security/hardware-security/system-guard-secure-launch-and-smm-protection#registry

set "revert_sg="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v SystemGuard 2^>nul') do set "revert_sg=%%A"
if "!revert_sg!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard" /v Enabled /t REG_DWORD /d 1 /f >nul
    if "!errorlevel!"=="0" (
	    echo.
        echo Enabling System Guard                   %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v SystemGuard /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling System Guard                   %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: Enables Credential Guard without lock 

:: Starting in Windows 11, 22H2 and Windows Server 2025, VBS and Credential Guard are enabled by default on devices that meet the requirements. The default enablement is without UEFI Lock, which is the same enablement used in this script. You can learn more about this at https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/#default-enablement

:: This is the official, documented way Microsoft has demonstrated. See "Configure Credential Guard with registry settings" at https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/configure?tabs=reg#configure-credential-guard-with-registry-settings

set "revert_cg="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v CredentialGuard 2^>nul') do set "revert_cg=%%A"
if "!revert_cg!"=="0x1" (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 2 /f >nul
    reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v LsaCfgFlags >nul 2>&1
    if "!errorlevel!"=="0" reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v LsaCfgFlags /f >nul 2>&1
    if "!errorlevel!"=="0" (
	    echo.
        echo Enabling Credential Guard               %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v CredentialGuard /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling Credential Guard               %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: Restores KVA Shadow (Meltdown mitigation) by removing the override keys

:: You can learn more about how KVA Shadow mitigates Meltdown at https://www.microsoft.com/en-us/msrc/blog/2018/03/kva-shadow-mitigating-meltdown-on-windows

set "revert_kva="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" /v KVAShadow 2^>nul') do set "revert_kva=%%A"
if "!revert_kva!"=="0x1" (
    set "kva1=0"
    set "kva2=0"
    reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride >nul 2>&1
    if "!errorlevel!"=="0" (
        reg delete "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /f >nul 2>&1
        if "!errorlevel!"=="0" set "kva1=1"
    ) else (
        set "kva1=1"
    )
    reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask >nul 2>&1
    if "!errorlevel!"=="0" (
        reg delete "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /f >nul 2>&1
        if "!errorlevel!"=="0" set "kva2=1"
    ) else (
        set "kva2=1"
    )
    if "!kva1!"=="1" if "!kva2!"=="1" (
	    echo.
        echo Enabling KVA Shadow                     %cGreen%[Successful]%cReset%
        reg delete "HKLM\SOFTWARE\ManageVBS" /v KVAShadow /f >nul 2>&1
    ) else (
	    echo.
        echo Enabling KVA Shadow                     %cRed%[Failed]%cReset%
        set "haderror=1"
    )
)

:: Removes the ManageVBS tracking key if all features were successfully re-enabled. If any failed, the key is kept so the user can run Revert Changes again.

set "mvbs_remaining=0"
for /f "skip=2" %%A in ('reg query "HKLM\SOFTWARE\ManageVBS" 2^>nul') do set "mvbs_remaining=1"
if "!mvbs_remaining!"=="0" reg delete "HKLM\SOFTWARE\ManageVBS" /f >nul 2>&1

if "!haderror!"=="1" (
    echo.
    echo %cRedHL%Some errors were detected.%cReset%
    echo.
    echo %cBlueHL%Check this webpage for help - %cReset% %cYellow%https://cs.rin.ru/forum/viewtopic.php?f=14^&t=156435%cReset%
)
echo(________________________________________________________________________
echo.
echo %cBlueHL%A restart is required to apply changes.%cReset%
echo(________________________________________________________________________
echo.
call :dk_restart_prompt
exit /b

:dk_restart_prompt
if "!dk_restart_choice!"=="1" (
    echo [Auto] Restarting now.
    echo.
    shutdown /r /t 0
    exit /b
)
if "!dk_restart_choice!"=="2" (
    echo [Auto] Restart deferred.
    echo.
    exit /b
)
choice /C:12 /N /M "[1] Restart Now [2] Restart Later:
echo.
if !errorlevel!==1 shutdown /r /t 0
exit /b

:: Checks if BitLocker protection is enabled on the OS drive.

:dk_bitlocker

set "blprotected=0"
for /f "delims=" %%s in ('powershell -nop -c "(Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus" 2^>nul') do (
    if "%%s"=="On" set "blprotected=1"
)
exit /b

:: Show OS info.

:dk_sysinfo

set winbuild=1
for /f "tokens=2 delims=[]" %%G in ('ver') do (
    for /f "tokens=2,3,4 delims=. " %%H in ("%%~G") do (
        set "winbuild=%%J"
    )
)

call :dk_reflection

set d1=!ref! $meth = $TypeBuilder.DefinePInvokeMethod('BrandingFormatString', 'winbrand.dll', 'Public, Static', 1, [String], @([String]), 1, 3);
set d1=!d1! $meth.SetImplementationFlags(128); $TypeBuilder.CreateType()::BrandingFormatString('%%WINDOWS_LONG%%') -replace [string][char]0xa9, '' -replace [string][char]0xae, '' -replace [string][char]0x2122, ''

set winos=
for /f "delims=" %%s in ('"%psc% %d1%"') do if not errorlevel 1 set "winos=%%s"
echo "!winos!" | find /i "Windows" >nul 2>&1 || (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "winos=%%b"
    if !winbuild! GEQ 22000 set "winos=!winos:Windows 10=Windows 11!"
)

set "osarch="
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE 2^>nul') do set "osarch=%%b"

set "fullbuild="
for /f "tokens=6-7 delims=[]. " %%i in ('ver') do if not "%%j"=="" (
    set "fullbuild=%%i.%%j"
) else (
    set "UBR="
    for /f "tokens=3" %%G in ('"reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR" 2^>nul') do if not errorlevel 1 set /a "UBR=%%G"
    for /f "skip=2 tokens=3,4 delims=. " %%G in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v BuildLabEx 2^>nul') do (
        if defined UBR (set "fullbuild=%%G.!UBR!") else (set "fullbuild=%%G.%%H")
    )
)
exit /b

:: This is used to build the PowerShell reflection code that calls BrandingFormatString from winbrand.dll to get the Windows product name, which is turn populates !winos! for the Checking OS Info line.

:dk_reflection
set ref=$AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly(4, 1);
set ref=%ref% $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule(2, $False);
set ref=%ref% $TypeBuilder = $ModuleBuilder.DefineType(0);
exit /b
