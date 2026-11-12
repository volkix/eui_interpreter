# ==============================================================================
# OpenEuphoria 4.x (Java 25 Enterprise Edition for Linux 64-Bit)
# ==============================================================================

JDK25_HOME     := /home/volkix/prg/jdk25
JAVA           := $(JDK25_HOME)/bin/java
MVN            := JAVA_HOME=$(JDK25_HOME) mvn
JAVA_SRCS      := $(wildcard java/src/main/java/eu/*.java)
JAVA_JAR       := eui.jar
JAVA_BIN       := eui-java
STANDALONE_BIN := eui-standalone
EU_STDLIB      := $(wildcard eu_include/std/*.e eu_include/std/*/*.e eu_include/euphoria/*.e)

.PHONY: all java fatjar standalone test test-java test-standalone clean

all: java standalone

java: $(JAVA_JAR) $(JAVA_BIN)

fatjar: $(JAVA_JAR)

$(JAVA_JAR): pom.xml $(JAVA_SRCS) $(EU_STDLIB)
	$(MVN) package -DskipTests

$(JAVA_BIN): $(JAVA_JAR)
	@printf '#!/usr/bin/env bash\nDIR="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")" && pwd)"\nexec $(JAVA) --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 -Dawt.useSystemAAFontSettings=lcd -Dswing.aatext=true -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine -Djdk.internal.httpclient.disableHostnameVerification=true -jar "$$DIR/$(JAVA_JAR)" "$$@"\n' > $(JAVA_BIN)
	@chmod +x $(JAVA_BIN)

standalone: $(STANDALONE_BIN)

$(STANDALONE_BIN): $(JAVA_JAR) tools/build_standalone.sh
	./tools/build_standalone.sh $(STANDALONE_BIN)

test: test-java

test-java: $(JAVA_BIN)
	./$(JAVA_BIN) examples/hello.ex
	./$(JAVA_BIN) examples/sieve.ex
	./$(JAVA_BIN) examples/oe4_features.ex
	./$(JAVA_BIN) examples/stdlib_full_test.ex
	./$(JAVA_BIN) examples/http_demo.ex
	./$(JAVA_BIN) examples/data_sqlite_demo.ex
	./$(JAVA_BIN) examples/01_utf8_textverarbeitung.ex
	./$(JAVA_BIN) examples/02_json_und_schema.ex
	./$(JAVA_BIN) examples/03_xml_xpath_xsd.ex
	./$(JAVA_BIN) examples/04_sqlite_datenbank.ex
	./$(JAVA_BIN) examples/05_rest_api_microservice.ex
	./$(JAVA_BIN) examples/06_postgresql_datenbank.ex
	./$(JAVA_BIN) tests/t_gui.e
	./$(JAVA_BIN) tests/t_java_interop.e
	./$(JAVA_BIN) tests/t_concurrency.ex

test-standalone: $(STANDALONE_BIN)
	./$(STANDALONE_BIN) examples/hello.ex
	./$(STANDALONE_BIN) examples/sieve.ex
	./$(STANDALONE_BIN) examples/oe4_features.ex
	./$(STANDALONE_BIN) examples/stdlib_full_test.ex
	./$(STANDALONE_BIN) examples/http_demo.ex
	./$(STANDALONE_BIN) examples/data_sqlite_demo.ex
	./$(STANDALONE_BIN) examples/01_utf8_textverarbeitung.ex
	./$(STANDALONE_BIN) examples/02_json_und_schema.ex
	./$(STANDALONE_BIN) examples/03_xml_xpath_xsd.ex
	./$(STANDALONE_BIN) examples/04_sqlite_datenbank.ex
	./$(STANDALONE_BIN) examples/05_rest_api_microservice.ex
	./$(STANDALONE_BIN) examples/06_postgresql_datenbank.ex
	./$(STANDALONE_BIN) tests/t_gui.e
	./$(STANDALONE_BIN) tests/t_java_interop.e
	./$(STANDALONE_BIN) tests/t_concurrency.ex

clean:
	rm -rf java/target $(JAVA_JAR) $(STANDALONE_BIN)
