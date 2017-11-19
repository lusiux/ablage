.PHONY: phony_explicit backup

PDFS=$(wildcard ocr/*.pdf)
OCRS=$(addprefix classify/, $(notdir ${PDFS}))
CLASSS=$(wildcard classify/*.pdf)
HTMLSTMP=$(notdir $(OCRS:%.pdf=%.html)) $(notdir $(CLASSS:%.pdf=%.html))
HTMLS=$(addprefix html/, ${HTMLSTMP})

all: ${OCRS} ${HTMLS}

phony_explicit:

html/%.html: classify/%.pdf phony_explicit
	@./classify.pl $<

classify/%.pdf: ocr/%.pdf
	ocrmypdf -l deu -d -c -r $< $@
	rm $<

DATE=$(shell date +%Y%m%d_%H%M)

backup:
	tar -cf backup/${DATE}_store.tar store

clean: $(wildcard html/*.html)
	rm -I $^

fixup:
	find store -xtype l -delete
