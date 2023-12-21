.PHONY: all box16

all:
	p8compile pp1unpack.p8 -target cx16 -sourcelines -asmlist
	cp pp1unpack.prg ./sdcard/SHELL-CMDS/pp1unpack

box16:
	cd sdcard && box16 -gif capture.gif

clean:
	rm -rf pp1unpack.asm pp1unpack.list pp1unpack.prg *.vice-mon.list
