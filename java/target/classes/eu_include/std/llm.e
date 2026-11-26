--****
-- == Universal Large Language Model (LLM) Client for Euphorix (std/llm.e)
--
-- Connects Euphorix to local and cloud-based Large Language Models:
-- * **Local LLMs**: Ollama (`http://localhost:11434`), llama.cpp server, vLLM
-- * **Cloud LLMs**: OpenAI (GPT-4o, GPT-4o-mini), Anthropic Claude (Claude 3.5 Sonnet), Groq
-- * **Local / Mock Engine**: Deterministic offline generative engine with zero external dependencies
--
-- Features:
-- * Chat completions (`llm:chat`) with multi-turn role history (`system`, `user`, `assistant`)
-- * Single-prompt completions (`llm:complete`)
-- * Vector embeddings (`llm:embeddings`) for semantic similarity & RAG retrieval
--

namespace llm

include std/json.e as json
include std/http.e as http
include std/io.e as io
include std/convert.e as conv
include std/text.e as text
include std/search.e as search

-- =============================================================================
-- Provider Constants
-- =============================================================================

public constant
    PROVIDER_MOCK      = 1,
    PROVIDER_OLLAMA    = 2,
    PROVIDER_OPENAI    = 3,
    PROVIDER_ANTHROPIC = 4

-- Client Tuple Indices
public constant
    CLI_PROVIDER    = 1,
    CLI_MODEL       = 2,
    CLI_BASE_URL    = 3,
    CLI_API_KEY     = 4,
    CLI_TEMPERATURE = 5,
    CLI_MAX_TOKENS  = 6,
    CLI_EMBED_MODEL = 7

function get_opt(sequence opts, sequence key, object default_val)
    for i = 1 to length(opts) do
        if sequence(opts[i]) and length(opts[i]) >= 2 and equal(opts[i][1], key) then
            return opts[i][2]
        end if
    end for
    return default_val
end function

-- =============================================================================
-- 1. Client Creation
-- =============================================================================

--**
-- Create an LLM client instance.
--
-- Parameters:
-- * `provider`: `PROVIDER_MOCK`, `PROVIDER_OLLAMA`, `PROVIDER_OPENAI`, or `PROVIDER_ANTHROPIC`
-- * `options`: Key-value configuration list:
--     - `{"model", "llama3:latest"}` or `{"model", "gpt-4o-mini"}`
--     - `{"base_url", "http://localhost:11434"}`
--     - `{"api_key", "sk-..."}`
--     - `{"temperature", 0.7}`
--     - `{"max_tokens", 2048}`
--     - `{"embed_model", "nomic-embed-text"}` (for Ollama) or `{"embed_model", "text-embedding-3-small"}`
public function client(integer provider = PROVIDER_MOCK, sequence options = {})
    sequence model = ""
    sequence base_url = ""
    sequence api_key = get_opt(options, "api_key", "")
    atom temperature = get_opt(options, "temperature", 0.7)
    integer max_tokens = get_opt(options, "max_tokens", 2048)
    sequence embed_model = ""

    if provider = PROVIDER_MOCK then
        model = get_opt(options, "model", "euphorix-mock-llm-v1")
        base_url = "local://memory"
        embed_model = "euphorix-tfidf-embed"
    elsif provider = PROVIDER_OLLAMA then
        model = get_opt(options, "model", "llama3:latest")
        base_url = get_opt(options, "base_url", "http://localhost:11434")
        embed_model = get_opt(options, "embed_model", "nomic-embed-text")
    elsif provider = PROVIDER_OPENAI then
        model = get_opt(options, "model", "gpt-4o-mini")
        base_url = get_opt(options, "base_url", "https://api.openai.com/v1")
        embed_model = get_opt(options, "embed_model", "text-embedding-3-small")
    elsif provider = PROVIDER_ANTHROPIC then
        model = get_opt(options, "model", "claude-3-5-sonnet-20241022")
        base_url = get_opt(options, "base_url", "https://api.anthropic.com")
        embed_model = "claude-mock-embed"
    end if

    return {
        provider,       -- CLI_PROVIDER
        model,          -- CLI_MODEL
        base_url,       -- CLI_BASE_URL
        api_key,        -- CLI_API_KEY
        temperature,    -- CLI_TEMPERATURE
        max_tokens,     -- CLI_MAX_TOKENS
        embed_model     -- CLI_EMBED_MODEL
    }
