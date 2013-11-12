stash: exporttosdk #Boy this belongs in a shell script rather than this monster!
        #STASH_D,EXPORT_D,PLAT_D,PLAT_B,PLATs==stash/,export/,plat/,outname,inname#
        mkdir -p "$(STASH_D)"
        for P in $(PLATS); do #BEGIN:line-continuation                                    \
          # PLATFORM "P" DIRECTORIES, NAMES, PREFIXES, ETC. #                            ;\
          PX_D="$(EXPORT_D)/$${P}"  PS_N="$(PLAT_B)_$${P}"  PS_D="$${PX_D}/$${PS_N}"     ;\
          PP_IMP="$(PLAT_D)/implementation/$${P}"  PP_HDL="$(PLAT_D)/hdl/$${P}"          ;\
          # GATHER PLATFORM INTO A COMPOSITE DIRECTORY #                                 ;\
          echo "Stash \"$${P}\" into \"$${PS_D}\":"                                      ;\
          mkdir -p "$${PS_D}" && rm -rf "$${PS_D}/*" #ENSURE DEST DIRECTORY BUT EMPTY    ;\
          # GATHER COMPONENT:NGC/UCF/HDL; TOP:NGC/UCF/PCF/HDL XPS:XML GENERAL:BMM/LOG    ;\
          cp --recursive --target-directory="$${PS_D}/"                                   \
                $${PP_IMP}_*.ngc         $${PP_IMP}_*.ncf            $${PP_HDL}_*         \
                $${PP_IMP}.ngc     $${PP_IMP}.ucf $${PP_IMP}.pcf     $${PP_HDL}.*         \
                $${PP_IMP}_stub.bmm   $${PX_D}/hw/$${P}.xml          $${P}.log           ;\
          # BUILD THE ARCHIVES #                                                         ;\
          echo "Archive w/stub:"                                                         ;\
          tar --exclude="*/$${P}.v" --directory="$${PX_D}"                                \
                -cvjf $(STASH_D)/$${PS_N}_stub.tar.bz2 $${PS_N}                          ;\
          echo "Archive wo/stub:"                                                        ;\
          tar --exclude="*/$${P}_stub.v" --directory="$${PX_D}"                           \
                -cvjf $(STASH_D)/$${PS_N}.tar.bz2 $${PS_N}                               ;\
        done #END:line-continuation
        -cd "$(STASH_D)" && ls -alh . && md5sum $(PLATS:%=$(PLAT_B)_%[._]*)
