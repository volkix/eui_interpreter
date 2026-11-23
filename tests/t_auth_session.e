include std/unittest.e

set_test_verbosity(TEST_SHOW_ALL)
include std/auth.e as auth
include std/session.e as session

-- 1. Test Secure Password Hashing (PBKDF2)
sequence pass = "GeheimesPasswort123!"
sequence hash1 = auth:hash_password(pass)
test_true("hash not empty", length(hash1) > 20)
test_equal("hash starts with pbkdf2", 1, match("pbkdf2$", hash1))

test_equal("verify password with correct password", 1, auth:verify_password(pass, hash1))
test_equal("verify password with wrong password", 0, auth:verify_password("FalschesPasswort", hash1))
test_equal("verify password with empty password", 0, auth:verify_password("", hash1))

-- Salt uniqueness test
sequence hash2 = auth:hash_password(pass)
test_true("hashes have different salts", not equal(hash1, hash2))
test_equal("both hashes verify correctly", 1, auth:verify_password(pass, hash2))

-- 2. Test Secure Random Token
sequence token32 = auth:random_token(32)
test_equal("token32 length is 64 hex chars", 64, length(token32))
sequence token16 = auth:random_token(16)
test_equal("token16 length is 32 hex chars", 32, length(token16))
test_true("tokens are random", not equal(token32[1..32], token16))

-- 3. Test JWT (JSON Web Tokens)
sequence secret = "mein-super-geheimer-schluessel-2026"
sequence payload = `{"sub":"user_42","user":"admin","role":"supervisor"}`
sequence jwt = auth:create_jwt(payload, secret, 3600)
test_true("jwt token string generated", length(jwt) > 30)

-- Count dots in JWT
integer dot_count = 0
for i = 1 to length(jwt) do
    if jwt[i] = '.' then dot_count += 1 end if
end for
test_equal("jwt has exactly two dots", 2, dot_count)

-- Verify valid JWT
sequence v_res = auth:verify_jwt(jwt, secret)
test_equal("jwt verify status ok", 1, v_res[1])
test_true("jwt payload contains user", match(`"user":"admin"`, v_res[2]) > 0)

-- Verify JWT with wrong secret
sequence v_fail = auth:verify_jwt(jwt, "falscher-schluessel")
test_equal("jwt verify with wrong secret fails", 0, v_fail[1])

-- Verify tampered JWT
sequence tampered_jwt = jwt
tampered_jwt[10] = 'X'
sequence v_tamper = auth:verify_jwt(tampered_jwt, secret)
test_equal("jwt verify with tampered token fails", 0, v_tamper[1])

-- 4. Test Session Management
sequence cookie_hdr = "OtherCookie=abc; EUI_SESSION=sess_12345; Theme=dark"
sequence extracted_sid = session:extract_sid(cookie_hdr)
test_equal("extracted sid from cookie", "sess_12345", extracted_sid)

sequence s_new = session:start()
test_equal("new session flag is 1", 1, s_new[2])
sequence sid = s_new[1]
test_true("session id length > 10", length(sid) > 10)

-- Set & Get attributes
session:set(sid, "username", "volkix")
session:set(sid, "logged_in", 1)
session:set(sid, "roles", {"admin", "developer"})

test_equal("session get username", "volkix", session:get(sid, "username"))
test_equal("session get logged_in", 1, session:get(sid, "logged_in"))
test_equal("session get roles count", 2, length(session:get(sid, "roles")))
test_equal("session has key", 1, session:has(sid, "username"))
test_equal("session has nonexistent key", 0, session:has(sid, "nonexistent"))
test_equal("session default fallback", "Gast", session:get(sid, "nonexistent", "Gast"))

-- Cookie Header formatting
sequence set_cookie = session:cookie_header(sid, 3600)
test_true("set-cookie contains sid", match(sid, set_cookie) > 0)
test_true("set-cookie contains HttpOnly", match("HttpOnly", set_cookie) > 0)
test_true("set-cookie contains SameSite", match("SameSite=Lax", set_cookie) > 0)

-- Destroy session
session:destroy(sid)
test_equal("session get after destroy is empty", "", session:get(sid, "username", ""))

test_report()