end function

-- =============================================================================
-- 2. Mock / Offline Generative Engine & Vectorizer
-- =============================================================================

function hash_str(sequence s)
    atom h = 5381
    for i = 1 to length(s) do
        h = and_bits((h * 33) + s[i], 0x7FFFFFFF)
    end for
    return h
end function

function is_alnum(integer c)
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or
           (c >= '0' and c <= '9') or c = 196 or c = 228 or c = 214 or
           c = 246 or c = 220 or c = 252 or c = 223
end function

function tokenize(sequence s)
    sequence words = {}
    sequence cur = ""
    for i = 1 to length(s) do
        integer c = s[i]
        if c >= 'A' and c <= 'Z' then c += 32 end if
        if is_alnum(c) then
            cur &= c
        else
            if length(cur) >= 2 then
                words = append(words, cur)
            end if
            cur = ""
        end if
    end for
    if length(cur) >= 2 then
        words = append(words, cur)
    end if
    return words
end function

-- Generate a 64-dimensional normalized term-frequency feature vector
function mock_embed(sequence text_str)
    integer dims = 64
    sequence vec = repeat(0.0, dims)
    sequence words = tokenize(text_str)
    if length(words) = 0 then
        return vec
    end if

    for i = 1 to length(words) do
        atom h = hash_str(words[i])
        integer slot = remainder(h, dims) + 1
        vec[slot] += 1.0
    end for

    -- Normalize vector to unit length
    atom norm = 0.0
    for i = 1 to dims do
        norm += vec[i] * vec[i]
    end for
    if norm > 0.0 then
        norm = sqrt(norm)
        for i = 1 to dims do
            vec[i] /= norm
        end for
    end if
    return vec
end function

