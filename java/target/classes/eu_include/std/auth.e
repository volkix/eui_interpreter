--****
-- == Authentication, Cryptography & JWT Engine for Euphorix (std/auth.e)
--
-- Provides enterprise security functions:
-- * Secure Password Hashing (PBKDF2-HMAC-SHA256 with 65,536 iterations and salt)
-- * Constant-time Password Hash Verification against timing attacks
-- * JSON Web Token (JWT) creation and cryptographic verification (HS256)
-- * Cryptographically Secure Random Token generation for session IDs and CSRF tokens
--

namespace auth

constant
    M_CRYPTO_HASH   = 343,
    M_CRYPTO_VERIFY = 344,
    M_JWT_CREATE    = 345,
    M_JWT_VERIFY    = 346,
    M_CRYPTO_RANDOM = 347

--**
-- Hash a password with salt using PBKDF2-HMAC-SHA256.
-- If `salt` is empty, a cryptographically secure 16-byte random salt is generated.
-- Returns formatted string: `"pbkdf2$65536$<salt_hex>$<hash_hex>"`.
public function hash_password(sequence password, sequence salt = "")
    return machine_func(M_CRYPTO_HASH, {password, salt})
end function

--**
-- Verify a plaintext password against a stored PBKDF2 hash string in constant time.
-- Returns `1` if the password matches, `0` otherwise.
public function verify_password(sequence password, sequence hash_str)
    return machine_func(M_CRYPTO_VERIFY, {password, hash_str})
end function

--**
-- Generate a cryptographically secure random token (hex-encoded).
-- `byte_count` specifies the random entropy size (default: 32 bytes -> 64 hex characters).
public function random_token(integer byte_count = 32)
    return machine_func(M_CRYPTO_RANDOM, byte_count)
end function

--**
-- Create a JSON Web Token (JWT) with HS256 signature.
--
-- Parameters:
-- * `payload`: JSON string (e.g. `'{"user":"admin","role":"supervisor"}'`)
-- * `secret_key`: Cryptographic secret key used to sign the token
-- * `expiry_secs`: Expiration time in seconds from now (default: 3600 = 1 hour, `0` for none)
--
-- Returns compact token string: `"header.payload.signature"`.
public function create_jwt(sequence payload, sequence secret_key, integer expiry_secs = 3600)
    return machine_func(M_JWT_CREATE, {payload, secret_key, expiry_secs})
end function

--**
-- Verify and decode a JSON Web Token (JWT).
--
-- Parameters:
-- * `token`: Compact JWT string
-- * `secret_key`: Secret key used for signature verification
--
-- Returns `{1, payload_json_string}` on success.
-- On verification failure or expired token, returns `{0, error_message}`.
public function verify_jwt(sequence token, sequence secret_key)
    return machine_func(M_JWT_VERIFY, {token, secret_key})
end function
