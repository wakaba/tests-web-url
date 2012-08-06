WGET = wget --no-check-certificate

all: idna2003-based-data

idna2003-based-data: charprop-subset bin/generate-stringprep-mappings.pl
	perl bin/generate-stringprep-mappings.pl

charprop-subset: \
  lib/Char/Prop/Unicode/Age.pm \
  lib/Char/Prop/Unicode/BidiClass.pm \
  lib/Char/Prop/Unicode/5_1_0/BidiClass.pm

lib/Char/Prop/Unicode/%.pm: lib/Char/Prop/Unicode
	$(WGET) -O $@ https://github.com/wakaba/perl-charclass/raw/master/$@
lib/Char/Prop/Unicode/5_1_0/%.pm: lib/Char/Prop/Unicode/5_1_0
	$(WGET) -O $@ https://github.com/wakaba/perl-charclass/raw/master/$@

lib/Char/Prop/Unicode:
	mkdir -p $@
lib/Char/Prop/Unicode/5_1_0:
	mkdir -p $@

## License: Public Domain.
