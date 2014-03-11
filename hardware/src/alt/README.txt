* Debugging tools or special interest features (extensions above/beyond project) *

Coregen based IP can be built fresh from their .xco files (with ezcore),
  OR extracted from the associated stash_xxx.tar.bz2 archives.

XPS/EDK based IP is pulled from the team/tools/ area and referenced minimally here
    as semi-top level verilog and directory of .ngc/.ncf files (pre-synth'd netlists).

"BRK" below represents breakpoint/trace/intercept/inject functionality.  Currently, it
    halts pipelines rather than clearing instructions, like a hardware assisted software
    monitor might do (as with ARM debug features or ICE).  The mipsy exposes a big flat
    bus concatenated from its more curious innerds, and imposes full-stall to mimic break.
    Serial (UART) lines are optionally re-routed through the PLOP for stream injection or
    relay of JTAG-serial access if physical COM is missing.  MicroBlaze Debug Module (MDM)
    has serial relay accessed via "terminal" feature of "xdm".

* Partial file list for reference *

CS: cs_*/ { build_cs | stash_cs.tar.bz2 }
    ChipScope IP cores to facilitate probing and manual BRK (break/trace) control.

OPS: [mult|div]_[un]signed/ { build_ops | stash_ops.tar.bz2 }
    Math to support optional MIPS instructions, mult/multu/div/divu.

PLOP: plop.v minitop.[v|ucf|bmm] { copy from tools/plop/README.txt }
    MicroBlaze CPU for UART relay, hyper-BIOS, or debug console based BRK.

