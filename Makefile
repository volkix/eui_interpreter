# ==============================================================================
# Euphorix 1.0 (Java 25 High-Performance VM for OpenEuphoria Syntax)
# ==============================================================================

JDK25_HOME     := /home/volkix/prg/jdk25
JAVA           := $(JDK25_HOME)/bin/java
MVN            := JAVA_HOME=$(JDK25_HOME) mvn
JAVA_SRCS      := $(wildcard java/src/main/java/eu/*.java)
JAVA_JAR       := euphorix.jar
JAVA_BIN       := euphorix
STANDALONE_BIN := euphorix-standalone
EU_STDLIB      := $(wildcard eu_include/std/*.e eu_include/std/*/*.e eu_include/euphoria/*.e)

.PHONY: all java fatjar standalone test test-java test-standalone website clean

all: java standalone

java: $(JAVA_JAR) $(JAVA_BIN)

fatjar: $(JAVA_JAR)

$(JAVA_JAR): pom.xml $(JAVA_SRCS) $(EU_STDLIB)
	$(MVN) package -DskipTests
	@ln -sf $(JAVA_JAR) eui.jar

$(JAVA_BIN): $(JAVA_JAR)
	@printf '#!/usr/bin/env bash\nDIR="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")" && pwd)"\nexec $(JAVA) --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 -Dawt.useSystemAAFontSettings=lcd -Dswing.aatext=true -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine -Djdk.internal.httpclient.disableHostnameVerification=true -jar "$$DIR/$(JAVA_JAR)" "$$@"\n' > $(JAVA_BIN)
	@chmod +x $(JAVA_BIN)
	@ln -sf $(JAVA_BIN) eui-java
	@ln -sf $(JAVA_BIN) eux

standalone: $(STANDALONE_BIN)

$(STANDALONE_BIN): $(JAVA_JAR) tools/build_standalone.sh
	./tools/build_standalone.sh $(STANDALONE_BIN)
	@ln -sf $(STANDALONE_BIN) eui-standalone
	@ln -sf $(STANDALONE_BIN) eux-standalone

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
	./$(JAVA_BIN) examples/07_sapui5_webcomponents_demo.ex
	./$(JAVA_BIN) examples/08_cgibash_html_demo.ex
	./$(JAVA_BIN) examples/09_excel_und_csv_demo.ex
	./$(JAVA_BIN) examples/10_auth_jwt_und_session_demo.ex
	./$(JAVA_BIN) examples/11_vsui_charts_und_upload_demo.ex
	./$(JAVA_BIN) examples/12_cron_scheduler_demo.ex
	./$(JAVA_BIN) tests/t_gui.e
	./$(JAVA_BIN) tests/t_ui5.e
	./$(JAVA_BIN) tests/t_vsui.e
	./$(JAVA_BIN) tests/t_vsui_ext.e
	./$(JAVA_BIN) tests/t_excel_csv.e
	./$(JAVA_BIN) tests/t_auth_session.e
	./$(JAVA_BIN) tests/t_cron_sse.e
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
	./$(STANDALONE_BIN) examples/07_sapui5_webcomponents_demo.ex
	./$(STANDALONE_BIN) examples/08_cgibash_html_demo.ex
	./$(STANDALONE_BIN) examples/09_excel_und_csv_demo.ex
	./$(STANDALONE_BIN) examples/10_auth_jwt_und_session_demo.ex
	./$(STANDALONE_BIN) examples/11_vsui_charts_und_upload_demo.ex
	./$(STANDALONE_BIN) examples/12_cron_scheduler_demo.ex
	./$(STANDALONE_BIN) tests/t_gui.e
	./$(STANDALONE_BIN) tests/t_ui5.e
	./$(STANDALONE_BIN) tests/t_vsui.e
	./$(STANDALONE_BIN) tests/t_vsui_ext.e
	./$(STANDALONE_BIN) tests/t_excel_csv.e
	./$(STANDALONE_BIN) tests/t_auth_session.e
	./$(STANDALONE_BIN) tests/t_cron_sse.e
	./$(STANDALONE_BIN) tests/t_java_interop.e
	./$(STANDALONE_BIN) tests/t_concurrency.ex

website: $(JAVA_BIN)
	./$(JAVA_BIN) tools/build_website.ex

clean:
	rm -rf java/target $(JAVA_JAR) eui.jar $(JAVA_BIN) eui-java eux $(STANDALONE_BIN) eui-standalone eux-standalone