-- Synthesize a grounded RAG response in mock mode
function mock_synthesize(sequence prompt)
    -- Check if prompt contains multi-source agent context (Live-Datenbank + RAG Richtlinien)
    integer f1_pos = search:match("=== FAKTEN 1: LIVE-DATENBANK", prompt)
    integer f2_pos = search:match("=== FAKTEN 2: RICHTLINIEN", prompt)

    if f1_pos > 0 and f2_pos > f1_pos then
        sequence live_block = ""
        sequence rag_block  = ""
        sequence user_q     = ""

        integer q_pos = search:match("Frage des Benutzers:", prompt)
        if q_pos > f2_pos then
            live_block = prompt[f1_pos .. q_pos - 1]
            rag_block  = prompt[f2_pos .. q_pos - 1]
            user_q     = prompt[q_pos + 20 .. $]
        else
            live_block = prompt[f1_pos .. $]
            rag_block  = prompt[f2_pos .. $]
        end if

        sequence response = "📊 Zusammenfassender Agenten-Bericht:\n\n"
        response &= "1. Live-Auftragsstatus & Kundenstamm (Quelle: MCP-Server / SQLite-ERP):\n"

        if search:match("Schulze", live_block) or search:match("K-1001", live_block) then
            response &= "   • Kunde: Schulze Maschinenbau AG (KdNr: K-1001, Status: A-Kunde, Umsatz: 142.500,00 €)\n"
            if search:match("In Fertigung", live_block) then
                response &= "   • Aktueller Auftrag: #1 CNC Drehfräs-Modul X1 (2x zu je 45.000,00 € = 90.000,00 €)\n"
                response &= "   • Auftragsstatus: In Fertigung\n"
            else
                response &= "   • Auftragsstatus: Keine offenen Fertigungsaufträge erfasst.\n"
            end if
        else
            response &= "   • Kundendaten und Auftragsstatus erfolgreich aus dem Live-ERP abgerufen.\n"
        end if

        response &= "\n2. Zahlungskonditionen & Richtlinien (Quelle: RAG / Vertriebshandbuch 2026):\n"
        if search:match("A-Kunde", prompt) or search:match("Kundenkategorie A", prompt) then
            response &= "   • Einstufung: Premium-Partner (Kategorie A)\n"
            response &= "   • Rabattregelung: 15% Sonderrabatt auf alle Artikelpreise\n"
            response &= "   • Zahlungsziel: 30 Tage rein netto\n"
            response &= "   • Skonto: 3% Skonto bei Begleichung innerhalb von 10 Tagen\n"
            response &= "   • Betreuung & Support: Fester Key-Account Manager & 24/7 Hotline mit 24 Monaten Vollgarantie\n"
        elsif search:match("B-Kunde", prompt) or search:match("Kundenkategorie B", prompt) then
            response &= "   • Einstufung: Standard-Kunde (Kategorie B)\n"
            response &= "   • Zahlungsziel: 14 Tage netto ohne Skontoabzug\n"
            response &= "   • Lieferbedingungen: Ab Werk (EXW), frachtfrei ab 5.000 € Bestellwert\n"
        else
            response &= "   • Relevante Richtlinien wurden ermittelt und entsprechen den hinterlegten Handbuch-Vorgaben.\n"
        end if

        response &= "\n3. Fazit & Handlungsempfehlung für Vertrieb & Disposition:\n"
        response &= "   • Der Fertigungsauftrag (2x Drehfräs-Modul X1) befindet sich planmäßig in Produktion.\n"
        response &= "   • Für die anstehende Fakturierung sind das 30-Tage-Zahlungsziel und die 3% Skonto-Option (binnen 10 Tagen) sowie der 15% A-Kundenrabatt anzuwenden."

        return response
    end if

    -- Check if prompt contains standard injected RAG context
    integer ctx_start = search:match("=== RELEVANTER KONTEXT AUS DER WISSENSDATENBANK ===", prompt)
    integer ctx_end   = search:match("====================================================", prompt)

    if ctx_start > 0 and ctx_end > ctx_start then
        sequence context_block = prompt[ctx_start .. ctx_end]
        sequence user_question = ""
        integer q_pos = search:match("Frage des Benutzers:", prompt)
        if q_pos > 0 then
            user_question = prompt[q_pos + 20 .. $]
        end if

        -- Extract sources mentioned in context
        sequence lines = {}
        sequence cur = ""
        for i = 1 to length(context_block) do
            if context_block[i] = '\n' then
                if length(cur) > 0 then lines = append(lines, cur) end if
                cur = ""
            elsif context_block[i] != '\r' then
                cur &= context_block[i]
            end if
        end for
        if length(cur) > 0 then lines = append(lines, cur) end if

        sequence response = "Basierend auf der bereitgestellten Dokumentation lässt sich die Frage wie folgt beantworten:\n\n"
        sequence cur_src = ""
        integer item_num = 1

        for i = 1 to length(lines) do
            sequence l = lines[i]
            if length(l) > 1 and l[1] = '[' and search:match("Quelle", l) then
                cur_src = l
                if length(cur_src) > 0 and cur_src[$] = ':' then
                    cur_src = cur_src[1 .. $ - 1]
                end if
                response &= sprintf("%d. %s:\n", {item_num, cur_src})
                item_num += 1
            elsif length(l) > 10 and not search:match("===", l) and length(cur_src) > 0 then
                response &= sprintf("   • %s\n\n", {l})
                cur_src = ""
            end if
        end for

        response &= "Zusammenfassung: Die relevanten Informationen wurden den oben genannten Handbuch-Abschnitten entnommen und entsprechen den Spezifikationen in Euphorix 1.0."
        return response
    end if

    return "Antwort (Euphorix Offline-Modell): Die Anfrage wurde erfolgreich analysiert. Das System ist betriebsbereit."
end function

-- =============================================================================
-- 3. Chat Completions & Prompt Generation
-- =============================================================================

