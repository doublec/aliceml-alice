ALICEC      = alicec
ALICEC_OPTS = --dump-phases

ALICEDEP    = alicedep

SRCS = hello.aml          \
       logo.aml           \
       packbox.aml        \
       canvas.aml         \
       scramble.aml       \
       widgets.aml        \
       move.aml           \
       TextViewer.aml     \
       AliceTour.aml
OBJS = $(SRCS:%.aml=%.alc)

%.alc: %.aml
	$(ALICEC) $(ALICEC_OPTS) -c $< -o $@

all: $(OBJS)

depend:
	$(ALICEDEP) $(SRCS) > Makefile.depend

clean:
	rm -f *.alc

distclean: clean
	rm -f Makefile.depend

-include Makefile.depend
