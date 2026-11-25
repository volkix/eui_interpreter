--****
-- == Retrieval-Augmented Generation (RAG) Engine for Euphorix (std/rag.e)
--
-- Combines SQLite Full-Text Search (FTS5 / BM25) and Semantic Vector Embeddings (Cosine Similarity)
-- with Large Language Models (std/llm.e) to generate grounded, fact-based answers with source citations.
--
-- Features:
-- * **Smart Document Chunking**: Overlapping, paragraph- and sentence-aware chunking
-- * **Hybrid Retrieval**: State-of-the-art fusion of BM25 keyword matching (SQLite FTS5) + Vector similarity
-- * **Prompt Augmentation**: Automatic context injection with source attribution and citations
-- * **Offline & Online**: Runs 100% offline with zero dependencies or connects to Ollama, OpenAI, Claude
--

namespace rag

include std/llm.e as llm
include std/sqlite.e as sqlite
include std/json.e as json
include std/io.e as io
include std/convert.e as conv
include std/text.e as text
include std/search.e as search

-- =============================================================================
-- Knowledge Base Struct Indices
-- =============================================================================

public constant
    KB_NAME     = 1,
    KB_DB       = 2,
    KB_LLM      = 3,
    KB_STORAGE  = 4

function get_opt(sequence opts, sequence key, object default_val)
    for i = 1 to length(opts) do
        if sequence(opts[i]) and length(opts[i]) >= 2 and equal(opts[i][1], key) then
            return opts[i][2]
        end if
    end for
    return default_val
end function

-- =============================================================================
-- 1. Knowledge Base Creation & Lifecycle
-- =============================================================================

--**
-- Create a new RAG Knowledge Base.
--
-- Parameters:
-- * `name`: Identifier for the knowledge base
-- * `llm_client`: Optional LLM client handle from `llm:client()` (defaults to mock engine)
-- * `storage`: Storage path (":memory:" for in-memory or a file path like "my_kb.db")
public function create_kb(sequence name = "default", object llm_client = {}, sequence storage = ":memory:")
    if atom(llm_client) or length(llm_client) = 0 then
        llm_client = llm:client(llm:PROVIDER_MOCK)
    end if

    integer db = sqlite:open(storage)

    -- 1. Document metadata table
    sqlite:exec(db, "CREATE TABLE IF NOT EXISTS rag_docs (" &
                    "id TEXT PRIMARY KEY, " &
                    "title TEXT, " &
                    "chunk_count INTEGER, " &
                    "metadata TEXT);")

    -- 2. Chunks storage table
    sqlite:exec(db, "CREATE TABLE IF NOT EXISTS rag_chunks (" &
                    "chunk_id INTEGER PRIMARY KEY AUTOINCREMENT, " &
                    "doc_id TEXT, " &
                    "chunk_index INTEGER, " &
                    "title TEXT, " &
                    "content TEXT, " &
                    "embedding TEXT, " &
                    "metadata TEXT);")

    -- 3. SQLite FTS5 Full-Text Virtual Table for BM25 ranking
    sqlite:exec(db, "CREATE VIRTUAL TABLE IF NOT EXISTS rag_fts USING fts5(" &
                    "title, content, tokenize='unicode61');")

    return {
        name,           -- KB_NAME
        db,             -- KB_DB
        llm_client,     -- KB_LLM
        storage         -- KB_STORAGE
    }
end function

--**
-- Close the Knowledge Base database.
public procedure close_kb(sequence kb)
    if sequence(kb) and length(kb) >= KB_DB and integer(kb[KB_DB]) then
        sqlite:close(kb[KB_DB])
    end if
end procedure

-- =============================================================================
-- 2. Document Chunking & Ingestion
-- =============================================================================

--**
-- Chunk text into overlapping segments respecting word boundaries.
public function chunk_text(sequence text_str, integer max_chars = 500, integer overlap_chars = 60)
    sequence chunks = {}
    integer start_idx = 1
    integer n = length(text_str)

    if n <= max_chars then
        if n > 0 then
            return {text_str}
        end if
        return {}
    end if

    while start_idx <= n do
        integer end_idx = start_idx + max_chars - 1
        if end_idx >= n then
            sequence final_chunk = text_str[start_idx .. n]
            if length(final_chunk) > 0 then
                chunks = append(chunks, final_chunk)
            end if
            exit
        end if

        -- Break at nearest paragraph boundary, sentence end, or space
        integer split_pos = end_idx
        while split_pos > start_idx and text_str[split_pos] != ' ' and
              text_str[split_pos] != '\n' and text_str[split_pos] != '.' do
            split_pos -= 1
        end while

        if split_pos <= start_idx then
            split_pos = end_idx
        end if

        sequence chunk_piece = text_str[start_idx .. split_pos]
        if length(chunk_piece) > 0 then
            chunks = append(chunks, chunk_piece)
        end if

        start_idx = split_pos - overlap_chars + 1
        if start_idx <= split_pos - max_chars + 1 or start_idx <= 0 then
            start_idx = split_pos + 1
        end if
    end while

    return chunks
