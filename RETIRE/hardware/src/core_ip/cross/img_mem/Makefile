XCO_SRC = $(wildcard *.xco)
V_SRC := $(patsubst %.xco,%.v,$(XCO_SRC))
CG_FLAGS ?= -intstyle silent

ifndef $(IMG_NAME)
	IMG_NAME := blade1
#	moof200x150 side_camp_gray
endif

IMG_FILE := $(IMG_NAME).jpg
COE_FILE := $(IMG_NAME).coe
COE_LINK := img_data.coe

all: core
core: $(V_SRC)
link: src/$(COE_LINK)
coe: src/$(COE_FILE)

%.v: %.xco coregen.cgp src/$(COE_LINK)
	coregen $(CG_FLAGS) -p coregen.cgp -b $*.xco

src/$(COE_FILE): src/$(IMG_FILE) src/img_to_coe.py src/img_to_coe.m
	cd src; \
		matlab -nojvm -nodisplay -nosplash -r "img_to_coe('$(IMG_FILE)')"

src/$(COE_LINK): src/$(COE_FILE)
	cd src; rm -f $(COE_LINK); ln -s $(COE_FILE) $(COE_LINK)

tidy: core
	-echo 'rm -rf $*/* $*.xci $*.asy $*_*.tcl $*_*.txt $*.xise $*.gise *.cgc *.log tmp xlnx*'
	-echo 'rmdir $*'

clean:
	find . ! -name '*.xco' -a ! -name 'Makefile' -a ! -name '*.cgp' -a ! -name '.gitignore' -a ! -name 'stash*' -a ! -name 'src' -a ! -name '*.jpg' -a ! -name '*.py' -a ! -name '*.m' -delete