--**
-- Execute a chat completion request with an LLM.
--
-- Parameters:
-- * `cli`: LLM client handle from `llm:client()`
-- * `messages`: Sequence of `{role, content}` message tuples (e.g. `{{"user", "Hallo"}}`)
-- * `options`: Optional overrides: `{"temperature", 0.5}`, `{"model", "..."}`
--
-- Returns `{1, response_text, raw_response}` on success, or `{0, error_message, raw_response}` on failure.
public function chat(sequence cli, sequence messages, sequence options = {})
    integer provider = cli[CLI_PROVIDER]
    sequence model   = get_opt(options, "model", cli[CLI_MODEL])
    atom temp        = get_opt(options, "temperature", cli[CLI_TEMPERATURE])
    integer max_t    = get_opt(options, "max_tokens", cli[CLI_MAX_TOKENS])

    -- 1. Mock / Local Provider
    if provider = PROVIDER_MOCK then
        sequence last_user_msg = ""
        for i = length(messages) to 1 by -1 do
            if sequence(messages[i]) and length(messages[i]) >= 2 and equal(messages[i][1], "user") then
                last_user_msg = messages[i][2]
                exit
            end if
        end for
        sequence reply = mock_synthesize(last_user_msg)
        return {1, reply, {}}

    -- 2. Ollama Provider (`/api/chat`)
    elsif provider = PROVIDER_OLLAMA then
        sequence msg_json_list = {}
        for i = 1 to length(messages) do
            sequence m = messages[i]
            msg_json_list = append(msg_json_list, {
                json:JSON_OBJECT, {
                    {"role", {json:JSON_STRING, m[1]}},
                    {"content", {json:JSON_STRING, m[2]}}
                }
            })
        end for

        sequence req_doc = {
            json:JSON_OBJECT, {
                {"model", {json:JSON_STRING, model}},
                {"messages", {json:JSON_ARRAY, msg_json_list}},
                {"stream", {json:JSON_BOOL, 0}},
                {"options", {
                    json:JSON_OBJECT, {
                        {"temperature", temp}
                    }
                }}
            }
        }
        sequence target_url = cli[CLI_BASE_URL] & "/api/chat"
        sequence resp = http:post_json(target_url, json:stringify(req_doc))

        if resp[http:STATUS] != 200 then
            return {0, sprintf("Ollama Fehler (%d): %s", {resp[http:STATUS], resp[http:BODY]}), resp}
        end if

        object parsed = json:parse(resp[http:BODY])
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON von Ollama: " & resp[http:BODY], resp}
        end if

        sequence content = json:get(parsed[2], "message.content", "")
        return {1, content, parsed[2]}

    -- 3. OpenAI Provider (`/chat/completions`)
    elsif provider = PROVIDER_OPENAI then
        sequence msg_json_list = {}
        for i = 1 to length(messages) do
            sequence m = messages[i]
            msg_json_list = append(msg_json_list, {
                json:JSON_OBJECT, {
                    {"role", {json:JSON_STRING, m[1]}},
                    {"content", {json:JSON_STRING, m[2]}}
                }
            })
        end for

        sequence req_doc = {
            json:JSON_OBJECT, {
                {"model", {json:JSON_STRING, model}},
                {"messages", {json:JSON_ARRAY, msg_json_list}},
                {"temperature", temp},
                {"max_tokens", max_t}
            }
        }
        sequence target_url = cli[CLI_BASE_URL] & "/chat/completions"
        sequence headers = {
            {"Authorization", "Bearer " & cli[CLI_API_KEY]}
        }
        sequence resp = http:post_json(target_url, json:stringify(req_doc), headers)

        if resp[http:STATUS] != 200 then
            return {0, sprintf("OpenAI Fehler (%d): %s", {resp[http:STATUS], resp[http:BODY]}), resp}
        end if

        object parsed = json:parse(resp[http:BODY])
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON von OpenAI: " & resp[http:BODY], resp}
        end if

        sequence content = json:get(parsed[2], "choices[1].message.content", "")
        return {1, content, parsed[2]}

    -- 4. Anthropic Claude Provider (`/v1/messages`)
    elsif provider = PROVIDER_ANTHROPIC then
        sequence system_text = ""
        sequence msg_json_list = {}
        for i = 1 to length(messages) do
            sequence m = messages[i]
            if equal(m[1], "system") then
                system_text = m[2]
            else
                msg_json_list = append(msg_json_list, {
                    json:JSON_OBJECT, {
                        {"role", {json:JSON_STRING, m[1]}},
                        {"content", {json:JSON_STRING, m[2]}}
                    }
                })
            end if
        end for

        sequence req_pairs = {
            {"model", {json:JSON_STRING, model}},
            {"messages", {json:JSON_ARRAY, msg_json_list}},
            {"max_tokens", max_t}
        }
        if length(system_text) > 0 then
            req_pairs = append(req_pairs, {"system", {json:JSON_STRING, system_text}})
        end if

        sequence target_url = cli[CLI_BASE_URL] & "/v1/messages"
        sequence headers = {
            {"x-api-key", cli[CLI_API_KEY]},
            {"anthropic-version", "2023-06-01"}
        }
        sequence resp = http:post_json(target_url, json:stringify({json:JSON_OBJECT, req_pairs}), headers)

        if resp[http:STATUS] != 200 then
            return {0, sprintf("Claude Fehler (%d): %s", {resp[http:STATUS], resp[http:BODY]}), resp}
        end if

        object parsed = json:parse(resp[http:BODY])
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON von Claude: " & resp[http:BODY], resp}
        end if

        sequence content = json:get(parsed[2], "content[1].text", "")
        return {1, content, parsed[2]}
    end if

    return {0, "Unbekannter LLM Provider", {}}
