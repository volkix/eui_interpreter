--****
-- == Java Interoperability
--
-- Exposes Java Virtual Machine reflection, dynamic JAR loading, object creation,
-- method invocation, and field manipulation to OpenEuphoria.
--

namespace java

public constant
    M_JAVA_LOAD_JAR        = 300,
    M_JAVA_FIND_CLASS       = 301,
    M_JAVA_NEW              = 302,
    M_JAVA_CALL_STATIC      = 303,
    M_JAVA_CALL_METHOD      = 304,
    M_JAVA_GET_FIELD        = 305,
    M_JAVA_SET_FIELD        = 306,
    M_JAVA_TO_STRING        = 307,
    M_JAVA_CREATE_LISTENER  = 308

--**
-- Loads a .jar archive into the runtime classpath dynamically.
--
-- Parameters:
--   # jar_path: Path to the .jar file
--
-- Returns:
--   1 on success, 0 on failure
--
public function load_jar(sequence jar_path)
    return machine_func(M_JAVA_LOAD_JAR, jar_path)
end function

--**
-- Resolves a Java class by its fully-qualified name or simple name in java.lang.
--
-- Parameters:
--   # class_name: String e.g. "java.lang.Math", "java.util.ArrayList"
--
-- Returns:
--   Class handle (>0) or 0 if not found.
--
public function find_class(sequence class_name)
    return machine_func(M_JAVA_FIND_CLASS, class_name)
end function

--**
-- Instantiates a new Java object using the best matching constructor.
--
-- Parameters:
--   # class_or_name: Class handle (atom) or class name (sequence)
--   # args: Sequence of constructor arguments (default {})
--
-- Returns:
--   Object handle (>0) or 0 on failure.
--
public function new_object(object class_or_name, sequence args = {})
    return machine_func(M_JAVA_NEW, {class_or_name, args})
end function

--**
-- Invokes a static method on a Java class.
--
-- Parameters:
--   # class_or_name: Class handle (atom) or class name (sequence)
--   # method_name: Method name string
--   # args: Sequence of arguments (default {})
--
-- Returns:
--   Method result converted to Euphoria value, or 0.
--
public function call_static(object class_or_name, sequence method_name, sequence args = {})
    return machine_func(M_JAVA_CALL_STATIC, {class_or_name, method_name, args})
end function

--**
-- Invokes an instance method on a Java object handle.
--
-- Parameters:
--   # obj_handle: Java object handle (atom)
--   # method_name: Method name string
--   # args: Sequence of arguments (default {})
--
-- Returns:
--   Method result converted to Euphoria value, or 0.
--
public function call_method(atom obj_handle, sequence method_name, sequence args = {})
    return machine_func(M_JAVA_CALL_METHOD, {obj_handle, method_name, args})
end function

--**
-- Retrieves the value of a public field from a class or object.
--
-- Parameters:
--   # target_or_class: Object handle, class handle, or class name
--   # field_name: Field name string
--
-- Returns:
--   Field value converted to Euphoria.
--
public function get_field(object target_or_class, sequence field_name)
    return machine_func(M_JAVA_GET_FIELD, {target_or_class, field_name})
end function

--**
-- Sets the value of a public field on a class or object.
--
-- Parameters:
--   # target_or_class: Object handle, class handle, or class name
--   # field_name: Field name string
--   # val: Value to set
--
-- Returns:
--   1 on success, 0 on failure.
--
public function set_field(object target_or_class, sequence field_name, object val)
    return machine_func(M_JAVA_SET_FIELD, {target_or_class, field_name, val})
end function

--**
-- Calls toString() on a Java object handle and returns the Euphoria string.
--
-- Parameters:
--   # obj_handle: Java object handle (atom)
--
-- Returns:
--   Euphoria sequence string.
--
public function to_string(atom obj_handle)
    return machine_func(M_JAVA_TO_STRING, obj_handle)
end function

--**
-- Creates a dynamic proxy implementing a Java listener interface
-- (e.g. ActionListener, WindowListener, Runnable) which routes method
-- calls to a Euphoria routine.
--
-- Parameters:
--   # interface_class_or_name: Interface name string or class handle
--   # routine_id: Euphoria routine ID from routine_id()
--
-- Returns:
--   Proxy listener object handle (atom) or 0 on error.
--
public function create_listener(object interface_class_or_name, integer routine_id)
    return machine_func(M_JAVA_CREATE_LISTENER, {interface_class_or_name, routine_id})
end function
