### INCLUDE THIS AFTER SETTING $(NAME) ###

vlog xsim.dir : $(NAME).prj $(NAME).v
	xvlog --prj $(NAME).prj --include ..

elab xsim.dir/xil_defaultlib.$(NAME) : xsim.dir
	xelab --debug typical xil_defaultlib.$(NAME)

sim xil_defaultlib.$(NAME).wdb : xsim.dir/xil_defaultlib.$(NAME)
	xsim --gui --view $(NAME).wcfg  xil_defaultlib.$(NAME)

simtxt : xsim.dir/xil_defaultlib.$(NAME)
	xsim --runall xil_defaultlib.$(NAME)


clean :
	rm -rf .Xil xsim.dir *.log *.pb *.jou

.phony: vlog elab sim simtxt clean

