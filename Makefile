NIM=nim
APPNAME=smalltrek

$(APPNAME)-debug: src/*.nim
	$(NIM) c -d:debug -o:$@ src/main.nim

$(APPNAME): src/*.nim
	$(NIM) c -d:release -o:$@ src/main.nim

clean:
	rm -vrf src/nimcache $(APPNAME) $(APPNAME)-debug || true

run: $(APPNAME)
	./$(APPNAME)

rund: $(APPNAME)-debug
	./$(APPNAME)-debug

.PHONY: clean run rund
