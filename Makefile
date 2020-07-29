NIMC=nim
APPNAME=smalltrek
DATE=$(shell date +%Y-%m-%d)

SOURCES = $(shell find src -name '*.nim')

$(APPNAME)-debug: src/*.nim
	$(NIMC) c -d:debug -d:gamerzillasupport -o:$@ src/main.nim

$(APPNAME): src/*.nim
	$(NIMC) c -d:release -d:gamerzillasupport -o:$@ src/main.nim

clean:
	rm -vrf src/nimcache $(APPNAME) $(APPNAME)-debug || true

run: $(APPNAME)
	./$(APPNAME)

rund: $(APPNAME)-debug
	./$(APPNAME)-debug

windows: $(SOURCES)
	${NIMC} c -d:release -d:gamerzillasupport -d:windows --threads:on -o:winversion/${APPNAME}.exe src/main.nim
	cp -r assets winversion
	cp config.ini winversion
	unix2dos winversion/config.ini
	find winversion/assets/ -name '*.wav' -delete
	rm ${APPNAME}-${DATE}-win32.zip || true
	cd winversion; \
	zip -r ../${APPNAME}-${DATE}-win32.zip .

linux64: $(SOURCES)
	${NIMC} c -d:release -d:gamerzillasupport --threads:on -o:linux/${APPNAME}.x86_64 src/main.nim

linux32: $(SOURCES)
	${NIMC} c -d:release -d:gamerzillasupport -d:linux32 --threads:on -o:linux/${APPNAME}.x86 src/main.nim

linux: linux32 linux64
	cp -r assets linux
	cp config.ini linux
	find linux/assets/ -name '*.wav' -delete
	cd linux; \
	tar czf ../${APPNAME}-${DATE}-linux.tar.gz .

osx: $(SOURCES)
	${NIMC} c -d:release -d:osx --threads:off -o:${APPNAME}.app/Contents/MacOS/smalltrek src/main.nim
	cp -r assets ${APPNAME}.app/Contents/Resources/
	cp config.ini ${APPNAME}.app/Contents/Resources/
	find ${APPNAME}.app/Contents/Resources/assets/ -name '*.wav' -delete
	rm ${APPNAME}-${DATE}-osx.zip || true
	zip --symlinks -r ${APPNAME}-${DATE}-osx.zip ${APPNAME}.app

.PHONY: clean run rund