end function

--**
-- Ingest and index a document into the Knowledge Base.
--
-- Parameters:
-- * `kb`: Knowledge base handle
-- * `doc_id`: Unique document ID (e.g. `"DOC-101"` or `"manual_vsui"`)
-- * `title`: Document title
-- * `content`: Full text content
-- * `metadata`: Optional metadata list
-- * `max_chunk_chars`: Chunk size limit (default 450)
-- * `overlap_chars`: Overlap between consecutive chunks (default 50)
--
-- Returns the number of chunks indexed.
public function add_document(sequence kb, sequence doc_id, sequence title, sequence content,
                            sequence metadata = {}, integer max_chunk_chars = 450, integer overlap_chars = 50)
    integer db = kb[KB_DB]
    object llm_cli = kb[KB_LLM]

    sequence chunks = chunk_text(content, max_chunk_chars, overlap_chars)
    sequence meta_json = json:stringify(metadata)

    -- Upsert document record
    sqlite:exec(db, "INSERT OR REPLACE INTO rag_docs (id, title, chunk_count, metadata) VALUES (?, ?, ?, ?);",
                {doc_id, title, length(chunks), meta_json})

    -- Delete old chunks if document existed
    sqlite:exec(db, "DELETE FROM rag_chunks WHERE doc_id = ?;", {doc_id})

    for i = 1 to length(chunks) do
        sequence ch = chunks[i]

        -- 1. Compute vector embeddings
        sequence emb_json = "[]"
        sequence emb_res = llm:embeddings(llm_cli, ch)
        if emb_res[1] = 1 and sequence(emb_res[2]) and length(emb_res[2]) > 0 then
            emb_json = json:stringify(emb_res[2])
        end if

        -- 2. Store in chunks table
        sqlite:exec(db, "INSERT INTO rag_chunks (doc_id, chunk_index, title, content, embedding, metadata) VALUES (?, ?, ?, ?, ?, ?);",
                    {doc_id, i, title, ch, emb_json, meta_json})
        integer chunk_id = sqlite:last_insert_id(db)

        -- 3. Index in FTS5 full-text table
        sqlite:exec(db, "INSERT INTO rag_fts (rowid, title, content) VALUES (?, ?, ?);",
                    {chunk_id, title, ch})
    end for

    return length(chunks)
end function

-- =============================================================================
-- 3. Hybrid Retrieval Engine (BM25 + Cosine Similarity)
-- =============================================================================

sequence fts_stopwords = {
    "der", "die", "das", "und", "oder", "in", "von", "zu", "den", "dem", "des",
    "ein", "eine", "einer", "eines", "einem", "einen", "im", "am", "auf", "fuer",
    "für", "mit", "wie", "ist", "sind", "war", "kann", "können", "koennen", "wird",
    "werden", "hat", "haben", "the", "a", "an", "and", "or", "of", "to", "for",
    "is", "are", "as", "at", "by", "welche", "welcher", "welches", "was", "wer",
    "wo", "wann", "warum", "nicht", "über", "ueber", "zur", "zum", "aus", "euphorix"
}

function is_fts_stopword(sequence word)
    sequence lower_w = ""
    for i = 1 to length(word) do
        integer c = word[i]
        if c >= 'A' and c <= 'Z' then c += 32 end if
        lower_w &= c
    end for
    for i = 1 to length(fts_stopwords) do
        if equal(fts_stopwords[i], lower_w) then return 1 end if
    end for
    return 0
end function

function is_alnum_word(integer c)
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or
           (c >= '0' and c <= '9') or (c >= 128)
end function

function sanitize_fts_query(sequence query)
    sequence terms = {}
    sequence cur = ""
    for i = 1 to length(query) do
        integer c = query[i]
        if is_alnum_word(c) then
            cur &= c
        else
            if length(cur) >= 2 and not is_fts_stopword(cur) then
                terms = append(terms, cur & "*")
            end if
            cur = ""
        end if
    end for
    if length(cur) >= 2 and not is_fts_stopword(cur) then
        terms = append(terms, cur & "*")
    end if

    if length(terms) = 0 then
        return ""
    end if

    sequence match_expr = ""
    for i = 1 to length(terms) do
        if i > 1 then match_expr &= " OR " end if
        match_expr &= terms[i]
    end for
    return match_expr
end function

