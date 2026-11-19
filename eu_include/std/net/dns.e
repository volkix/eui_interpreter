--****
-- == DNS
--
-- <<LEVELTOC level=2 depth=4>>
--

namespace dns

enum M_SOCK_GETHOSTBYNAME = 79, M_SOCK_GETHOSTBYADDR

--****
-- ===  Constants

public enum ADDR_FLAGS, ADDR_FAMILY, ADDR_TYPE, ADDR_PROTOCOL, ADDR_ADDRESS

public enum HOST_OFFICIAL_NAME, HOST_ALIASES, HOST_IPS, HOST_TYPE

public constant
	DNS_QUERY_STANDARD = 0,
	DNS_QUERY_ACCEPT_TRUNCATED_RESPONSE = 1,
	DNS_QUERY_USE_TCP_ONLY = 2,
	DNS_QUERY_NO_RECURSION = 4,
	DNS_QUERY_BYPASS_CACHE = 8,
	DNS_QUERY_NO_WIRE_QUERY = 16,
	DNS_QUERY_NO_LOCAL_NAME = 32,
	DNS_QUERY_NO_HOSTS_FILE = 64,
	DNS_QUERY_NO_NETBT = 128,
	DNS_QUERY_WIRE_ONLY = 256,
	DNS_QUERY_RETURN_MESSAGE = 512,
	DNS_QUERY_TREAT_AS_FQDN = #1000,
	DNS_QUERY_DONT_RESET_TTL_VALUES = #100000,
	DNS_QUERY_RESERVED = #FF000000,

	NS_C_IN = 1,
	NS_C_ANY = 255,
	NS_KT_RSA = 1,
	NS_KT_DH = 2,
	NS_KT_DSA = 3,
	NS_KT_PRIVATE = 254,
	NS_T_A = 1,
	NS_T_NS = 2,
	NS_T_PTR = 12,
	NS_T_MX = 15,
	NS_T_AAAA = 28,
	NS_T_A6 = 38,
	NS_T_ANY = 255

--****
-- === General Routines



--**
-- Get the host information by name.
--
-- Parameters:
--   # ##name## : host name
--
-- Returns:
--   A ##sequence##, containing
--   <eucode>
--   {
--     official name,
--     { alias1, alias2, ... },
--     { ip1, ip2, ... },
--     address_type
--   }
--   </eucode>
--
-- Example 1:
-- <eucode>
-- object data = host_by_name("www.google.com")
-- -- data = {
-- --   "www.l.google.com",
-- --   {
-- --     "www.google.com"
-- --   },
-- --   {
-- --     "74.125.93.104",
-- --     "74.125.93.147",
-- --     ...
-- --   },
-- --   2
-- -- }
-- </eucode>
--

public function host_by_name(sequence name)
	return machine_func(M_SOCK_GETHOSTBYNAME, { name })
end function

--**
-- Get the host information by address.
--
-- Parameters:
--   # ##address## : host address
--
-- Returns:
--   A ##sequence##, containing
--   <eucode>
--   {
--     official name,
--     { alias1, alias2, ... },
--     { ip1, ip2, ... },
--     address_type
--   }
--   </eucode>
--
-- Example 1:
-- <eucode>
-- object data = host_by_addr("74.125.93.147")
-- -- data = {
-- --   "www.l.google.com",
-- --   {
-- --     "www.google.com"
-- --   },
-- --   {
-- --     "74.125.93.104",
-- --     "74.125.93.147",
-- --     ...
-- --   },
-- --   2
-- -- }
-- </eucode>
--

public function host_by_addr(sequence address)
	return machine_func(M_SOCK_GETHOSTBYADDR, { address })
end function
