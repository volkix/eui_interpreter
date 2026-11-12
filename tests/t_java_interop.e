include std/unittest.e
include std/java.e as java
include std/filesys.e as fs

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Static methods in JDK
test_equal("Math:max", 20, java:call_static("java.lang.Math", "max", {10, 20}))
test_equal("Math:min", 10, java:call_static("java.lang.Math", "min", {10, 20}))
test_equal("Math:sqrt", 12.0, java:call_static("java.lang.Math", "sqrt", {144.0}))
test_equal("String:valueOf", "42", java:call_static("java.lang.String", "valueOf", {42}))

atom now_ms = java:call_static("java.lang.System", "currentTimeMillis", {})
test_true("System:currentTimeMillis", now_ms > 1000000000000)

-- 2. Static fields in JDK
atom pi = java:get_field("java.lang.Math", "PI")
test_true("Math:PI", pi > 3.1415 and pi < 3.1416)
test_equal("Integer:MAX_VALUE", 2147483647, java:get_field("java.lang.Integer", "MAX_VALUE"))

-- 3. Object instantiation and instance methods: StringBuilder
atom sb = java:new_object("java.lang.StringBuilder", {"Euphoria"})
test_true("new StringBuilder", sb > 0)
java:call_method(sb, "append", {" + Java 25"})
test_equal("StringBuilder:toString", "Euphoria + Java 25", java:call_method(sb, "toString", {}))
test_equal("java:to_string(sb)", "Euphoria + Java 25", java:to_string(sb))

-- 4. Object instantiation and instance methods: ArrayList
atom list = java:new_object("java.util.ArrayList", {})
test_true("new ArrayList", list > 0)
java:call_method(list, "add", {"Apfel"})
java:call_method(list, "add", {"Banane"})
test_equal("ArrayList:size", 2, java:call_method(list, "size", {}))
test_equal("ArrayList:get(0)", "Apfel", java:call_method(list, "get", {0}))
test_equal("ArrayList:get(1)", "Banane", java:call_method(list, "get", {1}))

-- 5. Dynamic JAR loading and custom class calls
sequence jar_path = "demo/test_calc.jar"
if not fs:file_exists(jar_path) then
    jar_path = "../demo/test_calc.jar"
end if

test_equal("java:load_jar", 1, java:load_jar(jar_path))

atom cls = java:find_class("testpkg.Calculator")
test_true("find_class Calculator", cls > 0)

test_equal("Calculator:add", 42, java:call_static("testpkg.Calculator", "add", {15, 27}))
test_equal("Calculator:greet", "Hallo Euphoria", java:call_static("testpkg.Calculator", "greet", {"Euphoria"}))

atom calc = java:new_object("testpkg.Calculator", {7})
test_true("new Calculator", calc > 0)
test_equal("Calculator:multiply #1", 42, java:call_method(calc, "multiply", {6}))
test_equal("Calculator:get_field multiplier", 7, java:get_field(calc, "multiplier"))

test_equal("Calculator:set_field multiplier", 1, java:set_field(calc, "multiplier", 10))
test_equal("Calculator:multiply #2", 60, java:call_method(calc, "multiply", {6}))

test_report()
