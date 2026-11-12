# OpenEuphoria 4.x Enterprise Edition (Java 25 Runtime)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Java 25](https://img.shields.io/badge/Java-25%20(Loom%20%7C%20FFM)-orange.svg)](https://openjdk.org/)
[![Platform](https://img.shields.io/badge/Platform-Linux%2064--bit%20%7C%20Windows-green.svg)]()
[![Tests](https://img.shields.io/badge/Tests-100%25%20Passing-brightgreen.svg)]()

A clean-room, register-based Virtual Machine and standard library implementation for **OpenEuphoria 4.x** powered by **Java 25**, featuring **Virtual Threads (Project Loom)**, native **Java Interoperability**, **Swing GUI**, **Go-Style Concurrency & Async/Await**, and enterprise SQL database drivers.

Available as both a portable JAR executable (`eui.jar`) and a **completely self-contained 53 MB single-binary** (`eui-standalone`) requiring no pre-installed Java.

---

## 📖 Documentation

* 🇩🇪 **[HANDBUCH.md](HANDBUCH.md)** – Vollständiges deutschsprachiges Handbuch (13 Kapitel, vollständige API- und Sprachreferenz).
* 🇬🇧 **[MANUAL.md](MANUAL.md)** – Comprehensive English User & Developer Manual.

---

## 🚀 Key Highlights & Architecture

* **Clean-Room Register-Based VM**: 65,536 registers with Copy-on-Write (CoW) memory semantics, fast opcode dispatch, and high-precision 48-bit integers & 64-bit IEEE-754 floats.
* **Modern Multi-Core Concurrency**:
  * **Virtual Threads**: Non-blocking I/O across CPU cores via Java 25 (`task:create_thread`, `thread:spawn`).
  * **Async / Await**: Effortless asynchronous computation with Futures (`thread:async`, `thread:await`, `thread:await_all`).
  * **Go-Style Channels**: Communicating Sequential Processes (CSP) for lock-free, deadlock-safe message passing (`std/channel.e`).
* **Direct Java Interoperability (`std/java.e`)**:
  * Call any Java method or load arbitrary JARs directly from Euphoria (`java:call_static`, `java:new_instance`).
  * Seamless bidirectional data type conversion and dynamic Proxy Event Listeners (`java:create_listener`).
* **Native Desktop GUI (`std/gui.e`)**:
  * Rich Swing/AWT desktop widgets with Subpixel Font Antialiasing.
  * Modern theme support: **FlatLaf** (Dark & Light), **GTK+**, and **Nimbus**.
* **Enterprise Database Engines**:
  * **SQLite 3.47**: Statically linked via JDBC (`std/sqlite.e`), transactions, and JSON export.
  * **PostgreSQL 42.7**: High-performance pure-Java driver (`std/pgsql.e`).
* **Enterprise Data Formats & Protocols**:
  * **UTF-8**: Full Unicode-aware string slicing, search, and casing (`std/utf8.e`).
  * **JSON & JSONPath**: RFC 9535 JSONPath and Draft 2020-12 Schema validation (`std/json.e`, `std/json_schema.e`).
  * **XML**: W3C XPath 1.0 DOM and XSD Schema validation (`std/xml.e`).
  * **HTTP/HTTPS**: Asynchronous HTTP client & multi-threaded server (`std/http.e`).
* **Dual-Platform Ready**:
  * **Linux 64-bit**: `./eui-java` (shell wrapper) and `./eui-standalone` (self-extracting binary).
  * **Microsoft Windows**: `eui.cmd` and `eui.bat` launchers with dynamic platform adaptation.

---

## 📦 Quick Start

### 1. Interactive REPL
```bash
# Launch interactive REPL
./eui-java
```

### 2. Run a Euphoria Script
```bash
# Linux (with Java 25 installed)
./eui-java my_script.ex

# Linux (Standalone, zero dependencies)
./eui-standalone my_script.ex

# Windows
eui.cmd my_script.ex
```

### 3. Run the Desktop GUI Demo
```bash
./eui-java demo/gui_demo.ex
```

---

## 💡 Code Examples

### Concurrency: Async / Await & Go-Style Channels
```euphoria
include std/thread.e
include std/channel.e

-- 1. Async / Await Future:
function heavy_calc(atom n)
    thread:sleep(0.1)
    return n * n
end function

atom job = thread:async(routine_id("heavy_calc"), {42})
-- Main thread continues execution freely...
atom result = thread:await(job) -- 1764

-- 2. Go-Style Channel Communication:
atom box = channel:new(5)

procedure producer(atom ch)
    for i = 1 to 3 do
        channel:send(ch, sprintf("Item #%d", {i}))
    end for
end procedure

thread:spawn(routine_id("producer"), {box})
for i = 1 to 3 do
    puts(1, channel:read(box) & "\n")
end for
```

### Java Interop & Swing GUI
```euphoria
include std/gui.e
include std/java.e

gui:set_theme("flatlaf-dark")

atom win = gui:window("OpenEuphoria Enterprise", 450, 300)
atom lbl = gui:text_label("Welcome to Java 25 Euphoria!")
atom btn = gui:button("Click Me")

procedure on_click(atom sender)
    java:call_static("javax.swing.JOptionPane", "showMessageDialog", {0, "Hello from Euphoria!"})
end procedure

gui:on_click(btn, routine_id("on_click"))
gui:add(win, lbl)
gui:add(win, btn)
gui:show(win)
gui:wait_window(win)
```

---

## 🛠️ Build & Verification

The project is built using **GNU Make** and **Apache Maven** with Java 25:

```bash
# Build eui.jar and eui-java wrapper
make

# Build self-contained single-binary (bundles minimal JRE via jlink)
make standalone

# Run the complete test suite (examples, GUI, Java interop, Concurrency)
make test

# Run tests against the self-contained standalone binary
make test-standalone
```

---

## 📁 Repository Structure

```
├── HANDBUCH.md            # Comprehensive German manual (13 chapters)
├── MANUAL.md              # Comprehensive English manual (13 chapters)
├── README.md              # Project overview & quick start
├── LICENSE                # GNU General Public License v3.0
├── Makefile               # Build & test automation
├── pom.xml                # Maven project definition (FlatLaf, SQLite, PostgreSQL, Jackson)
├── eui-java               # Linux executable shell launcher
├── eui.cmd / eui.bat      # Windows executable batch launchers
├── eui.jar                # Shaded executable Fat-JAR (19 MB)
├── eui-standalone         # Self-extracting single binary with minimal JRE (53 MB)
├── eu_include/            # OpenEuphoria standard library
│   └── std/
│       ├── thread.e       # Virtual Threads & Async/Await
│       ├── channel.e      # Go-Style CSP Channels
│       ├── task.e         # Cooperative & Preemptive Tasks
│       ├── gui.e          # Swing Desktop GUI & Themes
│       ├── java.e         # Dynamic Java Reflection Interop
│       ├── sqlite.e       # SQLite 3 Database Engine
│       ├── pgsql.e        # PostgreSQL Database Engine
│       ├── utf8.e         # UTF-8 Unicode String Engine
│       └── ...
├── java/src/main/java/eu/ # Java 25 Clean-Room Register VM Implementation
│   ├── VM.java            # Bytecode execution loop & machine functions
│   ├── Compiler.java      # Lexical analyzer & AST compiler
│   ├── JavaInterop.java   # Dynamic reflection & proxy bridge
│   ├── Sequence.java      # Copy-on-Write Euphoria sequence
│   └── Value.java         # Tagged union values & NaN-boxing
├── demo/                  # Interactive GUI demonstrations
├── examples/              # REST microservices, database, XML, and stdlib examples
├── tests/                 # Unit & regression tests (100% passing)
└── tools/                 # Standalone packager (`build_standalone.sh`)
```

---

## ⚖️ License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.  
See the [LICENSE](LICENSE) file for the full license text.
