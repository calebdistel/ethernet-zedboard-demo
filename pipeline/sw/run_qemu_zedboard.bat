@echo off
rem Boots ethernet_udp_app_emu.elf on an emulated ZedBoard (AMD QEMU, Zynq-7000 PS only).
rem   run_qemu_zedboard.bat [path\to\ethernet_udp_app_emu.elf]
rem Default ELF: <project>\vitis_prj\ethernet_udp_app_emu\build\ethernet_udp_app_emu.elf
rem Start the MATLAB receiver (demo\host\fft_udp_receiver.m, UDP 5005) first.
rem Quit QEMU with Ctrl-A, then X.

set QEMU=C:\Xilinx\Vitis\2024.1\data\emulation\qemu_win\qemu\qemu-system-aarch64.exe
set DTB=C:\Xilinx\Vitis\2024.1\data\emulation\dtbs\zynq\zynq-arm.dtb

set ELF=%~1
if "%ELF%"=="" set ELF=%~dp0..\..\vitis_prj\ethernet_udp_app_emu\build\ethernet_udp_app_emu.elf
if not exist "%ELF%" (
  echo ELF not found: %ELF%
  echo Build the ethernet_udp_app_emu component in Vitis first, or pass the ELF path.
  exit /b 1
)

rem The -device loader writes set up the Zynq clock registers (SLCR) the way
rem ps7_init would, so the UART and GEM run at the right rates. The GEM is
rem bridged to the PC through QEMU user networking: the guest's 192.168.50.1
rem is this PC, so UDP to 192.168.50.1:5005 arrives at the local receiver.
"%QEMU%" ^
 -M arm-generic-fdt-7series ^
 -hw-dtb "%DTB%" ^
 -display none -serial null -serial mon:stdio ^
 -device loader,addr=0xf8000008,data=0xDF0D,data-len=4 ^
 -device loader,addr=0xf8000140,data=0x00500801,data-len=4 ^
 -device loader,addr=0xf800012c,data=0x01ed044d,data-len=4 ^
 -device loader,addr=0xf8000108,data=0x0001e008,data-len=4 ^
 -device loader,addr=0xf8000910,data=0xf,data-len=4 ^
 -device loader,addr=0xf8000244,data=0x22,data-len=4 ^
 -device "loader,file=%ELF%,cpu-num=0" ^
 -net nic,model=cadence_gem ^
 -net user,net=192.168.50.0/24,host=192.168.50.1,dhcpstart=192.168.50.100