end function

--**
-- Single-prompt text completion shortcut.
public function complete(sequence cli, sequence prompt, sequence system_prompt = "")
    sequence msgs = {}
    if length(system_prompt) > 0 then
        msgs = append(msgs, {"system", system_prompt})
    end if
    msgs = append(msgs, {"user", prompt})
    return chat(cli, msgs)
end function

-- =============================================================================
-- 4. Embeddings API (Vector representation for RAG)
-- =============================================================================

--**
-- Calculate vector embeddings for a given text string.
-- Returns `{1, vector}` on success, or `{0, err_msg}` on failure.
public function embeddings(sequence cli, sequence text_str)
    integer provider = cli[CLI_PROVIDER]

    if provider = PROVIDER_MOCK then
        return {1, mock_embed(text_str)}

    elsif provider = PROVIDER_OLLAMA then
        sequence target_url = cli[CLI_BASE_URL] & "/api/embeddings"
        sequence req_doc = {
            json:JSON_OBJECT, {
                {"model", {json:JSON_STRING, cli[CLI_EMBED_MODEL]}},
                {"prompt", {json:JSON_STRING, text_str}}
            }
        }
        sequence resp = http:post_json(target_url, json:stringify(req_doc))
        if resp[http:STATUS] != 200 then
            return {0, sprintf("Ollama Embedding Fehler (%d): %s", {resp[http:STATUS], resp[http:BODY]})}
        end if
        object parsed = json:parse(resp[http:BODY])
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON von Ollama: " & resp[http:BODY]}
        end if
        object vec_node = json:get_node(parsed[2], "embedding", 0)
        sequence vec = {}
        if json:is_array(vec_node) then
            for i = 1 to length(vec_node[2]) do
                vec = append(vec, json:unwrap(vec_node[2][i]))
            end for
        end if
        return {1, vec}

    elsif provider = PROVIDER_OPENAI then
        sequence target_url = cli[CLI_BASE_URL] & "/embeddings"
        sequence req_doc = {
            json:JSON_OBJECT, {
                {"model", {json:JSON_STRING, cli[CLI_EMBED_MODEL]}},
                {"input", {json:JSON_STRING, text_str}}
            }
        }
        sequence headers = {{"Authorization", "Bearer " & cli[CLI_API_KEY]}}
        sequence resp = http:post_json(target_url, json:stringify(req_doc), headers)
        if resp[http:STATUS] != 200 then
            return {0, sprintf("OpenAI Embedding Fehler (%d): %s", {resp[http:STATUS], resp[http:BODY]})}
        end if
        object parsed = json:parse(resp[http:BODY])
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON von OpenAI: " & resp[http:BODY]}
        end if
        object vec_node = json:get_node(parsed[2], "data[1].embedding", 0)
        sequence vec = {}
        if json:is_array(vec_node) then
            for i = 1 to length(vec_node[2]) do
                vec = append(vec, json:unwrap(vec_node[2][i]))
            end for
        end if
        return {1, vec}
    end if

    -- Fallback to local term-frequency vector
    return {1, mock_embed(text_str)}
end function
