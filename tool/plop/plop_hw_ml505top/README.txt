Mimics the XPS hardware platform output project (for eclipse or manual use):

system.bit: symlink to current build output
system.bmm: symlink to current build _bd.bmm output
system.xml: Manual copy of XPS platform system description output (see below).


--- Procedure to update ---

Following a fresh XPS generation (probably best to skip auto EDK launch):
  Manually update ./system.xml (from ../plop_hw_platform/system.xml).
  Manually update team project embedded MB with minimal XPS output:
    == cd <cs150-xx>/hardware/fun/
    -- rm plop*.v plop*.ncg
    ++ cp tool/plop/hdl/plop.v .
    ++ cp tool/plop/implementation/plop_*.ncg .
  Update .bmm file if MB's RAM has changed shape (optional for downstream injection).
  Rebuild team project to standard location.
  Ensure symlinks find bit-file & (optionally) bmm with current PLACE/LOC tags.
  In EDK:
    (optional) Use plop directory as workspace.
    Ensure/Import this hw-platform into workspace.
    Ensure/Create board-support project references this hw-platform:
      BSP's libgen.opt:HWSPEC entry references desired system.xml file.
      (optional) BSP's project reference to this hw-platform project.
      BSP rebuild (likely automatic).
    Ensure/Create application project referencing proper BSP:
      Use "Change Referenced BSP" command if in doubt.
      (detail) Reference is via "project reference" & build-settings "include" & "lib" dirs.
    Proceed with application as usual:
      (choice A) Manually impact system.bit (likely has bootloop).
      (choice B) Use "Program FPGA" to inject an elf (bootloop/other) into download.bit.
      Start xmd debugger & a terminal for UART emulation.
