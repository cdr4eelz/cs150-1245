./rem_files.sh

#Following coregen commands to be uncommented  when the parameter DEBUG_EN is changed from 0 to 1 in mig_xupv5.v/.vhd file.
#coregen -b makeproj.sh
#coregen -p . -b icon4_cg.xco
#coregen -p . -b vio_async_in96_cg.xco
#coregen -p . -b vio_async_in192_cg.xco
#coregen -p . -b vio_sync_out32_cg.xco
#coregen -p . -b vio_async_in100_cg.xco

#rm *.ncf
xtclsh set_ise_prop.tcl
