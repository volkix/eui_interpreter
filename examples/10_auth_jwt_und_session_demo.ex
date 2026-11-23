-- ==============================================================================
-- Euphorix 1.0 Demo: Authentication, JWT & HTTP Sessions
-- ==============================================================================

include std/console.e
include std/auth.e as auth
include std/session.e as session

puts(1, "=====================================================================\n")
puts(1, "  Euphorix Enterprise Security Demo (Auth, JWT, Sessions)\n")
puts(1, "=====================================================================\n\n")

-- 1. Passwort-Hashing mit PBKDF2
sequence passwort = "MeinStrengGeheimesPasswort!2026"
puts(1, "1) Passwort-Hashing (PBKDF2 mit 65.536 Runden & Zufalls-Salt):\n")
printf(1, "   Klartext: '%s'\n", {passwort})

sequence hash_str = auth:hash_password(passwort)
printf(1, "   Hash    : %s\n", {hash_str})

integer check_ok = auth:verify_password(passwort, hash_str)
integer check_wrong = auth:verify_password("FalschesPasswort", hash_str)
printf(1, "   Prüfung korrektes Passwort : %d (1 = Gültig)\n", {check_ok})
printf(1, "   Prüfung falsches Passwort  : %d (0 = Abgelehnt)\n\n", {check_wrong})

-- 2. JSON Web Tokens (JWT) mit HS256
puts(1, "2) JSON Web Tokens (JWT) für REST-APIs & Microservices:\n")
sequence payload = `{"sub":"user_1042","name":"Volker Schulte","role":"admin"}`
sequence api_secret = "mein-intranet-geheimschluessel-2026"

sequence jwt = auth:create_jwt(payload, api_secret, 7200)
printf(1, "   Generierter Token:\n   %s\n\n", {jwt})

sequence jwt_result = auth:verify_jwt(jwt, api_secret)
if jwt_result[1] = 1 then
    printf(1, "   ✓ Token-Signatur gültig! Extrahierte Payload:\n   %s\n\n", {jwt_result[2]})
end if

-- 3. Server-Sessions & Cookie Management
puts(1, "3) HTTP Session-Verwaltung & Cookie-Headers:\n")
sequence sess = session:start()
sequence sid = sess[1]
printf(1, "   Neue Session erstellt, ID: %s\n", {sid})

session:set(sid, "user", "vschulte")
session:set(sid, "theme", "dark")
session:set(sid, "permissions", {"read", "write", "export"})

printf(1, "   Gespeicherte Attribute: User='%s', Theme='%s'\n",
       {session:get(sid, "user"), session:get(sid, "theme")})

sequence cookie = session:cookie_header(sid, 86400)
printf(1, "   HTTP Set-Cookie Header:\n   %s\n\n", {cookie})

puts(1, "=== Demo erfolgreich beendet! ===\n")