public function cosine_similarity(sequence a, sequence b)
    if length(a) != length(b) or length(a) = 0 then
        return 0.0
    end if
    atom dot = 0.0
    atom norm_a = 0.0
    atom norm_b = 0.0
    for i = 1 to length(a) do
        atom x = a[i]
        atom y = b[i]
        dot += x * y
        norm_a += x * x
        norm_b += y * y
    end for
    if norm_a <= 0.0 or norm_b <= 0.0 then
        return 0.0
    end if
    return dot / (sqrt(norm_a) * sqrt(norm_b))
end function

--**
-- Retrieve the most relevant chunks for a user query.
--
-- Parameters:
-- * `kb`: Knowledge base handle
-- * `query`: Search question or query text
-- * `top_k`: Maximum number of chunks to return (default 3)
-- * `mode`: Retrieval mode: `"hybrid"` (default), `"fts"` (BM25 only), or `"vector"` (semantic only)
--
-- Returns a list of sorted matches:
-- `{ {score, doc_id, chunk_index, title, content, metadata}, ... }`
public function retrieve(sequence kb, sequence query, integer top_k = 3, sequence mode = "hybrid")
    integer db = kb[KB_DB]
    object llm_cli = kb[KB_LLM]

    -- 1. Get query embeddings for vector search
    sequence query_vec = {}
    if not equal(mode, "fts") then
        sequence q_emb_res = llm:embeddings(llm_cli, query)
        if q_emb_res[1] = 1 then
            query_vec = q_emb_res[2]
        end if
    end if

    -- 2. Full-Text Search (BM25) via SQLite FTS5
    sequence fts_scores = {}
    sequence fts_expr = sanitize_fts_query(query)
    if length(fts_expr) > 0 and not equal(mode, "vector") then
        sequence fts_rows = sqlite:query(db,
            "SELECT rowid, rank FROM rag_fts WHERE rag_fts MATCH ? ORDER BY rank ASC LIMIT 25;",
            {fts_expr})
        for i = 1 to length(fts_rows) do
            integer chunk_id = fts_rows[i][1]
            -- Reciprocal Rank: position 1 = 1.0, position 2 = 0.5, etc.
            atom bm25_score = 1.0 / i
            fts_scores = append(fts_scores, {chunk_id, bm25_score})
        end for
    end if

    -- 3. Scan candidate chunks from database
    sequence chunks_rows = sqlite:query(db,
        "SELECT chunk_id, doc_id, chunk_index, title, content, embedding, metadata FROM rag_chunks;")

    if length(chunks_rows) = 0 then
        return {}
    end if

    sequence scored_matches = {}

    for i = 1 to length(chunks_rows) do
        sequence r = chunks_rows[i]
        integer chunk_id = r[1]
        sequence doc_id  = r[2]
        integer chunk_idx = r[3]
        sequence title   = r[4]
        sequence content = r[5]
        sequence emb_str = r[6]
        sequence meta_str = r[7]

        atom bm25_score = 0.0
        for f = 1 to length(fts_scores) do
            if fts_scores[f][1] = chunk_id then
                bm25_score = fts_scores[f][2]
                exit
            end if
        end for

        atom vec_score = 0.0
        if length(query_vec) > 0 and length(emb_str) > 2 then
            object parsed_emb = json:decode(emb_str)
            if sequence(parsed_emb) and length(parsed_emb) = length(query_vec) then
                vec_score = cosine_similarity(query_vec, parsed_emb)
                if vec_score < 0.0 then vec_score = 0.0 end if
            end if
        end if

        atom final_score = 0.0
        if equal(mode, "fts") then
            final_score = bm25_score
        elsif equal(mode, "vector") then
            final_score = vec_score
        else
            -- Hybrid: balanced combination of keyword BM25 + semantic vector similarity
            if length(fts_scores) > 0 then
                if bm25_score > 0.0 then
                    final_score = (0.60 * bm25_score) + (0.40 * vec_score)
                else
                    final_score = 0.20 * vec_score
                end if
            else
                final_score = vec_score
            end if
        end if

        if final_score > 0.001 or length(fts_scores) = 0 then
            scored_matches = append(scored_matches, {
                final_score,
                doc_id,
                chunk_idx,
                title,
                content,
                meta_str
            })
        end if
    end for

    -- 4. Sort descending by score
    for i = 1 to length(scored_matches) - 1 do
        integer best_idx = i
        for j = i + 1 to length(scored_matches) do
            if scored_matches[j][1] > scored_matches[best_idx][1] then
                best_idx = j
            end if
        end for
        if best_idx != i then
            sequence tmp = scored_matches[i]
            scored_matches[i] = scored_matches[best_idx]
            scored_matches[best_idx] = tmp
        end if
    end for

    -- 5. Limit to top_k
    if length(scored_matches) > top_k then
        scored_matches = scored_matches[1 .. top_k]
    end if

    return scored_matches
