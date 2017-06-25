title := penguin_demo

objlist := nrom init main penguin

AS65 := ca65
LD65 := ld65
CFLAGS65 := --cpu 6502X
objdir := obj/nes
srcdir := src

EMU := fceux
DEBUG_EMU := wine fceux/fceux.exe

.PHONY: all run clean

all: $(title).nes 

run: $(title).nes
	$(EMU) $<

debug: $(title).nes
	$(DEBUG_EMU) $<

clean:
	-rm $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr

objlistntsc := $(foreach o,$(objlist),$(objdir)/$(o).o)

map.txt $(title).nes: nrom128.cfg $(objlistntsc)
	$(LD65) -o $(title).nes -m map.txt -C $^

$(objdir)/%.o: $(srcdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/penguin.o: $(srcdir)/music_data.inc $(srcdir)/sfx_data.inc

convert: convert.cpp
	g++ convert.cpp -o convert

convert_sfx: convert_sfx.cpp
	g++ convert_sfx.cpp -o convert_sfx

$(srcdir)/music_data.inc: convert ralph4_music.txt
	./convert ralph4_music.txt $(srcdir)/music_data.inc

$(srcdir)/sfx_data.inc: convert_sfx ralph4_sfx.txt ralph4_sfx.nsf
	./convert_sfx ralph4_sfx.txt ralph4_sfx.nsf $(srcdir)/sfx_data.inc $(srcdir)/sfx.inc

