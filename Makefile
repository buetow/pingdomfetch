NAME=pingdomfetch
all: version documentation perltidy
version:
	cut -d' ' -f2 debian/changelog | head -n 1 | sed 's/(//;s/)//' > .version
perltidy:
	find . -name \*.pm | xargs perltidy -b
	perltidy -b $(NAME)
	find . -name \*.bak -delete
documentation:
	pod2man --release="$(NAME) $$(cat .version)" \
                       --center="User Commands" ./docs/$(NAME).pod > ./docs/$(NAME).1
	pod2text ./docs/$(NAME).pod > ./docs/$(NAME).txt
	cp ./docs/${NAME}.pod ./README.pod
install:
	test ! -d $(DESTDIR)/usr/bin && mkdir -p $(DESTDIR)/usr/bin || exit 0
	test ! -d $(DESTDIR)/var/run/pingdomfetch && mkdir -p $(DESTDIR)/var/run/pingdomfetch || exit 0
	test ! -d $(DESTDIR)/usr/share/$(NAME)/examples && mkdir -p $(DESTDIR)/usr/share/$(NAME)/examples || exit 0
	cp $(NAME) $(DESTDIR)/usr/bin
	cp -r ./lib $(DESTDIR)/usr/share/$(NAME)/lib
	cp ./.version $(DESTDIR)/usr/share/$(NAME)/version
	cp ./pingdomfetch.conf.sample $(DESTDIR)/usr/share/$(NAME)/examples/pingdomfetch.conf.sample
deinstall:
	test ! -z "$(DESTDIR)" && test -f $(DESTDIR)/usr/bin/$(NAME) && rm $(DESTDIR)/usr/bin/$(NAME) || exit 0
	test ! -z "$(DESTDIR)/usr/share/$(NAME)" && -d $(DESTDIR)/usr/share/$(NAME) && rm -r $(DESTDIR)/usr/share/$(NAME) || exit 0
clean:
	test -d $(DESTDIR) && rm -Rf $(DESTDIR)
dch:
	dch -i
deb: 
	dpkg-buildpackage -uc -us
dput: deb
	bash -c "dput -u incoming-debrepo ../$(NAME)_$$(cat ./debian/pingdomfetch/usr/share/pingdomfetch/version)_amd64.changes"
release: all dch deb dput 
	git commit -a -m 'New release'
	bash -c "git tag $$(cat ./debian/pingdomfetch/usr/share/pingdomfetch/version)"
	git push origin master
	git push --tags
clean-top:
	rm ../$(NAME)_*.tar.gz
	rm ../$(NAME)_*.dsc
	rm ../$(NAME)_*.changes
	rm ../$(NAME)_*.deb
tmp-top:
	mv ../$(NAME)_*.tar.gz /tmp
	mv ../$(NAME)_*.dsc /tmp
	mv ../$(NAME)_*.changes /tmp
	mv ../$(NAME)_*.deb /tmp
testrun:
	./pingdomfetch --all-tls --config pingdomfetch.conf.test 
testrun_verbose:
	./pingdomfetch --all-tls --config pingdomfetch.conf.test --verbose