end function

-- =============================================================================
-- 4. Prompt Augmentation & End-to-End RAG
-- =============================================================================

--**
-- Construct the augmented RAG prompt combining retrieved knowledge with instructions.
public function build_augmented_prompt(sequence query, sequence retrieved_chunks, sequence system_instructions = "")
    sequence prompt = "=== RELEVANTER KONTEXT AUS DER WISSENSDATENBANK ===\n"

    if length(retrieved_chunks) = 0 then
        prompt &= "(Keine spezifischen Passagen in der Wissensdatenbank gefunden)\n"
    else
        for i = 1 to length(retrieved_chunks) do
            sequence ch = retrieved_chunks[i]
            sequence title = ch[4]
            integer c_idx  = ch[3]
            sequence text_c = ch[5]
            prompt &= sprintf("\n[Quelle %d: %s (Abschnitt #%d)]:\n%s\n",
                              {i, title, c_idx, text_c})
        end for
    end if

    prompt &= "====================================================\n\n"
    prompt &= "Frage des Benutzers: " & query & "\n\n"
    prompt &= "Anweisung für die Antwort:\n" &
              "1. Beantworte die Frage präzise, professionell und faktenbasiert.\n" &
              "2. Stütze deine Aussagen auf die bereitgestellten Kontext-Passagen.\n" &
              "3. Wenn die Information im Kontext nicht vorhanden ist, weise ehrlich darauf hin.\n"

    if length(system_instructions) > 0 then
        prompt &= "4. " & system_instructions & "\n"
    end if

    return prompt
end function

--**
-- Ask a question against the Knowledge Base using Retrieval-Augmented Generation.
--
-- Parameters:
-- * `kb`: Knowledge base handle
-- * `query`: User question
-- * `options`: Optional parameters:
--     - `{"top_k", 3}`
--     - `{"mode", "hybrid"}`
--     - `{"instructions", "..."}`
--
-- Returns structured RAG result sequence:
-- `{ {"answer", answer_text}, {"sources", sources_list}, {"chunks", retrieved}, {"query", query} }`
public function ask(sequence kb, sequence query, sequence options = {})
    integer top_k = get_opt(options, "top_k", 3)
    sequence mode = get_opt(options, "mode", "hybrid")
    sequence instructions = get_opt(options, "instructions", "")

    -- 1. Retrieval
    sequence chunks = retrieve(kb, query, top_k, mode)

    -- 2. Context Augmentation
    sequence augmented_prompt = build_augmented_prompt(query, chunks, instructions)

    -- 3. LLM Generation
    sequence sys_msg = "Du bist ein intelligenter, präziser Wissensassistent mit Retrieval-Augmented Generation (RAG)."
    sequence messages = {
        {"system", sys_msg},
        {"user", augmented_prompt}
    }
    sequence chat_res = llm:chat(kb[KB_LLM], messages)
    sequence answer_text = ""
    if chat_res[1] = 1 then
        answer_text = chat_res[2]
    else
        answer_text = "Fehler bei der Antwortgenerierung: " & chat_res[2]
    end if

    -- 4. Collect source attributions
    sequence sources_list = {}
    for i = 1 to length(chunks) do
        sources_list = append(sources_list, {
            chunks[i][4],       -- title
            chunks[i][2],       -- doc_id
            chunks[i][3],       -- chunk_index
            chunks[i][1]        -- relevance score
        })
    end for

    return {
        {"answer", answer_text},
        {"sources", sources_list},
        {"chunks", chunks},
        {"query", query},
        {"prompt", augmented_prompt}
    }
end function

--**
-- Extract the generated answer text from a RAG result.
public function answer(sequence rag_result)
    for i = 1 to length(rag_result) do
        if sequence(rag_result[i]) and length(rag_result[i]) >= 2 and equal(rag_result[i][1], "answer") then
            return rag_result[i][2]
        end if
    end for
    return ""
end function

--**
-- Extract the list of sources from a RAG result.
public function sources(sequence rag_result)
    for i = 1 to length(rag_result) do
        if sequence(rag_result[i]) and length(rag_result[i]) >= 2 and equal(rag_result[i][1], "sources") then
            return rag_result[i][2]
        end if
    end for
    return {}
end function

--**
-- Format sources into a readable markdown/text citation list.
public function format_sources(sequence rag_result)
    sequence src = sources(rag_result)
    if length(src) = 0 then
        return "(Keine Quellen zitiert)"
    end if
    sequence out = ""
    for i = 1 to length(src) do
        sequence s = src[i]
        out &= sprintf("  [%d] %s (Abschnitt #%d, Relevanz: %.1f%%)\n",
                       {i, s[1], s[3], s[4] * 100.0})
    end for
    return out
end function
