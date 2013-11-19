./rem_files.sh

#Following coregen commands to be uncommented  when the parameter DEBUG_EN is changed from 0 to 1 in mig_xupv5.v/.vhd file.
#coregen -b makeproj.sh
#coregen -p . -b icon4_cg.xco
#coregen -p . -b vio_async_in96_cg.xco
#coregen -p . -b vio_async_in192_cg.xco
#coregen -p . -b vio_sync_out32_cg.xco
#coregen -p . -b vio_async_in100_cg.xco

#rm *.ncf
echo Synthesis Tool: XST

mkdir "../synth/__projnav" > ise_flow_results.txt
mkdir "../synth/xst" >> ise_flow_results.txt
mkdir "../synth/xst/work" >> ise_flow_results.txt

xst -ifn xst_run.txt -ofn mem_interface_top.syr -intstyle ise >> ise_flow_results.txt
ngdbuild -intstyle ise -dd ../synth/_ngo -nt timestamp -uc mig_xupv5.ucf -p xc5vlx110tff1136-1 mig_xupv5.ngc mig_xupv5.ngd >> ise_flow_results.txt

map -intstyle ise -detail -w -logic_opt off -ol high -xe n -t 1 -cm area -o mig_xupv5_map.ncd mig_xupv5.ngd mig_xupv5.pcf >> ise_flow_results.txt
par -w -intstyle ise -ol high -xe n mig_xupv5_map.ncd mig_xupv5.ncd mig_xupv5.pcf >> ise_flow_results.txt
trce -e 3 -xml mig_xupv5 mig_xupv5.ncd -o mig_xupv5.twr mig_xupv5.pcf >> ise_flow_results.txt
bitgen -intstyle ise -f mem_interface_top.ut mig_xupv5.ncd >> ise_flow_results.txt

echo done!
