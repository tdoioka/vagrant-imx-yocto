include provision/speck.rb

TASKS=$(shell grep Makefile -oe '^[a-zA-Z][^:]*')
.PHONY: $(TASKS)

default: image

plugin:
	./provision/host-setup.sh plugin

preimage: plugin
	./provision/host-setup.sh pre_provision expand_part

baseimage: preimage
	./provision/host-setup.sh -f provision

build: baseimage
	./provision/host-setup.sh -f build

export:
	./provision/host-setup.sh finalize export

all: baseimage build export

cleanstate:
	rm -rf $(PROVS)/$(BUILD_CACHE)

clean: cleanstate
	vagrant destroy -f || true

