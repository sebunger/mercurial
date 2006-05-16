PREFIX=/usr/local
export PREFIX
PYTHON=python

help:
	@echo 'Commonly used make targets:'
	@echo '  all          - build program and documentation'
	@echo '  install      - install program and man pages to PREFIX ($(PREFIX))'
	@echo '  install-home - install with setup.py install --home=HOME ($(HOME))'
	@echo '  local        - build C extensions for inplace usage'
	@echo '  tests        - run all tests in the automatic test suite'
	@echo '  test-foo     - run only specified tests (e.g. test-merge1)'
	@echo '  dist         - run all tests and create a source tarball in dist/'
	@echo '  clean        - remove files created by other targets'
	@echo '                 (except installed files or dist source tarball)'
	@echo
	@echo 'Example for a system-wide installation under /usr/local:'
	@echo '  make all && su -c "make install" && hg version'
	@echo
	@echo 'Example for a local installation (usable in this directory):'
	@echo '  make local && ./hg version'

all: build doc

local:
	$(PYTHON) setup.py build_ext -i

build:
	$(PYTHON) setup.py build

doc:
	$(MAKE) -C doc

clean:
	-$(PYTHON) setup.py clean --all # ignore errors of this command
	find . -name '*.py[co]' -exec rm -f '{}' ';'
	rm -f MANIFEST mercurial/__version__.py mercurial/*.so tests/*.err
	$(MAKE) -C doc clean

install: all
	$(PYTHON) setup.py install --prefix="$(PREFIX)" --force
	cd doc && $(MAKE) $(MFLAGS) install

install-home: all
	$(PYTHON) setup.py install --home="$(HOME)" --force
	cd doc && $(MAKE) $(MFLAGS) PREFIX="$(HOME)" install

dist:	tests dist-notests

dist-notests:	doc
	TAR_OPTIONS="--owner=root --group=root --mode=u+w,go-w,a+rX-s" $(PYTHON) setup.py sdist --force-manifest

tests:
	cd tests && $(PYTHON) run-tests.py

test-%:
	cd tests && $(PYTHON) run-tests.py $@


.PHONY: help all local build doc clean install install-home dist dist-notests tests
