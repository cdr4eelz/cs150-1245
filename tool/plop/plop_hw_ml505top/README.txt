Mimics the XPS hardware platform output project (for eclipse or manual use):

plop_hw_ml505top:
system.bit (symlink/copy current build output)
system.bmm (symlink/copy current build _bd.bmm output)
system.xml (copy XPS platform system description file; see below)

plop_bsp:
system.mss (software setup, fiddle with BSP settings or copy from fresh BSP)

--- Procedure to update ---

Following a fresh XPS generation (probably best to skip auto EDK launch):
  Manually update ./system.xml (from ../plop_hw_platform/system.xml).
  Manually update team project embedded MB with minimal XPS output:
    == cd <cs150-xx>/hardware/fun/
    -- rm plop.v plop/*
    ++ cp tool/plop/hdl/plop.v .
    ++ cp tool/plop/implementation/plop_*.ncg
    (update stash tarball with plop/ compiled netlists, checking plop.v directly)
tool/plop/implementation/plop_*.ncf .
  Update .bmm file based on tool/plop/implementation/plop.bmm (optional for injection).
  Rebuild team project to standard location (note BRAMs no longer at TOP).
  Ensure symlinks find bit-file & (optionally) bmm with PLACE/LOC tags.
  In EDK:
    (optional) Use plop directory as workspace.
    Ensure/Import this hw-platform into workspace (system.xml is key).
    Ensure/Create board-support project references this hw-platform:
      BSP's libgen.opt:HWSPEC entry references desired "system.xml".
      (optional) BSP's project-reference to this hw-platform project.
      Fiddle with BSP settings (ensure libraries/settings) & create "system.mss".
      BSP rebuild (likely automatic).
    Ensure/Create application project referencing proper BSP:
      Use "Change Referenced BSP" command if in doubt.
      (detail) Reference is via "project reference" & build-settings "include" & "lib" dirs.
    Proceed with application as usual:
      (choice A) Manually impact system.bit (likely has bootloop).
      (choice B) Use "Program FPGA" to inject an elf (bootloop/other) into download.bit.
      Start xmd debugger & a terminal for UART emulation.
