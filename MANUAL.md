# Euphorix 1.0 (Java 25 VM for OpenEuphoria Syntax) – Developer Manual & API Reference

> 🇩🇪 **Deutsche Version verfügbar:** [HANDBUCH.md](file:///home/volkix/prj/intpret/HANDBUCH.md) | 📄 **Overview:** [README.md](file:///home/volkix/prj/intpret/README.md) | ⚖️ **License:** [GNU GPLv3](file:///home/volkix/prj/intpret/LICENSE)

> [!NOTE]
> **OpenEuphoria Syntax Compatibility:** **Euphorix** is an independent, clean-room high-performance Virtual Machine written in Java 25. It natively interprets and executes the **OpenEuphoria 4.x syntax** and standard library, enhanced with modern Java 25 capabilities (Virtual Threads, Go-style Channels, Async/Await Futures, Swing/FlatLaf Desktop GUI, JDBC for SQLite & PostgreSQL, UTF-8, and XML/JSON).

This manual is the complete documentation and technical reference for **Euphorix** (`./euphorix`, `./euphorix-standalone`, and `euphorix.jar`). Backward-compatible aliases such as `./eui-java` and `./eui-standalone` are maintained.

The runtime environment combines the clean, lightweight syntax of OpenEuphoria with modern Java platform capabilities (OpenJDK 25):
* **Virtual Threads (Project Loom)** for scalable servers, asynchronous streaming pipelines, and background processes—completely **without fragile POSIX `fork()`**.
* **Seamless Java Interoperability (`std/java.e`)**: Runtime loading of external JAR files, instantiation of Java classes, static and instance method invocation, field access, and dynamic proxy listeners for callbacks.
* **Native GUI Development with Java Swing & AWT (`std/gui.e`)**: Modern Linux desktop design via **GTK+ Look & Feel** and FlatLaf, crisp **subpixel LCD anti-aliasing**, native Ubuntu typography, and declarative widget definitions.
* **Comprehensive UTF-8 Support**: Consistent handling of non-ASCII characters, German umlauts (`ä`, `ö`, `ü`, `ß`), and worldwide Unicode glyphs across lexer, compiler, bytecode VM, Swing GUI, and I/O.
* **Built-in Enterprise Modules**: JSON & RFC 9535 JSONPath, JSON-Schema (Draft 2020-12), XML DOM with W3C XPath 1.0 & XSD, SQLite 3 & PostgreSQL (JDBC), HTTP/HTTPS client & server, and dual-stack IPv4/IPv6 sockets.
* **C-FFI & Native Raw Memory**: Direct binding of native Linux shared libraries (`.so`) using the JDK 25 Foreign Function & Memory (FFM) API (`java.lang.foreign.*`).
* **Standalone Single-Binary (`./euphorix-standalone`)**: Fully self-contained 53 MB single executable bundling an optimized minimal Java 25 runtime (via `jlink`), requiring **no installed Java** on target systems.

---

## Table of Contents

1. [Architecture, Installation & Build (Java 25 on Linux 64-Bit)](#1-architecture-installation--build-java-25-on-linux-64-bit)
   - 1.1 [Project Structure & Fat-JAR Architecture](#11-project-structure--fat-jar-architecture)
   - 1.2 [Virtual Threads Architecture (Processes & Concurrency without `fork()`)](#12-virtual-threads-architecture-processes--concurrency-without-fork)
   - 1.3 [Native C Binding (.so) via JDK 25 FFM API](#13-native-c-binding-so-via-jdk-25-ffm-api)
   - 1.4 [Prerequisites & Maven Build](#14-prerequisites--maven-build)
   - 1.5 [Managing & Integrating Java Dependencies via `pom.xml`](#15-managing--integrating-java-dependencies-via-pomxml)
   - 1.6 [Self-Contained Single-Binary with Bundled Minimal JRE (`./euphorix-standalone`)](#16-self-contained-single-binary-with-bundled-minimal-jre-euphorix-standalone)
   - 1.7 [Cross-Platform & Microsoft Windows Support (`euphorix.cmd` / `euphorix.bat`)](#17-cross-platform--microsoft-windows-support-euphorixcmd--euphorixbat)
2. [Complete Language, Syntax & Standard Reference](#2-complete-language-syntax--standard-reference)
   - 2.1 [Data Types & Type System](#21-data-types--type-system)
   - 2.2 [Visibility, Namespaces & Includes](#22-visibility-namespaces--includes)
   - 2.3 [Operators, Indexing & Slicing](#23-operators-indexing--slicing)
   - 2.4 [Control Structures & Loops](#24-control-structures--loops)
   - 2.5 [Procedures, Functions & Callbacks](#25-procedures-functions--callbacks)
   - 2.6 [Conditional Compilation (`ifdef`)](#26-conditional-compilation-ifdef)
   - 2.7 [All Built-in Routines](#27-all-built-in-routines)
   - 2.8 [Key Modules of the Standard Library (`std/*.e`)](#28-key-modules-of-the-standard-library-stde)
3. [Java Interoperability & JAR Integration (`std/java.e`)](#3-java-interoperability--jar-integration-stdjavae)
   - 3.1 [Loading External JAR Files (`java:load_jar`)](#31-loading-external-jar-files-javaload_jar)
   - 3.2 [Class Resolution & Object Instantiation](#32-class-resolution--object-instantiation)
   - 3.3 [Method Invocation (Static & Instance)](#33-method-invocation-static--instance)
   - 3.4 [Reading and Writing Fields](#34-reading-and-writing-fields)
   - 3.5 [Automatic Type Matching & Conversions](#35-automatic-type-matching--conversions)
   - 3.6 [Event Listeners & Callbacks (`java:create_listener`)](#36-event-listeners--callbacks-javacreate_listener)
   - 3.7 [Subprocess Streaming Pipes with Virtual Threads](#37-subprocess-streaming-pipes-with-virtual-threads)
4. [Graphical User Interfaces with Swing & AWT (`std/gui.e`)](#4-graphical-user-interfaces-with-swing--awt-stdguie)
   - 4.1 [Linux Desktop Integration & Theme Selection (`gui:set_theme`)](#41-linux-desktop-integration--theme-selection-guiset_theme)
   - 4.2 [Typography & Subpixel LCD Anti-Aliasing](#42-typography--subpixel-lcd-anti-aliasing)
   - 4.3 [Window Management (`window`, `show`, `wait_window`)](#43-window-management-window-show-wait_window)
   - 4.4 [Layout Managers with Gap Control (`hgap`/`vgap`)](#44-layout-managers-with-gap-control-hgapvgap)
   - 4.5 [Widget Component Reference](#45-widget-component-reference)
   - 4.6 [Properties, Styling & Padding](#46-properties-styling--padding)
   - 4.7 [Standard Dialogs (Message, Input, Confirm, FileDialog)](#47-standard-dialogs-message-input-confirm-filedialog)
   - 4.8 [Complete Demo Application (`demo/gui_demo.ex`)](#48-complete-demo-application-demogui_demoex)
5. [UTF-8 String Processing (`std/utf8.e` & VM Engine)](#5-utf-8-string-processing-stdutf8e--vm-engine)
6. [JSON & RFC 9535 JSONPath (`std/json.e`)](#6-json--rfc-9535-jsonpath-stdjsone)
7. [JSON-Schema Draft 2020-12 (`std/json_schema.e`)](#7-json-schema-draft-2020-12-stdjson_schemae)
8. [XML DOM, W3C XPath 1.0 & XSD (`std/xml.e`)](#8-xml-dom-w3c-xpath-10--xsd-stdxmle)
9. [SQL Databases: SQLite 3 (`std/sqlite.e`) & PostgreSQL (`std/pgsql.e`)](#9-sql-databases-sqlite-3-stdsqlitee--postgresql-stdpgsqle)
10. [HTTP & HTTPS Client and Server (`std/http.e`)](#10-http--https-client-and-server-stdhttpe)
11. [Dual-Stack Networking & Sockets (`std/socket.e` & `std/net/dns.e`)](#11-dual-stack-networking--sockets-stdsockete--stdnetdnse)
12. [Demos, Examples & Execution](#12-demos-examples--execution)
13. [Modern Concurrency: Virtual Threads, Async/Await & Channels (`std/thread.e`, `std/channel.e`, `std/task.e`)](#13-modern-concurrency-virtual-threads-asyncawait--channels-stdthreade-stdchannele-stdtaske)
   - 13.1 [Approach 1: Classic Tasks with Virtual Threads (`task:create_thread`)](#131-approach-1-classic-tasks-with-virtual-threads-taskcreate_thread)
   - 13.2 [Approach 2: Channels / Go-Style Concurrency (`std/channel.e`)](#132-approach-2-channels--go-style-concurrency-stdchannele)
   - 13.3 [Approach 3: Async / Await Futures (`std/thread.e`)](#133-approach-3-async--await-futures-stdthreade)

---

## 1. Architecture, Installation & Build (Java 25 on Linux 64-Bit)

### 1.1 Project Structure & Fat-JAR Architecture

The interpreter builds as a **standalone Fat-JAR (`euphorix.jar`)**. When built with Maven, all dependencies (JDBC drivers, Jackson JSON, FlatLaf look-and-feel, embedded standard library) are shaded into a single archive:

```
prj/intpret/
├── euphorix (eui-java, eux) <- Shell launcher with optimized JVM parameters
├── euphorix.jar (eui.jar)   <- Standalone Java 25 Fat-JAR (19.4 MB shaded)
├── euphorix-standalone      <- Standalone 53 MB single executable (bundled minimal JRE)
├── euphorix.cmd / .bat      <- Windows command launchers
├── pom.xml                  <- Maven project descriptor for JDK 25 & Shade plugin
├── eu_include/              <- Standard library (std/*.e, euphoria/*.e)
│   ├── std/
│   │   ├── gui.e            <- Swing & AWT Desktop GUI API
│   │   ├── java.e           <- Java Interoperability, JAR Loader & Virtual Thread Pipes
│   │   ├── utf8.e           <- Unicode & UTF-8 string manipulation
│   │   ├── json.e           <- JSON & RFC 9535 JSONPath
│   │   ├── json_schema.e    <- JSON-Schema Draft 2020-12
│   │   ├── xml.e            <- XML DOM, XPath 1.0, XSD
│   │   ├── sqlite.e         <- SQLite 3 API
│   │   ├── pgsql.e          <- PostgreSQL API
│   │   ├── http.e           <- HTTP/HTTPS Client & Server
│   │   └── ...              <- sequence.e, math.e, regex.e, socket.e, etc.
├── java/src/main/java/eu/   <- Java 25 source code
│   ├── Main.java            <- CLI entry point, UTF-8 & AWT property initialization
│   ├── Lexer.java           <- Lexer with native UTF-8 multi-byte encoding
│   ├── Compiler.java        <- Single-pass bytecode compiler & constant folder
│   ├── Bytecode.java        <- 3-address register instruction set (OpCodes)
│   ├── VM.java              <- Register VM with virtual threads & engine dispatch
│   ├── Value.java           <- 48-bit Int, IEEE-754 Atom & Copy-on-Write Sequences
│   ├── JavaInterop.java     <- Reflection, JAR ClassLoader, dynamic proxy & pipes
│   └── DataEngines.java     <- JSON, XPath & schema validation engines
├── tools/
│   └── build_standalone.sh  <- jlink packaging tool for standalone executable
└── demo/
    └── gui_demo.ex          <- Interactive GTK+ Swing GUI demo application
```

#### The `./euphorix` Launcher Script
The launcher script (`./euphorix` with aliases `./eui-java` and `./eux`) provides optimized Linux 64-bit JVM parameters:
```bash
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR="$DIR/euphorix.jar"
exec /home/volkix/prg/jdk25/bin/java \
    --enable-native-access=ALL-UNNAMED \
    -Dfile.encoding=UTF-8 \
    -Dawt.useSystemAAFontSettings=lcd \
    -Dswing.aatext=true \
    -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
    -Djdk.internal.httpclient.disableHostnameVerification=true \
    -jar "$JAR" "$@"
```

---

### 1.2 Virtual Threads Architecture (Processes & Concurrency without `fork()`)

In C programs, `fork()` clones the address space of the process, which is problematic and prone to deadlocks in multithreaded environments.

The Java 25 Edition utilizes **Virtual Threads (Project Loom)** exclusively:
1. **Subprocess Pipes (`pipe_open`, `pipe_read`, `pipe_write`, `pipe_close`)**:
   Subprocesses launch asynchronously via `java.lang.ProcessBuilder`. Dedicated virtual threads continuously read `stdout` and `stderr` into lock-free `LinkedBlockingQueue` buffers. This eliminates pipeline stalls and deadlocks without blocking the Euphoria interpreter thread.
2. **HTTP/HTTPS Servers**:
   Incoming connections to `http:server_create` dispatch across a virtual thread executor. Thousands of concurrent connections consume minimal operating system resources.
3. **Re-entrant Event Callbacks**:
   Swing and background threads safely invoke Euphoria callback routines via `VM.invokeRoutine()`.

---

### 1.3 Native C Binding (.so) via JDK 25 FFM API

Standard OpenEuphoria C-FFI routines (`open_dll`, `define_c_func`, `define_c_proc`, `c_func`, `c_proc`, `allocate`, `free`, `peek*`, `poke*`) interface with native Linux shared objects through the **JDK 25 Foreign Function & Memory (FFM) API**:
* Shared libraries (`.so`) load via `SymbolLookup.libraryLookup(Path, Arena)`.
* Function invocations execute through `Linker.nativeLinker().downcallHandle()` using native ABI descriptors (`ValueLayout.JAVA_INT`, `JAVA_LONG`, `ADDRESS`, `JAVA_DOUBLE`).
* Off-heap memory is allocated via `MemorySegment.allocateNative()`.

This enables direct calls into Linux system libraries (e.g. `libc.so.6`, `libm.so.6`, `libcrypto.so`) without any C compiler.

---

### 1.4 Prerequisites & Maven Build

* **Operating System**: Linux 64-Bit (`x86_64`)
* **Java SDK**: OpenJDK 25 (at `/home/volkix/prg/jdk25` or configured via `JAVA_HOME`)
* **Build Tool**: Apache Maven (`mvn`)

```bash
# Build the Fat-JAR (euphorix.jar)
JAVA_HOME=/home/volkix/prg/jdk25 mvn clean package -DskipTests

# Execute an OpenEuphoria script
./euphorix demo/gui_demo.ex

# Run unit test suites (Java 25 Runner)
./tools/run_all_tests ./euphorix tests/t_gui.e tests/t_java_interop.e tests/t_concurrency.ex
```

---

### 1.5 Managing & Integrating Java Dependencies via `pom.xml`

Managing dependencies through [`pom.xml`](file:///home/volkix/prj/intpret/pom.xml) makes millions of Java libraries instantly accessible in OpenEuphoria without classpath configuration.

#### How Fat-JAR Dependency Management Works:
1. **Central Declaration**: Libraries declared in `pom.xml` are downloaded automatically from Maven Central, along with all transitive dependencies.
2. **Automatic Shading**: The `maven-shade-plugin` unpacks all classes and bundles them directly into `euphorix.jar`.
3. **Immediate Euphoria Availability**: Every class becomes accessible in Euphoria using `java:new_object()` and `java:call_static()`.

#### Example: Adding a New Java Library (3 Steps)

To add libraries such as **JFreeChart** (data visualization), **Apache POI** (Excel/Office documents), or **ZXing** (barcodes):

1. **Add dependency to `pom.xml`**:
   ```xml
   <dependency>
       <groupId>org.jfree</groupId>
       <artifactId>jfreechart</artifactId>
       <version>1.5.4</version>
   </dependency>
   ```

2. **Repackage the Fat-JAR**:
   ```bash
   JAVA_HOME=/home/volkix/prg/jdk25 mvn package -DskipTests
   ```

3. **Use directly in Euphoria**:
   ```euphoria
   include std/java.e as java

   atom chart = java:call_static("org.jfree.chart.ChartFactory", "createBarChart", {
       "Revenue 2026", "Category", "EUR", dataset
   })
   ```

#### Pre-configured Enterprise Dependencies in `pom.xml`:
* **SQLite JDBC** (`org.xerial:sqlite-jdbc`): Native SQLite 3 driver with bundled C engine for Linux x86_64.
* **PostgreSQL JDBC** (`org.postgresql:postgresql`): Full PostgreSQL driver supporting SCRAM-SHA-256 and TLS.
* **Jackson Databind** (`com.fasterxml.jackson.core:jackson-databind`): Fast JSON and RFC 9535 JSONPath engine.
* **FlatLaf Modern Look & Feel** (`com.formdev:flatlaf`): Clean Light and Dark modern UI themes.
* **SLF4J-NOP** (`org.slf4j:slf4j-nop`): Silent logging backend for clean CLI output.

---

### 1.6 Self-Contained Single-Binary with Bundled Minimal JRE (`./euphorix-standalone`)

The entire interpreter, including a **stripped-down 60 MB Java 25 runtime**, can be packaged into a **single, standalone 53 MB executable**:

```bash
# Build ./euphorix-standalone (approx. 53 MB xz-compressed)
make standalone
# or directly:
./tools/build_standalone.sh ./euphorix-standalone
```

#### How the Standalone Executable Operates:
1. **`jlink` (Java Linker)** extracts only required modules (`java.base`, `java.desktop`, `java.sql`, `java.net.http`, `java.xml`, etc.), removing debug symbols, manual pages, and unused modules.
2. The [`tools/build_standalone.sh`](file:///home/volkix/prj/intpret/tools/build_standalone.sh) script bundles the mini-JRE and `euphorix.jar` into an archive with an auto-extracting shell header.
3. **Execution**:
   - The file [`euphorix-standalone`](file:///home/volkix/prj/intpret/euphorix-standalone) (with alias `eui-standalone`) can be copied to any Linux 64-bit machine (e.g. to `/usr/local/bin/euphorix`).
   - **No Java runtime or JDK is required on the target machine!**
   - On initial launch, the runtime extracts to `~/.cache/euphorix/java25-runtime/<hash>/`. Subsequent launches execute directly from cache in milliseconds.
   - **Advantage over GraalVM**: Full support for runtime JAR loading (`java:load_jar`), Swing & GTK+ desktop GUIs, virtual threads, and HotSpot JIT optimization without closed-world limitations.

### 1.7 Cross-Platform & Microsoft Windows Support (`euphorix.cmd` / `euphorix.bat`)

Thanks to the pure Java 25 bytecode engine, `euphorix.jar` runs out of the box on **Microsoft Windows** (10, 11, Server) and **macOS** with zero code changes:

* **Dynamic OS Detection**: At compile time, flags such as `WINDOWS`, `WIN32` or `LINUX`, `UNIX` are resolved dynamically via `System.getProperty("os.name")`. The built-in `platform()` returns `2` (`WIN32`) on Windows.
* **Paths & Environment Variables**: `EUINC` automatically splits paths using `File.pathSeparator` (semicolon `;` on Windows, colon `:` on Linux), fully respecting Windows drive letters (`C:\...`).
* **Shell & Process Execution**: Shell commands (`system()`, `JavaInterop.pipeExec`) invoke `cmd.exe /c` automatically on Windows and `/bin/sh -c` on Unix.
* **Windows Launchers**: Convenient command-line wrappers [euphorix.cmd](file:///home/volkix/prj/intpret/euphorix.cmd) and [euphorix.bat](file:///home/volkix/prj/intpret/euphorix.bat) are provided in the root directory:
  ```cmd
  euphorix.cmd my_script.ex
  ```

---

## 2. Complete Language, Syntax & Standard Reference

### 2.1 Data Types & Type System

OpenEuphoria features a clean, hierarchical type system:

```
        object (any value: number or sequence)
       /      \
    atom      sequence (nested list: {1, "text", {2, 3}})
     |
  integer (48-bit signed integer)
```

- **`integer`**: 48-bit signed integers in range `[-140737488355328, +140737488355327]`.
- **`atom`**: Any numerical value—integer or 64-bit IEEE-754 floating-point (`double`).
- **`sequence`**: Ordered, **1-based** dynamic array (`{}`). Strings are sequences of byte values.
- **`object`**: Universal type capable of holding an `atom` or a `sequence`.

#### Variables, Constants & Enums
```euphoria
integer count = 42
atom price = 19.95
sequence name = "Euphoria"
constant VAT = 0.19, CURRENCY = "EUR"
enum STATUS_READY = 1, STATUS_ACTIVE, STATUS_DONE
```

#### Custom Types (`type ... end type`)
```euphoria
type percentage(object x)
    return integer(x) and x >= 0 and x <= 100
end type

percentage discount = 15   -- Validated dynamically upon assignment
```

---

### 2.2 Visibility, Namespaces & Includes

| Keyword | Visibility |
|---|---|
| *(none)* | File-local (`local`). |
| `export` | Accessible only to files that directly include this file. |
| `public` | Accessible to includers (and re-exported by public includes). |
| `global` | Visible program-wide across all files. |
| `override` | Selectively overrides a built-in or global routine. |

```euphoria
-- In mylib.e:
namespace mylib
public function double_val(atom x)
    return x * 2
end function

-- In main program:
include mylib.e as m
? m:double_val(21)   -- Output: 42
```

---

### 2.3 Operators, Indexing & Slicing

#### Indexing and Slicing (1-based)
* `s[1]`: First element
* `s[$]`: Last element (`$` represents `length(s)`)
* `s[$-1]`: Second to last element
* `s[2..4]`: Sub-sequence slice from index 2 to 4
* `s[2..$-1]`: Slice excluding first and last elements

#### Concatenation & Element-wise Operations
* `&`: Flattens and concatenates sequences (`"Hello " & "World"`).
* Arithmetic operators (`+`, `-`, `*`, `/`) apply element-wise across sequences:
  `{10, 20} * 2` yields `{20, 40}`.
* **Equality Testing**: The `=` operator performs element-wise comparisons. To test whether two sequences or strings are identical as a whole, use **`equal(a, b)`**!

---

### 2.4 Control Structures & Loops

```euphoria
-- If statement
if condition then
    action1()
elsif alt_condition then
    action2()
else
    action3()
end if

-- Switch statement
switch cmd do
    case "start", "run" then
        start_service()
        break
    case "stop" then
        stop_service()
        break
    case else
        unknown_cmd()
end switch

-- For loop
for i = 1 to 10 by 2 do
    ? i
end for

-- While loop
while is_running do
    process_next()
end while

-- Loop-until loop
loop do
    step()
    until is_done
```

---

### 2.5 Procedures, Functions & Callbacks

* **`procedure`**: Executes code without returning a value.
* **`function`**: Returns a value using `return <val>`.
* **Default Parameters**: Parameters can have default values (`function f(integer a, integer b = 10)`).
* **Multi-assignment (Destructuring)**:
  ```euphoria
  function coords()
      return {12.5, 48.2}
  end function
  atom x, y
  {x, y} = coords()
  ```
* **Routine IDs & Dynamic Invocation**:
  `integer rid = routine_id("my_function")`
  `object res = call_func(rid, {arg1, arg2})`

---

### 2.6 Conditional Compilation (`ifdef`)

```euphoria
ifdef LINUX then
    constant PATH_SEP = "/"
elsifdef WINDOWS then
    constant PATH_SEP = "\\"
end ifdef
```
Predefined symbols: `EU4`, `EU4_0`, `EU4_1`, `UNIX`, `LINUX`, `BITS64`, `LONG64`, `JAVA`, `JAVA25`, `CONSOLE`.

---

### 2.7 All Built-in Routines

#### Type Checking & Comparisons
* `integer(x)`: `1` if integer, else `0`.
* `atom(x)`: `1` if number (`integer` or `double`), else `0`.
* `sequence(x)`: `1` if sequence/string, else `0`.
* `object(x)`: `1` if initialized.
* `equal(a, b)`: Deep equality test (`1` or `0`).
* `compare(a, b)`: Lexicographical comparison (`-1`, `0`, `+1`).

#### Sequence & String Operations
* `length(s)`: Number of elements / bytes in `s`.
* `append(s, x)`: Appends `x` as a single element.
* `prepend(s, x)`: Prepends `x` as a single element.
* `repeat(item, count)`: Creates a sequence of `count` identical items.
* `find(needle, haystack, start=1)`: Finds element index in sequence (`0` if not found).
* `match(sub, haystack, start=1)`: Finds substring index in sequence (`0` if not found).
* `insert(s, item, index)` / `splice(s, items, index)`: Inserts element or slice.
* `remove(s, start, stop=start)`: Removes slice range.
* `replace(s, rep, start, stop=start)`: Replaces slice range with `rep`.

#### Console & File I/O
* `puts(fn, text)`: Writes string to file channel (`1` = STDOUT, `2` = STDERR).
* `printf(fn, fmt, values)`: Formatted output (`%d`, `%f`, `%s`, `%x`).
* `sprintf(fmt, values)`: Formatted string creation.
* `gets(fn)`: Reads line from file channel (or `-1` on EOF).
* `getc(fn)`: Reads single byte (or `-1` on EOF).
* `open(path, mode)`: Opens file (`"r"`, `"w"`, `"a"`, `"rb"`, `"wb"`).
* `close(fn)`: Closes file.
* `seek(fn, pos)` / `where(fn)`: Moves or queries file pointer position.

---

### 2.8 Key Modules of the Standard Library (`std/*.e`)

* **`std/sequence.e`**: `split`, `join`, `flatten`, `reverse`, `unique`, `filter`, `apply`, `slice`, `vslice`.
* **`std/search.e`**: `find_all`, `match_all`, `find_replace`, `match_replace`, `begins`, `ends`, `binary_search`.
* **`std/sort.e`**: `sort`, `custom_sort`, `sort_columns`.
* **`std/text.e`**: `trim`, `upper`, `lower`, `pad_head`, `pad_tail`, `format`.
* **`std/math.e`**: `abs`, `round`, `ceil`, `trunc`, `sum`, `average`, `min`, `max`, `gcd`.
* **`std/io.e`**: `read_file`, `write_file`, `read_lines`, `write_lines`, `append_lines`.
* **`std/filesys.e`**: `file_exists`, `dir`, `current_dir`, `chdir`, `create_directory`, `delete_file`, `copy_file`, `pathname`, `filename`.
* **`std/datetime.e`**: `datetime:now()`, `datetime:new()`, `datetime:format()`, `datetime:diff()`, `datetime:add()`.
* **`std/map.e`**: `map:new()`, `map:put()`, `map:get()`, `map:has()`, `map:remove()`, `map:keys()`, `map:values()`.
* **`std/regex.e`**: `regex:new()`, `regex:is_match()`, `regex:find()`, `regex:find_replace()`, `regex:split()`.

---

## 3. Java Interoperability & JAR Integration (`std/java.e`)

The `std/java.e` module provides bidirectional access to the Java 25 ecosystem and external JAR files.

### 3.1 Loading External JAR Files (`java:load_jar`)

```euphoria
include std/java.e as java

integer ok = java:load_jar("lib/my_custom_library.jar")
if not ok then
    puts(2, "Error: Could not load JAR file!\n")
end if
```

---

### 3.2 Class Resolution & Object Instantiation

* **`java:find_class(sequence class_name) -> atom`**  
  Resolves class handle (`Class<?>`) by fully-qualified name:
  ```euphoria
  atom cls_calc = java:find_class("com.example.Calculator")
  ```
* **`java:new_object(object class_or_name, sequence args = {}) -> atom`**  
  Instantiates an object using reflection and constructor resolution:
  ```euphoria
  atom sb = java:new_object("java.lang.StringBuilder", {"Initial text: "})
  atom list = java:new_object("java.util.ArrayList", {})
  ```

---

### 3.3 Method Invocation (Static & Instance)

* **`java:call_method(atom handle, sequence method_name, sequence args = {}) -> object`**  
  Calls an instance method:
  ```euphoria
  java:call_method(sb, "append", {123})
  java:call_method(sb, "append", {" EUR"})
  sequence text = java:to_string(sb)   -- "Initial text: 123 EUR"
  ```
* **`java:call_static(object class_or_name, sequence method_name, sequence args = {}) -> object`**  
  Calls a static method:
  ```euphoria
  atom now = java:call_static("java.lang.System", "currentTimeMillis", {})
  atom root = java:call_static("java.lang.Math", "sqrt", {144.0})   -- 12.0
  atom max_val = java:call_static("java.lang.Math", "max", {10, 25}) -- 25
  ```

---

### 3.4 Reading and Writing Fields

* **`java:get_field(atom obj_or_class, sequence field_name) -> object`**
* **`java:set_field(atom obj_or_class, sequence field_name, object value)`**

```euphoria
atom max_int = java:get_field("java.lang.Integer", "MAX_VALUE")
atom pi = java:get_field("java.lang.Math", "PI")
```

---

### 3.5 Automatic Type Matching & Conversions

The interop bridge scores available overloads and translates types automatically:

| Euphoria Type | Java Types |
|---|---|
| `integer` | `int`, `Integer`, `long`, `Long`, `short`, `byte`, `boolean` (`!= 0`) |
| `atom` (Float) | `double`, `Double`, `float`, `Float` |
| `sequence` (String) | `java.lang.String`, `java.lang.CharSequence` (UTF-8) |
| `sequence` (Numbers) | `byte[]`, `int[]`, `long[]` |
| `sequence` (Objects) | `java.util.List<?>`, `java.lang.Object[]` |
| Handle (`atom > 0`) | Java instance reference |
| `0` | `null` |

---

### 3.6 Event Listeners & Callbacks (`java:create_listener`)

Using **`java:create_listener(sequence interface_name, integer routine_id)`**, the runtime creates a dynamic `java.lang.reflect.Proxy` directing Java events back to an OpenEuphoria routine:

```euphoria
procedure on_button_click(atom sender)
    puts(1, "Button clicked!\n")
end procedure

atom listener = java:create_listener("java.awt.event.ActionListener", routine_id("on_button_click"))
java:call_method(btn, "addActionListener", {listener})
```
*Identity preservation:* The `sender` parameter in callbacks matches the exact atom handle of the triggering widget (`sender = btn`).

---

### 3.7 Subprocess Streaming Pipes with Virtual Threads

Subprocesses execute asynchronously via virtual threads:

```euphoria
atom pipe = java:pipe_open("uname -a", java:PIPE_READ)
sequence line = java:pipe_read_line(pipe)
puts(1, "Kernel: " & line & "\n")
java:pipe_close(pipe)
```

---

## 4. Graphical User Interfaces with Swing & AWT (`std/gui.e`)

The `std/gui.e` module provides a declarative API for developing desktop GUI applications under Linux.

### 4.1 Linux Desktop Integration & Theme Selection (`gui:set_theme`)

GUI initialization (`gui:init_gui()`) defaults to the native **GTK+ Look and Feel** (`com.sun.java.swing.plaf.gtk.GTKLookAndFeel`):
* Buttons, inputs, checkboxes, and scrollbars match the user's desktop environment (GNOME, Ubuntu, XFCE).
* Use **`gui:set_theme(sequence theme_name)`** to switch designs:
  * `"gtk"`: Native Linux desktop theme (default)
  * `"flatlaf"` or `"flatlaf-light"`: Modern flat light design
  * `"flatlaf-dark"` or `"dark"`: Modern dark mode
  * `"nimbus"`: Clean vector UI
  * `"system"`: Host system default

```euphoria
include std/gui.e as gui

-- Switch to modern dark mode before creating widgets:
gui:set_theme("flatlaf-dark")

atom win = gui:window("Dark Mode Application", 600, 400)
```

---

### 4.2 Typography & Subpixel LCD Anti-Aliasing

Enabled through JVM parameters `-Dawt.useSystemAAFontSettings=lcd` and `-Dswing.aatext=true`:
* **Default Font**: `Ubuntu` (or `SansSerif`) at 13pt.
* **Customization**: `gui:set_font(widget, "Ubuntu", 16, 1)` configures family, size, and bold style.

---

### 4.3 Window Management (`window`, `show`, `wait_window`)

```euphoria
atom win = gui:window("My Application", 600, 400, gui:CLOSE_ON_EXIT)
gui:show(win)
gui:wait_window(win)
```

Close actions:
* `gui:CLOSE_ON_EXIT` (Default): Terminates application when window is closed.
* `gui:DISPOSE_ON_CLOSE`: Closes window and releases graphical resources.
* `gui:HIDE_ON_CLOSE`: Hides window without disposal.

---

### 4.4 Layout Managers with Gap Control (`hgap`/`vgap`)

* **`gui:BORDER_LAYOUT`**: Divides container into 5 zones (`NORTH`, `SOUTH`, `EAST`, `WEST`, `CENTER`).
* **`gui:FLOW_LAYOUT`**: Horizontal centered arrangement.
* **`gui:GRID_LAYOUT`**: Tabular grid with rows, columns, and spacing.

```euphoria
-- 5-row, 2-column form grid with 14px horizontal and 12px vertical spacing:
atom pnl = gui:panel(gui:GRID_LAYOUT, 5, 2, 14, 12)
```

---

### 4.5 Widget Component Reference

| Function | Description |
|---|---|
| `gui:text_label(sequence text, integer align = ALIGN_LEFT) -> atom` | Label (`ALIGN_LEFT`, `ALIGN_CENTER`, `ALIGN_RIGHT`). |
| `gui:text_field(sequence text = "", integer columns = 20) -> atom` | Single-line text input. |
| `gui:text_area(sequence text = "", integer rows = 5, integer cols = 20) -> atom` | Multi-line text area. |
| `gui:scroll_pane(atom client_widget) -> atom` | Scrolling wrapper. |
| `gui:button(sequence text, integer on_click_rid = 0) -> atom` | Pushbutton with click callback. |
| `gui:check_box(sequence text, integer checked = 0) -> atom` | Checkbox. |
| `gui:radio_button(sequence text, integer selected = 0) -> atom` | Radio button. |
| `gui:combo_box(sequence items = {}) -> atom` | Dropdown selection box. |
| `gui:progress_bar(integer min_val = 0, integer max_val = 100) -> atom` | Progress bar with text display. |
| `gui:slider(integer min_val = 0, integer max_val = 100, integer init_val = 50) -> atom` | Slider control. |
| `gui:panel(integer layout_type = FLOW_LAYOUT, ...)` | Container panel. |

---

### 4.6 Properties, Styling & Padding

* `gui:set_text(widget, text)` / `gui:get_text(widget) -> sequence`
* `gui:set_value(widget, val)` / `gui:get_value(widget) -> integer`
* `gui:is_selected(widget) -> integer` / `gui:set_selected(widget, selected)`
* `gui:set_padding(widget, top, left, bottom, right)`
* `gui:set_font(widget, name = "Ubuntu", size = 13, is_bold = 0)`
* `gui:set_enabled(widget, enabled)`

---

### 4.7 Standard Dialogs (Message, Input, Confirm, FileDialog)

* `gui:msgbox(title, message, icon_type = MSG_INFO)`: Dialog (`MSG_INFO`, `MSG_WARN`, `MSG_ERROR`, `MSG_QUESTION`).
* `gui:input_box(title, prompt, default_val = "") -> sequence`: Text input dialog.
* `gui:confirm_box(title, message) -> integer`: Returns `1` for Yes, `0` for No.
* `gui:file_dialog(title = "Select File", is_save = 0, start_dir = ".") -> sequence`: File dialog returning path or `""`.

---

### 4.8 Complete Demo Application (`demo/gui_demo.ex`)

```euphoria
include std/gui.e as gui
include std/text.e

atom win = gui:window("OpenEuphoria 4.1 GUI Demo (Java 25 Swing & GTK)", 620, 460)
gui:set_layout(win, gui:BORDER_LAYOUT)
gui:set_padding(win, 12, 14, 12, 14)

-- Header
atom pnl_top = gui:panel(gui:GRID_LAYOUT, 2, 1, 0, 6)
atom lbl_title = gui:text_label("OpenEuphoria GUI: Native Linux Desktop", gui:ALIGN_CENTER)
gui:set_font(lbl_title, "Ubuntu", 17, 1)
atom lbl_sub = gui:text_label("100% UTF-8 Support for Umlauts (ä, ö, ü, ß) & Modern Fonts", gui:ALIGN_CENTER)
gui:set_font(lbl_sub, "Ubuntu", 12, 0)
gui:add(pnl_top, lbl_title)
gui:add(pnl_top, lbl_sub)
gui:add(win, pnl_top, gui:NORTH)

-- Form panel
atom pnl_center = gui:panel(gui:GRID_LAYOUT, 5, 2, 14, 12)
atom lbl_name = gui:text_label("User Name:")
atom txt_name = gui:text_field("Euphoria Developer", 20)
atom lbl_lang = gui:text_label("Target Platform:")
atom cmb_lang = gui:combo_box({"Linux 64-Bit (Max Performance)", "Ubuntu / Debian", "Arch / Fedora"})
atom lbl_mode = gui:text_label("Preferences:")
atom cb_expert = gui:check_box("Enable automatic validation", 1)
atom lbl_pbar = gui:text_label("Progress:")
atom pbar = gui:progress_bar(0, 100)
gui:set_value(pbar, 65)
atom lbl_status_title = gui:text_label("Status:")
atom lbl_status = gui:text_label("Ready for actions")
gui:set_font(lbl_status, "Ubuntu", 12, 1)

gui:add(pnl_center, lbl_name)
gui:add(pnl_center, txt_name)
gui:add(pnl_center, lbl_lang)
gui:add(pnl_center, cmb_lang)
gui:add(pnl_center, lbl_mode)
gui:add(pnl_center, cb_expert)
gui:add(pnl_center, lbl_pbar)
gui:add(pnl_center, pbar)
gui:add(pnl_center, lbl_status_title)
gui:add(pnl_center, lbl_status)
gui:add(win, pnl_center, gui:CENTER)

-- Callbacks
integer count = 0
procedure on_submit(atom sender)
    count += 1
    sequence name = gui:get_text(txt_name)
    gui:set_text(lbl_status, sprintf("Action #%d executed for '%s'", {count, name}))
    gui:msgbox("Confirmation", 
        sprintf("Hello %s!\n\nAction processed in Swing event thread!\nUmlauts test: ä ö ü Ä Ö Ü ß", {name}),
        gui:MSG_INFO)
end procedure

procedure on_file_pick(atom sender)
    sequence path = gui:file_dialog("Select File", 0, ".")
    if length(path) > 0 then
        gui:set_text(lbl_status, "Selected: " & path)
    end if
end procedure

procedure on_quit(atom sender)
    gui:close_window(win)
end procedure

-- Buttons
atom pnl_bottom = gui:panel(gui:FLOW_LAYOUT)
atom btn_submit = gui:button("Execute Action", routine_id("on_submit"))
atom btn_file   = gui:button("Select File...", routine_id("on_file_pick"))
atom btn_quit   = gui:button("Close",          routine_id("on_quit"))
gui:add(pnl_bottom, btn_submit)
gui:add(pnl_bottom, btn_file)
gui:add(pnl_bottom, btn_quit)
gui:add(win, pnl_bottom, gui:SOUTH)

gui:show(win)
gui:wait_window(win)
```

---

## 5. UTF-8 String Processing (`std/utf8.e` & VM Engine)

1. **Source String Literals**:
   Source files read as UTF-8. Non-ASCII characters (`c > 127`, e.g. `ä`, `ö`, `ü`, `ß`, `€`) encode as UTF-8 multi-byte sequences in the constant pool (`"ü"` $\rightarrow$ `{195, 188}`).
2. **Robust Decoding in `Value.toUtf8String()`**:
   When passed to Java (Swing, JDBC, HTTP, JSON), byte sequences decode losslessly. Malformed bytes fall back to ISO-8859-1, preventing replacement character corruption (`\uFFFD`).
3. **Character-Accurate Operations (`std/utf8.e`)**:
   * `utf8:len(s)`: Total Unicode codepoints.
   * `utf8:slice(s, start_cp, end_cp)`: Slices by character position rather than byte index.
   * `utf8:upper(s)` / `utf8:lower(s)`: Full Unicode case mapping.
   * `utf8:to_codepoints(s)` / `utf8:from_codepoints(cps)`: Translates to and from 32-bit codepoint integers.

---

## 6. JSON & RFC 9535 JSONPath (`std/json.e`)

Powered by **Jackson Databind**:
* High-speed parsing and serialization (`json:parse`, `json:stringify`, `json:pretty`).
* **RFC 9535 JSONPath**: Evaluates complex path expressions with filters:
  ```euphoria
  sequence r = json:path_query(doc, "$.store.book[?(@.price < 10)].title")
  ```
* Seamless interoperability with database query results (`sqlite:query_assoc`, `pgsql:query_assoc`).

---

## 7. JSON-Schema Draft 2020-12 (`std/json_schema.e`)

Validates structures against **Draft 2020-12**:
* `json_schema:validate(data, schema) -> sequence`: Returns `{valid, error_list}`.
* `json_schema:is_valid(data, schema) -> integer`: Boolean validation (`1` or `0`).

---

## 8. XML DOM, W3C XPath 1.0 & XSD (`std/xml.e`)

Powered by JDK XML modules (`javax.xml.parsers`, `javax.xml.xpath`, `javax.xml.validation`):
* **DOM**: `xml:parse(xml_str)`, `xml:stringify(node)`, `xml:element()`, `xml:tag()`, `xml:text()`, `xml:attr()`.
* **W3C XPath 1.0**: `xml:xpath(doc, "//catalog/book[@id='B1']/title")` or scalar aggregations `xml:xpath(doc, "sum(//price)")`.
* **XSD Schema Validation**: `xml:validate_xsd(doc, xsd_str)`.

---

## 9. SQL Databases: SQLite 3 (`std/sqlite.e`) & PostgreSQL (`std/pgsql.e`)

Both modules share an **identical unified API** via JDBC:

| Function | SQLite 3 (`std/sqlite.e`) | PostgreSQL (`std/pgsql.e`) |
|---|---|---|
| Connect | `sqlite:open("data.db")` | `pgsql:open("postgresql://user:pass@host:5432/db")` |
| Close | `sqlite:close(db)` | `pgsql:close(db)` |
| DDL/DML | `sqlite:exec(db, sql, params)` | `pgsql:exec(db, sql, params)` |
| SELECT (Rows) | `sqlite:query(db, sql, params)` | `pgsql:query(db, sql, params)` |
| SELECT (JSON Objects) | `sqlite:query_assoc(db, sql, params)` | `pgsql:query_assoc(db, sql, params)` |
| Scalar Value | `sqlite:query_value(db, sql, params)` | `pgsql:query_value(db, sql, params)` |
| Transactions | `sqlite:begin`, `commit`, `rollback` | `pgsql:begin`, `commit`, `rollback` |

---

## 10. HTTP & HTTPS Client and Server (`std/http.e`)

* **Client**: Built on Java 25 `HttpClient`:
  `http:get`, `http:post`, `http:post_json`, `http:put`, `http:delete_req`, `http:request`. Supports custom headers, timeouts, and automatic TLS verification.
* **Server**: Built on `com.sun.net.httpserver` with virtual thread execution:
  `http:server_create(port)`, `http:route(srv, method, path, handler_rid)`, `http:response_json(status, body)`, `http:server_background(srv)`.

---

## 11. Dual-Stack Networking & Sockets (`std/socket.e` & `std/net/dns.e`)

NIO socket channels supporting IPv4 and IPv6:
* `sockets:tcp_connect(host, port, timeout_ms)`
* `sockets:tcp_listen(port, bind_addr, backlog)`
* `sockets:tcp_accept(srv_sock, timeout_ms)`
* `sockets:send_all(sock, data)`
* `sockets:recv_line(sock)`

---

## 12. Demos, Examples & Execution

Example applications reside in `demo/` and `examples/`:

```bash
# 1. Run interactive Desktop GUI
./euphorix demo/gui_demo.ex

# 2. REST API Microservice with SQLite & Schema validation
./euphorix examples/05_rest_api_microservice.ex

# 3. Database integration tests
./euphorix examples/04_sqlite_datenbank.ex
./euphorix examples/06_postgresql_datenbank.ex

# 4. XML & XPath
./euphorix examples/03_xml_xpath_xsd.ex

# 5. Run test suites
./tools/run_all_tests ./euphorix tests/t_gui.e tests/t_java_interop.e tests/t_concurrency.ex
```

---

## 13. Modern Concurrency: Virtual Threads, Async/Await & Channels (`std/thread.e`, `std/channel.e`, `std/task.e`)

Java 25 Virtual Threads (Project Loom) eliminate the historical single-core bottleneck of OpenEuphoria. Blocking network, database, or disk I/O operations will never freeze the application. Three unified approaches cover all use cases:

### 13.1 Approach 1: Classic Tasks with Virtual Threads (`task:create_thread`)

The `std/task.e` module maintains 100% backward compatibility with classic cooperative multitasking, while offering `create_thread` to run tasks on preemptive, multi-core Java 25 Virtual Threads:

```euphoria
include std/task.e
include std/thread.e

procedure worker(sequence name)
    for i = 1 to 5 do
        thread:sleep(0.1) -- Does NOT block the main program!
        printf(1, "Task %s: Step %d\n", {name, i})
    end for
end procedure

-- Spawn as independent Virtual Threads on multi-core CPU:
atom t1 = task:create_thread(routine_id("worker"), {"A"})
atom t2 = task:create_thread(routine_id("worker"), {"B"})
```

### 13.2 Approach 2: Channels / Go-Style Concurrency (`std/channel.e`)

Thread-safe message pipes (CSP - Communicating Sequential Processes) enable lock-free data transfer without deadlocks or race conditions:

```euphoria
include std/thread.e
include std/channel.e

atom ch = channel:new(10) -- Buffered channel with capacity 10

procedure producer(atom out_ch)
    for i = 1 to 5 do
        channel:send(out_ch, sprintf("Packet #%d", {i}))
    end for
    channel:close(out_ch)
end procedure

thread:spawn(routine_id("producer"), {ch})

-- Consumer drains channel until closed:
while 1 do
    sequence msg = channel:receive(ch)
    if msg[1] != channel:OK then exit end if
    printf(1, "Received: %s\n", {msg[2]})
end while
```

### 13.3 Approach 3: Async / Await Futures (`std/thread.e`)

The most developer-friendly concurrency pattern: launch asynchronous computations in the background and retrieve results synchronously when needed:

```euphoria
include std/thread.e

function compute_heavy_task(atom x)
    thread:sleep(0.05)
    return x * x
end function

-- Run concurrently in the background:
atom job1 = thread:async(routine_id("compute_heavy_task"), {7})
atom job2 = thread:async(routine_id("compute_heavy_task"), {12})

-- Main thread continues execution (e.g., rendering UI or handling events):
if not thread:is_done(job1) then
    puts(1, "Job 1 is still processing in background...\n")
end if

-- Wait for and retrieve results:
atom res1 = thread:await(job1)
atom res2 = thread:await(job2)

-- Or await multiple jobs in parallel:
-- sequence all_results = thread:await_all({job1, job2})
```

