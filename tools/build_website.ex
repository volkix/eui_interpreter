--****
-- == Website Generator for Euphorix (tools/build_website.ex)
--
-- Generates a complete, responsive, production-ready static website
-- into `website/` ready to be served by lighttpd or copied to a remote server.
--
-- Configuration (including Impressum, Contact, Downloads, GitHub URL)
-- is read dynamically from `website_config.json`.
--
-- Run with: ./euphorix tools/build_website.ex
--

include std/io.e
include std/filesys.e
include std/json.e
include std/text.e

constant CONFIG_FILE = "website_config.json"
constant OUT_DIR     = "website"

procedure main()
    puts(1, "=====================================================================\n")
    puts(1, "  Euphorix Website Generator (lighttpd Ready)\n")
    puts(1, "=====================================================================\n\n")

    -- 1. Load website_config.json
    if not filesys:file_exists(CONFIG_FILE) then
        printf(2, "Fehler: Konfigurationsdatei '%s' wurde nicht gefunden!\n", {CONFIG_FILE})
        abort(1)
    end if

    sequence cfg_raw = io:read_file(CONFIG_FILE)
    object doc = json:decode(cfg_raw)
    if not json:is_object(doc) then
        printf(2, "Fehler: '%s' konnte nicht als JSON geparst werden!\n", {CONFIG_FILE})
        abort(1)
    end if

    -- Extract Config Variables
    sequence proj_name     = json:get(doc, "project.name", "Euphorix")
    sequence proj_ver      = json:get(doc, "project.version", "1.0.0")
    sequence proj_tagline  = json:get(doc, "project.tagline", "Next-Gen Virtual Machine für OpenEuphoria Syntax")
    sequence proj_headline = json:get(doc, "project.headline", "OpenEuphoria Syntax. Modernste Java 25 Power.")
    sequence proj_subhead  = json:get(doc, "project.subheadline", "")
    sequence github_url    = json:get(doc, "project.github_url", "https://github.com/volkix/eui_interpreter")
    sequence openeu_url    = json:get(doc, "project.openeuphoria_url", "https://openeuphoria.org")
    sequence license       = json:get(doc, "project.license", "GPLv3")

    -- Downloads
    sequence dl_std_fn     = json:get(doc, "downloads.standalone.filename", "euphorix-standalone")
    sequence dl_std_src    = json:get(doc, "downloads.standalone.source_path", "euphorix-standalone")
    sequence dl_std_title  = json:get(doc, "downloads.standalone.title", "Euphorix Standalone")
    sequence dl_std_badge  = json:get(doc, "downloads.standalone.badge", "Empfohlen")
    sequence dl_std_size   = json:get(doc, "downloads.standalone.size", "53 MB")
    sequence dl_std_desc   = json:get(doc, "downloads.standalone.description", "")
    sequence dl_std_cmd    = json:get(doc, "downloads.standalone.cmd_install", "./euphorix-standalone")

    sequence dl_jar_fn     = json:get(doc, "downloads.jar.filename", "euphorix.jar")
    sequence dl_jar_src    = json:get(doc, "downloads.jar.source_path", "euphorix.jar")
    sequence dl_jar_title  = json:get(doc, "downloads.jar.title", "Euphorix JAR")
    sequence dl_jar_badge  = json:get(doc, "downloads.jar.badge", "Plattformunabhängig")
    sequence dl_jar_size   = json:get(doc, "downloads.jar.size", "19 MB")
    sequence dl_jar_desc   = json:get(doc, "downloads.jar.description", "")
    sequence dl_jar_cmd    = json:get(doc, "downloads.jar.cmd_install", "java -jar euphorix.jar")

    sequence dl_hpdf_fn    = json:get(doc, "downloads.handbuch_pdf.filename", "HANDBUCH.pdf")
    sequence dl_hpdf_size  = json:get(doc, "downloads.handbuch_pdf.size", "2.4 MB")

    sequence dl_mpdf_fn    = json:get(doc, "downloads.manual_pdf.filename", "MANUAL.pdf")
    sequence dl_mpdf_size  = json:get(doc, "downloads.manual_pdf.size", "2.5 MB")

    sequence dl_hde_fn     = json:get(doc, "downloads.handbuch_de.filename", "HANDBUCH.md")
    sequence dl_hde_src    = json:get(doc, "downloads.handbuch_de.source_path", "HANDBUCH.md")
    sequence dl_hde_title  = json:get(doc, "downloads.handbuch_de.title", "Deutsches Handbuch")
    sequence dl_hde_badge  = json:get(doc, "downloads.handbuch_de.badge", "Deutsch")
    sequence dl_hde_size   = json:get(doc, "downloads.handbuch_de.size", "199 KB")
    sequence dl_hde_desc   = json:get(doc, "downloads.handbuch_de.description", "")

    sequence dl_men_fn     = json:get(doc, "downloads.manual_en.filename", "MANUAL.md")
    sequence dl_men_src    = json:get(doc, "downloads.manual_en.source_path", "MANUAL.md")
    sequence dl_men_title  = json:get(doc, "downloads.manual_en.title", "English Manual")
    sequence dl_men_badge  = json:get(doc, "downloads.manual_en.badge", "English")
    sequence dl_men_size   = json:get(doc, "downloads.manual_en.size", "188 KB")
    sequence dl_men_desc   = json:get(doc, "downloads.manual_en.description", "")

    -- Impressum & Datenschutz
    sequence imp_owner     = json:get(doc, "impressum.owner", "Volker Schulte")
    sequence imp_comp      = json:get(doc, "impressum.company", "")
    sequence imp_street    = json:get(doc, "impressum.street", "")
    sequence imp_city      = json:get(doc, "impressum.city", "")
    sequence imp_country   = json:get(doc, "impressum.country", "Deutschland")
    sequence imp_email     = json:get(doc, "impressum.email", "")
    sequence imp_phone     = json:get(doc, "impressum.phone", "")
    sequence imp_taxid     = json:get(doc, "impressum.tax_id", "")
    sequence imp_resp      = json:get(doc, "impressum.responsible_person", "")
    sequence imp_discl     = json:get(doc, "impressum.disclaimer", "")
    sequence imp_priv      = json:get(doc, "impressum.privacy", "")

    printf(1, "1. Konfiguration geladen: '%s' (v%s, %s)\n", {proj_name, proj_ver, github_url})

    -- 2. Create Target Directories
    filesys:create_directory(OUT_DIR)
    filesys:create_directory(OUT_DIR & "/css")
    filesys:create_directory(OUT_DIR & "/js")
    filesys:create_directory(OUT_DIR & "/downloads")
    puts(1, "2. Zielverzeichnisse in 'website/' erstellt.\n")

    -- 3. Generate PDFs & Copy download assets
    puts(1, "3. Erzeuge formatierte PDF-Handbücher...\n")
    system_exec("python3 tools/generate_pdf.py", 2)
    puts(1, "   Kopiere Download-Artefakte nach 'website/downloads/'...\n")
    if filesys:file_exists(dl_std_src) then
        filesys:copy_file(dl_std_src, OUT_DIR & "/downloads/" & dl_std_fn, 1)
        printf(1, "   - %s (%s)\n", {dl_std_fn, dl_std_size})
    else
        printf(2, "   [Warnung] Quelldatei '%s' nicht gefunden!\n", {dl_std_src})
    end if

    if filesys:file_exists(dl_jar_src) then
        filesys:copy_file(dl_jar_src, OUT_DIR & "/downloads/" & dl_jar_fn, 1)
        printf(1, "   - %s (%s)\n", {dl_jar_fn, dl_jar_size})
    end if

    if filesys:file_exists(dl_hde_src) then
        filesys:copy_file(dl_hde_src, OUT_DIR & "/downloads/" & dl_hde_fn, 1)
        printf(1, "   - %s (%s)\n", {dl_hde_fn, dl_hde_size})
    end if

    if filesys:file_exists(dl_men_src) then
        filesys:copy_file(dl_men_src, OUT_DIR & "/downloads/" & dl_men_fn, 1)
        printf(1, "   - %s (%s)\n", {dl_men_fn, dl_men_size})
    end if

    if filesys:file_exists("website/downloads/" & dl_hpdf_fn) then
        printf(1, "   - %s (%s)\n", {dl_hpdf_fn, dl_hpdf_size})
    end if
    if filesys:file_exists("website/downloads/" & dl_mpdf_fn) then
        printf(1, "   - %s (%s)\n", {dl_mpdf_fn, dl_mpdf_size})
    end if

    -- 4. Generate CSS (website/css/style.css)
    puts(1, "4. Erzeuge Stylesheet 'website/css/style.css'...\n")
    sequence css_code = `/* =============================================================================
 * Euphorix Modern Enterprise Theme (style.css)
 * High-Density / Modern Responsive Layout for lighttpd
 * ============================================================================= */

:root {
  --primary: #41518b;
  --primary-hover: #324070;
  --primary-light: #eff3fa;
  --accent: #549e53;
  --accent-hover: #438242;
  --dark: #0f172a;
  --dark-surface: #1e293b;
  --dark-border: #334155;
  --text-main: #1e293b;
  --text-muted: #64748b;
  --bg-page: #f8fafc;
  --bg-card: #ffffff;
  --border-light: #e2e8f0;
  --shadow-sm: 0 1px 3px rgba(0,0,0,0.06);
  --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.08), 0 2px 4px -2px rgba(0,0,0,0.04);
  --shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px -4px rgba(0,0,0,0.05);
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 16px;
  --font-sans: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', Menlo, Monaco, Consolas, 'Courier New', monospace;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; font-size: 16px; }
body {
  font-family: var(--font-sans);
  background: var(--bg-page);
  color: var(--text-main);
  line-height: 1.6;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* --- Navigation Bar --- */
.navbar {
  position: sticky;
  top: 0;
  z-index: 1000;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border-bottom: 1px solid var(--border-light);
}
.nav-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 20px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  color: var(--primary);
  font-weight: 800;
  font-size: 1.3rem;
  letter-spacing: -0.5px;
}
.brand-badge {
  background: var(--primary-light);
  color: var(--primary);
  font-size: 0.75rem;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 12px;
  border: 1px solid rgba(65, 81, 139, 0.2);
}
.nav-links {
  display: flex;
  align-items: center;
  gap: 24px;
  list-style: none;
}
.nav-links a {
  text-decoration: none;
  color: var(--text-main);
  font-size: 0.95rem;
  font-weight: 500;
  transition: color 0.15s;
}
.nav-links a:hover {
  color: var(--primary);
}
.nav-btn {
  background: var(--primary);
  color: white !important;
  padding: 8px 18px;
  border-radius: var(--radius-sm);
  font-weight: 600 !important;
  transition: background 0.15s, transform 0.1s;
}
.nav-btn:hover {
  background: var(--primary-hover);
  transform: translateY(-1px);
}
.mobile-toggle {
  display: none;
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--text-main);
}

/* --- Hero Section --- */
.hero {
  background: linear-gradient(135deg, #f0f4ff 0%, #ffffff 50%, #f4fbf5 100%);
  padding: 80px 20px 60px;
  border-bottom: 1px solid var(--border-light);
  text-align: center;
}
.hero-container {
  max-width: 960px;
  margin: 0 auto;
}
.hero-badges {
  display: inline-flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 10px;
  margin-bottom: 24px;
}
.pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 600;
  background: white;
  border: 1px solid var(--border-light);
  box-shadow: var(--shadow-sm);
}
.pill-accent { color: var(--accent); border-color: rgba(84, 158, 83, 0.3); }
.pill-primary { color: var(--primary); border-color: rgba(65, 81, 139, 0.3); }
.hero h1 {
  font-size: 3rem;
  font-weight: 850;
  line-height: 1.15;
  letter-spacing: -1px;
  color: var(--dark);
  margin-bottom: 20px;
}
.hero h1 span.highlight {
  color: var(--primary);
  background: linear-gradient(120deg, #41518b, #2b3864);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.hero p.lead {
  font-size: 1.2rem;
  color: var(--text-muted);
  max-width: 760px;
  margin: 0 auto 36px;
}
.hero-cta {
  display: flex;
  justify-content: center;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 48px;
}
.btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 24px;
  border-radius: var(--radius-sm);
  font-size: 1rem;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.15s;
  cursor: pointer;
  border: none;
}
.btn-primary {
  background: var(--primary);
  color: white;
  box-shadow: 0 4px 12px rgba(65, 81, 139, 0.25);
}
.btn-primary:hover {
  background: var(--primary-hover);
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(65, 81, 139, 0.35);
}
.btn-secondary {
  background: white;
  color: var(--text-main);
  border: 1px solid var(--border-light);
  box-shadow: var(--shadow-sm);
}
.btn-secondary:hover {
  background: #f1f5f9;
  border-color: #cbd5e1;
}

/* --- Terminal / Code Showcase --- */
.showcase-wrapper {
  max-width: 900px;
  margin: 0 auto;
  background: var(--dark);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-lg);
  overflow: hidden;
  text-align: left;
  border: 1px solid var(--dark-border);
}
.terminal-header {
  background: var(--dark-surface);
  padding: 12px 18px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--dark-border);
}
.terminal-dots {
  display: flex;
  gap: 6px;
}
.dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}
.dot-red { background: #ef4444; }
.dot-yellow { background: #eab308; }
.dot-green { background: #22c55e; }
.terminal-tabs {
  display: flex;
  gap: 4px;
}
.terminal-tab {
  background: transparent;
  color: #94a3b8;
  border: none;
  padding: 6px 14px;
  font-size: 0.82rem;
  font-family: var(--font-mono);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all 0.15s;
}
.terminal-tab.active {
  background: var(--dark);
  color: #38bdf8;
  font-weight: 600;
}
.terminal-body {
  padding: 20px;
  overflow-x: auto;
  font-family: var(--font-mono);
  font-size: 0.9rem;
  color: #e2e8f0;
  line-height: 1.6;
}
.terminal-body pre {
  margin: 0;
}
.code-tab-content { display: none; }
.code-tab-content.active { display: block; }
.token-kw { color: #f472b6; font-weight: bold; }
.token-fn { color: #38bdf8; }
.token-str { color: #4ade80; }
.token-num { color: #fb923c; }
.token-cmt { color: #64748b; font-style: italic; }

/* --- Section Layouts --- */
.section {
  padding: 80px 20px;
}
.section-alt {
  background: #ffffff;
  border-top: 1px solid var(--border-light);
  border-bottom: 1px solid var(--border-light);
}
.container {
  max-width: 1200px;
  margin: 0 auto;
}
.section-header {
  text-align: center;
  max-width: 720px;
  margin: 0 auto 56px;
}
.section-header h2 {
  font-size: 2.2rem;
  font-weight: 800;
  letter-spacing: -0.5px;
  margin-bottom: 14px;
}
.section-header p {
  color: var(--text-muted);
  font-size: 1.1rem;
}

/* --- Feature Grid --- */
.feature-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(340px, 1fr));
  gap: 28px;
}
.feature-card {
  background: var(--bg-card);
  padding: 30px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-light);
  box-shadow: var(--shadow-sm);
  transition: transform 0.2s, box-shadow 0.2s;
}
.feature-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-md);
}
.feature-icon {
  width: 50px;
  height: 50px;
  border-radius: var(--radius-sm);
  background: var(--primary-light);
  color: var(--primary);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 20px;
}
.feature-card h3 {
  font-size: 1.25rem;
  font-weight: 700;
  margin-bottom: 10px;
}
.feature-card p {
  color: var(--text-muted);
  font-size: 0.95rem;
}

/* --- Download Center --- */
.download-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 24px;
}
.download-card {
  background: white;
  border-radius: var(--radius-md);
  border: 2px solid var(--border-light);
  padding: 28px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  box-shadow: var(--shadow-sm);
  transition: border-color 0.2s, box-shadow 0.2s;
  position: relative;
}
.download-card.featured {
  border-color: var(--primary);
  box-shadow: 0 8px 24px rgba(65, 81, 139, 0.12);
}
.download-card-badge {
  position: absolute;
  top: -12px;
  right: 20px;
  background: var(--primary);
  color: white;
  font-size: 0.75rem;
  font-weight: 700;
  padding: 3px 12px;
  border-radius: 12px;
}
.download-card-badge.badge-accent {
  background: var(--accent);
}
.download-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--text-muted);
  font-size: 0.85rem;
  font-weight: 600;
  margin-top: 8px;
  margin-bottom: 14px;
}
.download-card h3 {
  font-size: 1.3rem;
  font-weight: 700;
  margin-bottom: 6px;
}
.download-card p {
  color: var(--text-muted);
  font-size: 0.92rem;
  flex-grow: 1;
  margin-bottom: 24px;
}
.download-card .btn {
  width: 100%;
  justify-content: center;
  text-align: center;
}
.download-cmd {
  margin-top: 12px;
  background: #f1f5f9;
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  padding: 8px 12px;
  font-family: var(--font-mono);
  font-size: 0.78rem;
  color: #475569;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* --- GitHub Banner --- */
.github-banner {
  background: linear-gradient(135deg, var(--dark) 0%, var(--dark-surface) 100%);
  color: white;
  border-radius: var(--radius-lg);
  padding: 50px 40px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 30px;
  flex-wrap: wrap;
  box-shadow: var(--shadow-lg);
}
.github-banner h3 {
  font-size: 1.8rem;
  font-weight: 800;
  margin-bottom: 10px;
}
.github-banner p {
  color: #94a3b8;
  max-width: 600px;
}
.github-clone-box {
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--dark-border);
  padding: 10px 16px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  gap: 12px;
  font-family: var(--font-mono);
  font-size: 0.85rem;
}
.btn-copy {
  background: none;
  border: none;
  color: #38bdf8;
  cursor: pointer;
  font-size: 0.85rem;
  font-weight: 600;
  padding: 2px 6px;
}

/* --- Impressum Page Layout --- */
.legal-page {
  max-width: 840px;
  margin: 40px auto 80px;
  padding: 0 20px;
}
.legal-card {
  background: white;
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: 40px;
  box-shadow: var(--shadow-sm);
}
.legal-card h1 {
  font-size: 2.2rem;
  font-weight: 850;
  margin-bottom: 24px;
  color: var(--dark);
}
.legal-card h2 {
  font-size: 1.4rem;
  font-weight: 700;
  margin: 32px 0 12px;
  color: var(--primary);
  border-bottom: 1px solid var(--border-light);
  padding-bottom: 8px;
}
.legal-card p, .legal-card ul {
  color: #475569;
  font-size: 0.98rem;
  margin-bottom: 16px;
}
.legal-card ul { padding-left: 20px; }
.legal-contact-box {
  background: var(--bg-page);
  border: 1px solid var(--border-light);
  border-left: 4px solid var(--primary);
  padding: 18px 24px;
  border-radius: var(--radius-sm);
  margin: 20px 0;
  font-size: 1rem;
}

/* --- Footer --- */
footer {
  margin-top: auto;
  background: white;
  border-top: 1px solid var(--border-light);
  padding: 40px 20px 30px;
}
.footer-container {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 20px;
}
.footer-links {
  display: flex;
  gap: 20px;
  list-style: none;
}
.footer-links a {
  text-decoration: none;
  color: var(--text-muted);
  font-size: 0.9rem;
  transition: color 0.15s;
}
.footer-links a:hover {
  color: var(--primary);
}

/* --- Mobile Responsiveness (<= 768px) --- */
@media (max-width: 768px) {
  .hero h1 { font-size: 2.2rem; }
  .hero p.lead { font-size: 1.05rem; }
  .mobile-toggle { display: block; }
  .nav-links {
    display: none;
    position: absolute;
    top: 64px;
    left: 0;
    right: 0;
    background: white;
    flex-direction: column;
    padding: 20px;
    border-bottom: 1px solid var(--border-light);
    box-shadow: var(--shadow-md);
    gap: 16px;
  }
  .nav-links.show { display: flex; }
  .nav-btn { width: 100%; text-align: center; }
  .feature-grid { grid-template-columns: 1fr; }
  .download-grid { grid-template-columns: 1fr; }
  .github-banner { padding: 30px 20px; flex-direction: column; align-items: flex-start; }
  .github-clone-box { width: 100%; justify-content: space-between; }
  .legal-card { padding: 24px; }
  .footer-container { flex-direction: column; text-align: center; }
}

/* --- Tutorial & Library Reference Styles --- */
.tutorial-hero {
  padding: 130px 20px 40px;
  background: radial-gradient(circle at top right, rgba(65, 81, 139, 0.08), transparent 50%),
              radial-gradient(circle at bottom left, rgba(84, 158, 83, 0.06), transparent 50%),
              var(--light);
  border-bottom: 1px solid var(--border-light);
  text-align: center;
}
.tutorial-search-wrapper {
  max-width: 680px;
  margin: 28px auto 16px;
}
.search-box-inner {
  display: flex;
  align-items: center;
  background: white;
  border: 1.5px solid var(--border-light);
  border-radius: 30px;
  padding: 8px 18px;
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.06);
}
.search-box-inner:focus-within {
  border-color: var(--primary);
  box-shadow: 0 6px 20px rgba(65, 81, 139, 0.15);
}
.search-box-inner svg {
  color: #94a3b8;
  margin-right: 10px;
  flex-shrink: 0;
}
.search-box-inner input {
  flex: 1;
  border: none;
  outline: none;
  font-size: 1rem;
  color: var(--dark);
  background: transparent;
}
#clear-search {
  background: none;
  border: none;
  color: #94a3b8;
  font-size: 1.1rem;
  cursor: pointer;
  padding: 0 4px;
}
.filter-pills-bar {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 8px;
  max-width: 1000px;
  margin: 0 auto 20px;
}
.filter-pill {
  background: white;
  border: 1px solid var(--border-light);
  border-radius: 20px;
  padding: 6px 14px;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.15s;
}
.filter-pill:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.filter-pill.active {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
  box-shadow: 0 2px 8px rgba(65, 81, 139, 0.25);
}
.runner-banner {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  background: #f8fafc;
  border: 1px dashed #cbd5e1;
  border-radius: 8px;
  padding: 10px 18px;
  font-size: 0.9rem;
  color: #475569;
  margin-top: 10px;
}
.runner-banner code {
  background: #1e293b;
  color: #38bdf8;
  padding: 4px 10px;
  border-radius: 4px;
  font-family: var(--font-mono);
  font-size: 0.85rem;
}
.btn-copy-small {
  background: #e2e8f0;
  border: none;
  border-radius: 4px;
  padding: 4px 10px;
  font-size: 0.8rem;
  cursor: pointer;
  font-weight: 600;
}
.btn-copy-small:hover { background: #cbd5e1; }

.tutorial-main {
  padding: 40px 20px 80px;
}
.tutorial-layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 36px;
  align-items: start;
}
.tutorial-sidebar {
  position: sticky;
  top: 90px;
  max-height: calc(100vh - 110px);
  overflow-y: auto;
  background: white;
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: 20px;
  box-shadow: var(--shadow-sm);
}
.sidebar-title {
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 700;
  color: var(--text-muted);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border-light);
}
.sidebar-chap-group {
  margin-bottom: 16px;
}
.sidebar-chap-link {
  display: block;
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--dark);
  text-decoration: none;
  margin-bottom: 6px;
  transition: color 0.15s;
}
.sidebar-chap-link:hover { color: var(--primary); }
.sidebar-sublist {
  list-style: none;
  padding-left: 12px;
  border-left: 2px solid var(--border-light);
}
.sidebar-sublist li { margin-bottom: 4px; }
.sidebar-mod-link {
  font-size: 0.82rem;
  color: var(--text-muted);
  text-decoration: none;
  transition: color 0.15s;
}
.sidebar-mod-link:hover { color: var(--primary); }

.tutorial-chapter-section {
  margin-bottom: 48px;
  padding-top: 10px;
}
.chapter-badge {
  display: inline-block;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--primary);
  background: var(--primary-light);
  padding: 2px 8px;
  border-radius: 4px;
  margin-bottom: 8px;
}
.tutorial-chapter-section h2 {
  font-size: 1.8rem;
  color: var(--dark);
  margin-bottom: 10px;
}
.chapter-desc {
  font-size: 1.05rem;
  color: var(--text-muted);
  margin-bottom: 12px;
  line-height: 1.5;
}
.chapter-file-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 0.85rem;
  color: #64748b;
  background: #f1f5f9;
  padding: 4px 10px;
  border-radius: 4px;
  margin-bottom: 24px;
}
.chapter-file-badge code {
  color: var(--primary);
  font-weight: 600;
}

.tutorial-card {
  background: white;
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: 24px;
  margin-bottom: 24px;
  box-shadow: var(--shadow-sm);
  transition: box-shadow 0.2s;
}
.tutorial-card:hover {
  box-shadow: var(--shadow-md);
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 12px;
}
.mod-pill {
  font-family: var(--font-mono);
  font-weight: 700;
  font-size: 1.05rem;
  color: var(--primary);
  background: var(--primary-light);
  padding: 4px 10px;
  border-radius: 6px;
}
.ns-pill {
  font-size: 0.8rem;
  color: #64748b;
  background: #f1f5f9;
  padding: 4px 8px;
  border-radius: 4px;
  margin-left: 6px;
}
.btn-copy-code {
  background: var(--light);
  border: 1px solid var(--border-light);
  border-radius: 4px;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-muted);
  padding: 5px 12px;
  cursor: pointer;
  transition: all 0.15s;
}
.btn-copy-code:hover {
  background: var(--primary-light);
  color: var(--primary);
  border-color: var(--primary);
}
.mod-explanation {
  font-size: 0.95rem;
  color: var(--dark);
  line-height: 1.55;
  margin-bottom: 16px;
}
.code-box {
  background: #0f172a;
  border-radius: 6px;
  overflow: hidden;
  margin-bottom: 14px;
}
.code-box-header {
  background: #1e293b;
  padding: 6px 14px;
  font-size: 0.75rem;
  color: #94a3b8;
  font-weight: 600;
  letter-spacing: 0.5px;
  border-bottom: 1px solid #334155;
}
.code-box pre {
  margin: 0;
  padding: 14px 18px;
  color: #f8fafc;
  font-family: var(--font-mono);
  font-size: 0.88rem;
  line-height: 1.5;
  overflow-x: auto;
}
.output-box {
  background: #090d16;
  border-radius: 6px;
  border: 1px solid #1e293b;
  overflow: hidden;
}
.output-box-header {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #131b2e;
  padding: 6px 14px;
  border-bottom: 1px solid #1e293b;
}
.output-title {
  font-size: 0.75rem;
  color: #94a3b8;
  font-weight: 600;
  margin-left: 6px;
}
.terminal-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
}
.terminal-dot.red { background: #ef4444; }
.terminal-dot.yellow { background: #f59e0b; }
.terminal-dot.green { background: #10b981; }
.output-pre {
  margin: 0;
  padding: 12px 18px;
  font-family: var(--font-mono);
  font-size: 0.85rem;
  color: #38bdf8;
  line-height: 1.45;
  overflow-x: auto;
}

@media (max-width: 992px) {
  .tutorial-layout {
    grid-template-columns: 1fr;
  }
  .tutorial-sidebar {
    position: static;
    max-height: 320px;
    margin-bottom: 24px;
  }
}
`
    io:write_file(OUT_DIR & "/css/style.css", css_code)

    -- 5. Generate JS (website/js/main.js)
    puts(1, "5. Erzeuge JavaScript 'website/js/main.js'...\n")
    sequence js_code = `/* Euphorix Website Interactivity */
document.addEventListener('DOMContentLoaded', function() {
  // 1. Mobile Menu Toggle
  var toggle = document.querySelector('.mobile-toggle');
  var links = document.querySelector('.nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', function() {
      links.classList.toggle('show');
    });
    // Close menu when clicking link
    links.querySelectorAll('a').forEach(function(a) {
      a.addEventListener('click', function() {
        links.classList.remove('show');
      });
    });
  }

  // 2. Terminal Code Tabs
  var tabs = document.querySelectorAll('.terminal-tab');
  tabs.forEach(function(tab) {
    tab.addEventListener('click', function() {
      var targetId = this.getAttribute('data-target');
      tabs.forEach(function(t) { t.classList.remove('active'); });
      document.querySelectorAll('.code-tab-content').forEach(function(c) {
        c.classList.remove('active');
      });
      this.classList.add('active');
      var target = document.getElementById(targetId);
      if (target) target.classList.add('active');
    });
  });

  // 3. Tutorial Live Search & Category Filter
  var searchInput = document.getElementById('tutorial-search');
  var clearBtn = document.getElementById('clear-search');
  var filterPills = document.querySelectorAll('.filter-pill');
  var chapterSections = document.querySelectorAll('.tutorial-chapter-section');
  var sidebarGroups = document.querySelectorAll('.sidebar-chap-group');

  function applyTutorialFilter() {
    var query = searchInput ? searchInput.value.toLowerCase().trim() : '';
    var activePill = document.querySelector('.filter-pill.active');
    var activeCat = activePill ? activePill.getAttribute('data-filter') : 'all';

    if (clearBtn) clearBtn.style.display = query.length > 0 ? 'inline-block' : 'none';

    chapterSections.forEach(function(sec) {
      var secCat = sec.getAttribute('data-cat');
      var catMatches = (activeCat === 'all' || activeCat === secCat);
      var visibleCardsCount = 0;

      var secCards = sec.querySelectorAll('.tutorial-card');
      secCards.forEach(function(card) {
        var cardText = card.textContent.toLowerCase();
        var cardKeywords = (card.getAttribute('data-keywords') || '').toLowerCase();
        var searchMatches = (query === '' || cardText.indexOf(query) !== -1 || cardKeywords.indexOf(query) !== -1);

        if (catMatches && searchMatches) {
          card.style.display = 'block';
          visibleCardsCount++;
        } else {
          card.style.display = 'none';
        }
      });

      if (visibleCardsCount > 0) {
        sec.style.display = 'block';
      } else {
        sec.style.display = 'none';
      }
    });

    sidebarGroups.forEach(function(grp) {
      var grpCat = grp.getAttribute('data-cat');
      if (activeCat === 'all' || activeCat === grpCat) {
        grp.style.display = 'block';
      } else {
        grp.style.display = 'none';
      }
    });
  }

  if (searchInput) {
    searchInput.addEventListener('input', applyTutorialFilter);
  }
  if (clearBtn) {
    clearBtn.addEventListener('click', function() {
      searchInput.value = '';
      applyTutorialFilter();
      searchInput.focus();
    });
  }

  filterPills.forEach(function(pill) {
    pill.addEventListener('click', function() {
      filterPills.forEach(function(p) { p.classList.remove('active'); });
      this.classList.add('active');
      applyTutorialFilter();
    });
  });
});

// Copy snippet to clipboard
function copyCommand(text, btnElement) {
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(function() {
      var oldText = btnElement.textContent;
      btnElement.textContent = "Kopiert!";
      setTimeout(function() { btnElement.textContent = oldText; }, 2000);
    });
  }
}

function copySnippet(btn) {
  var card = btn.closest('.tutorial-card');
  if (card) {
    var codeEl = card.querySelector('code');
    if (codeEl) {
      copyCommand(codeEl.textContent, btn);
    }
  }
}
`
    io:write_file(OUT_DIR & "/js/main.js", js_code)

    -- 6. Generate index.html
    puts(1, "6. Erzeuge Hauptseite 'website/index.html'...\n")
    sequence index_html = sprintf(`<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>%s – %s</title>
  <meta name="description" content="%s">
  <link rel="stylesheet" href="css/style.css">
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
</head>
<body>

  <!-- Navigation Bar -->
  <nav class="navbar">
    <div class="nav-container">
      <a href="index.html" class="brand">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
        %s
        <span class="brand-badge">v%s</span>
      </a>
      <button class="mobile-toggle" aria-label="Menü öffnen">☰</button>
      <ul class="nav-links">
        <li><a href="#features">Features</a></li>
        <li><a href="tutorial.html">Tutorial &amp; Bibliotheken</a></li>
        <li><a href="#code">Code-Vorschau</a></li>
        <li><a href="#downloads">Downloads</a></li>
        <li><a href="%s" target="_blank" rel="noopener">OpenEuphoria.org</a></li>
        <li><a href="%s" target="_blank" rel="noopener">GitHub</a></li>
        <li><a href="impressum.html">Impressum</a></li>
        <li><a href="#downloads" class="nav-btn">Download</a></li>
      </ul>
    </div>
  </nav>

  <!-- Hero Section -->
  <header class="hero">
    <div class="hero-container">
      <div class="hero-badges">
        <span class="pill pill-primary">⚡ Java 25 Virtual Machine</span>
        <span class="pill pill-accent">📌 Prozedurale Sprache mit einfacher Syntax</span>
        <span class="pill">🌐 <a href="%s" target="_blank" rel="noopener" style="text-decoration:none; color:inherit;">openeuphoria.org</a></span>
        <span class="pill">🚀 65.536 Register VM</span>
        <span class="pill">📱 Responsive VS-UI Framework</span>
      </div>
      <h1>%s</h1>
      <p class="lead">%s</p>
      <div class="hero-cta">
        <a href="#downloads" class="btn btn-primary">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Standalone herunterladen (%s)
        </a>
        <a href="%s" target="_blank" rel="noopener" class="btn btn-secondary">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>
          GitHub Repository
        </a>
      </div>

      <!-- Interactive Code Showcase -->
      <div id="code" class="showcase-wrapper">
        <div class="terminal-header">
          <div class="terminal-dots">
            <span class="dot dot-red"></span>
            <span class="dot dot-yellow"></span>
            <span class="dot dot-green"></span>
          </div>
          <div class="terminal-tabs">
            <button class="terminal-tab active" data-target="tab-vsui">vsui_server.ex</button>
            <button class="terminal-tab" data-target="tab-threads">threads.ex</button>
            <button class="terminal-tab" data-target="tab-sqlite">sqlite_json.ex</button>
          </div>
        </div>
        <div class="terminal-body">
          <div id="tab-vsui" class="code-tab-content active">
<pre><span class="token-cmt">-- Autarker High-Density Webserver mit reaktiven Patches & Mobile Grid</span>
<span class="token-kw">include</span> std/vsui.e <span class="token-kw">as</span> vsui

<span class="token-kw">integer</span> app = vsui:app(<span class="token-str">"ERP Cockpit"</span>, <span class="token-num">8089</span>)

<span class="token-kw">function</span> on_speichern(<span class="token-kw">sequence</span> ctx)
    <span class="token-kw">sequence</span> kdnr = vsui:val(ctx, <span class="token-str">"txt_kdnr"</span>)
    <span class="token-kw">sequence</span> name = vsui:val(ctx, <span class="token-str">"txt_name"</span>)
    
    <span class="token-cmt">-- Schneller Daten-Patch (flackerfreies Client-Rendering ohne Reload)</span>
    <span class="token-kw">return</span> vsui:updates({
        vsui:grid_set_data(<span class="token-str">"grid_kunden"</span>, {{kdnr, name, <span class="token-str">"Aktiv"</span>}}),
        vsui:clear_form(<span class="token-str">"form_kunden"</span>),
        vsui:set_focus(<span class="token-str">"txt_kdnr"</span>),
        vsui:toast_show(<span class="token-str">"Kunde erfolgreich gespeichert!"</span>, vsui:TOAST_SUCCESS)
    })
<span class="token-kw">end function</span>

vsui:on_click(app, <span class="token-str">"btn_save"</span>, <span class="token-fn">routine_id</span>(<span class="token-str">"on_speichern"</span>))
vsui:run(app)</pre>
          </div>
          <div id="tab-threads" class="code-tab-content">
<pre><span class="token-cmt">-- Concurrency mit Java 25 Loom Virtual Threads & CSP Channels</span>
<span class="token-kw">include</span> std/thread.e <span class="token-kw">as</span> thread
<span class="token-kw">include</span> std/channel.e <span class="token-kw">as</span> chan

<span class="token-kw">integer</span> ch = chan:new(<span class="token-num">10</span>)

<span class="token-kw">procedure</span> worker(<span class="token-kw">integer</span> id)
    <span class="token-kw">for</span> i = <span class="token-num">1</span> <span class="token-kw">to</span> <span class="token-num">1000</span> <span class="token-kw">do</span>
        chan:send(ch, {id, i, i * <span class="token-num">2</span>})
    <span class="token-kw">end for</span>
<span class="token-kw">end procedure</span>

<span class="token-cmt">-- Starte 50 parallele Virtual Threads (extrem leichtgewichtig)</span>
<span class="token-kw">for</span> w = <span class="token-num">1</span> <span class="token-kw">to</span> <span class="token-num">50</span> <span class="token-kw">do</span>
    thread:spawn(<span class="token-fn">routine_id</span>(<span class="token-str">"worker"</span>), {w})
<span class="token-kw">end for</span></pre>
          </div>
          <div id="tab-sqlite" class="code-tab-content">
<pre><span class="token-cmt">-- SQLite 3.47 Transaktionen & JSONPath Validierung</span>
<span class="token-kw">include</span> std/sqlite.e <span class="token-kw">as</span> sqlite
<span class="token-kw">include</span> std/json.e <span class="token-kw">as</span> json

<span class="token-kw">atom</span> db = sqlite:open(<span class="token-str">":memory:"</span>)
sqlite:exec(db, <span class="token-str">"CREATE TABLE artikel (artnr TEXT, bezeichnung TEXT, preis REAL);"</span>)
sqlite:exec(db, <span class="token-str">"INSERT INTO artikel VALUES (?, ?, ?);"</span>, {<span class="token-str">"A100"</span>, <span class="token-str">"Kugelschreiber"</span>, <span class="token-num">1.95</span>})

<span class="token-kw">sequence</span> rows = sqlite:query_all(db, <span class="token-str">"SELECT * FROM artikel;"</span>)
<span class="token-kw">sequence</span> json_str = json:encode(rows, <span class="token-num">2</span>)
puts(<span class="token-num">1</span>, json_str)</pre>
          </div>
        </div>
      </div>
    </div>
  </header>

  <!-- Features Section -->
  <section id="features" class="section section-alt">
    <div class="container">
      <div class="section-header">
        <h2>Architektur & Highlights</h2>
        <p>Euphorix vereint bewährte prozedurale Sprachkonzepte mit modernster Compiler- & VM-Technologie für datenintensive Geschäftsanwendungen.</p>
      </div>
      <div class="feature-grid">
        <div class="feature-card">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>
          </div>
          <h3>Prozedural &amp; Klare Syntax</h3>
          <p>OpenEuphoria ist eine moderne, rein prozedurale Programmiersprache ohne schwerfällige Objekt-Boilerplate. Universelle, dynamische <em>Sequences</em> als primäre Datenstruktur ermöglichen intuitive, robuste und blitzschnelle Programme. Sprachspezifikation auf <a href="%s" target="_blank" rel="noopener" style="color:var(--primary); font-weight:600;">openeuphoria.org</a>.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="4" width="16" height="16" rx="2" ry="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>
          </div>
          <h3>65.536-Register-VM</h3>
          <p>Clean-Room Register-Interpreter mit Copy-on-Write-Speicherverwaltung, 48-Bit Fast-Integers und hochoptimiertem Bytecode-Dispatch.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
          </div>
          <h3>Loom Virtual Threads</h3>
          <p>Mühelos skalierbare Nebenläufigkeit ohne Callback-Hölle: Millionen leichtgewichtiger Java 25 Threads, Async/Await und CSP Channels.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
          </div>
          <h3>High-Density Web-UI (VS-UI)</h3>
          <p>Autarkes, reaktives Webframework aus Volker Schultes cgibash/html. Sticky-Header DataGrid, flackerfreie JSON-Patches und automatischer Mobile-Card-View.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>
          </div>
          <h3>SQLite 3.47 & PostgreSQL</h3>
          <p>Integrierte Enterprise-Treiber für relationale Datenbanken, Transaktionen, Prepared Statements und direkten JSON/CSV-Export.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>
          </div>
          <h3>861 Standard-Routinen</h3>
          <p>74 vollständige Standard-Include-Dateien mit nativer Unterstützung für UTF-8 Unicode, RFC 9535 JSONPath, XML/XPath und HTTP/REST.</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Download Center -->
  <section id="downloads" class="section">
    <div class="container">
      <div class="section-header">
        <h2>Download Center</h2>
        <p>Laden Sie die autarke Linux-Binary, das plattformunabhängige JAR-Paket oder die vollständigen Handbücher als PDF und Markdown herunter.</p>
      </div>
      <div class="download-grid">

        <!-- Standalone Card -->
        <div class="download-card featured">
          <span class="download-card-badge">%s</span>
          <div>
            <h3>%s</h3>
            <div class="download-meta">
              <span>Linux 64-Bit</span> • <span>%s</span>
            </div>
            <p>%s</p>
          </div>
          <div>
            <a href="downloads/%s" download class="btn btn-primary">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              Datei herunterladen
            </a>
            <div class="download-cmd">
              <code>%s</code>
              <button class="btn-copy" onclick="copyCommand('%s', this)">Kopieren</button>
            </div>
          </div>
        </div>

        <!-- JAR Card -->
        <div class="download-card">
          <span class="download-card-badge badge-accent">%s</span>
          <div>
            <h3>%s</h3>
            <div class="download-meta">
              <span>Java 25+</span> • <span>%s</span>
            </div>
            <p>%s</p>
          </div>
          <div>
            <a href="downloads/%s" download class="btn btn-secondary">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              JAR herunterladen
            </a>
            <div class="download-cmd">
              <code>%s</code>
              <button class="btn-copy" onclick="copyCommand('%s', this)">Kopieren</button>
            </div>
          </div>
        </div>

        <!-- Handbuch DE Card -->
        <div class="download-card">
          <span class="download-card-badge">PDF &amp; Markdown</span>
          <div>
            <h3>%s</h3>
            <div class="download-meta">
              <span>15 Kapitel</span> • <span>861 Routinen</span>
            </div>
            <p>%s</p>
          </div>
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <a href="downloads/%s" download class="btn btn-primary" style="justify-content: center;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              PDF Handbuch (%s)
            </a>
            <a href="downloads/%s" download class="btn btn-secondary" style="justify-content: center; font-size: 0.85rem; padding: 8px 12px;">
              Markdown Quelle (%s)
            </a>
          </div>
        </div>

        <!-- Manual EN Card -->
        <div class="download-card">
          <span class="download-card-badge">PDF &amp; Markdown</span>
          <div>
            <h3>%s</h3>
            <div class="download-meta">
              <span>15 Chapters</span> • <span>Full Reference</span>
            </div>
            <p>%s</p>
          </div>
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <a href="downloads/%s" download class="btn btn-primary" style="justify-content: center;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              PDF Manual (%s)
            </a>
            <a href="downloads/%s" download class="btn btn-secondary" style="justify-content: center; font-size: 0.85rem; padding: 8px 12px;">
              Markdown Source (%s)
            </a>
          </div>
        </div>

      </div>
    </div>
  </section>

  <!-- GitHub Banner Section -->
  <section class="section section-alt">
    <div class="container">
      <div class="github-banner">
        <div>
          <h3>Open Source auf GitHub</h3>
          <p>Der Quellcode von Euphorix, der virtuelle Maschinenkern und die Standardbibliotheken sind quelloffen unter der %s lizenziert. Kompatibel mit der OpenEuphoria Sprachspezifikation.</p>
        </div>
        <div class="github-clone-box">
          <code>git clone %s.git</code>
          <button class="btn-copy" onclick="copyCommand('git clone %s.git', this)">Kopieren</button>
        </div>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer>
    <div class="footer-container">
      <div>
        <p><strong>%s v%s</strong> – %s</p>
        <p style="font-size: 0.85rem; color: #94a3b8; margin-top: 4px;">&copy; %s %s. Lizenziert unter der %s. Basierend auf der <a href="%s" target="_blank" rel="noopener" style="color:#64748b; text-decoration:underline;">OpenEuphoria</a> Sprachspezifikation.</p>
      </div>
      <ul class="footer-links">
        <li><a href="#features">Features</a></li>
        <li><a href="tutorial.html">Tutorial &amp; Bibliotheken</a></li>
        <li><a href="#downloads">Downloads</a></li>
        <li><a href="%s" target="_blank" rel="noopener">OpenEuphoria.org</a></li>
        <li><a href="%s" target="_blank" rel="noopener">GitHub</a></li>
        <li><a href="impressum.html">Impressum &amp; Datenschutz</a></li>
      </ul>
    </div>
  </footer>

  <script src="js/main.js"></script>
</body>
</html>`, {
        proj_name, proj_tagline, proj_subhead,
        proj_name, proj_ver, openeu_url, github_url,
        openeu_url, proj_headline, proj_subhead, dl_std_size, github_url,
        openeu_url,
        -- Standalone card
        dl_std_badge, dl_std_title, dl_std_size, dl_std_desc, dl_std_fn, dl_std_cmd, dl_std_cmd,
        -- JAR card
        dl_jar_badge, dl_jar_title, dl_jar_size, dl_jar_desc, dl_jar_fn, dl_jar_cmd, dl_jar_cmd,
        -- Handbuch DE card
        dl_hde_title, dl_hde_desc, dl_hpdf_fn, dl_hpdf_size, dl_hde_fn, dl_hde_size,
        -- Manual EN card
        dl_men_title, dl_men_desc, dl_mpdf_fn, dl_mpdf_size, dl_men_fn, dl_men_size,
        -- GitHub banner
        license, github_url, github_url,
        -- Footer
        proj_name, proj_ver, proj_tagline, "2026", imp_owner, license, openeu_url, openeu_url, github_url
    })
    io:write_file(OUT_DIR & "/index.html", index_html)

    -- 7. Generate tutorial.html & sync tutorial code
    puts(1, "7. Erzeuge Tutorialseite 'website/tutorial.html'...\n")
    system_exec("python3 tools/generate_tutorial.py website/tutorial.html", 2)
    system_exec("mkdir -p website/downloads/tutorial && cp -r tutorial/*.ex website/downloads/tutorial/", 2)

    -- 8. Generate impressum.html
    puts(1, "8. Erzeuge Impressums- & Datenschutzseite 'website/impressum.html'...\n")
    sequence imp_html = sprintf(`<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Impressum & Datenschutz – %s</title>
  <link rel="stylesheet" href="css/style.css">
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
</head>
<body>

  <!-- Navigation Bar -->
  <nav class="navbar">
    <div class="nav-container">
      <a href="index.html" class="brand">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
        %s
        <span class="brand-badge">v%s</span>
      </a>
      <ul class="nav-links">
        <li><a href="index.html#features">Features</a></li>
        <li><a href="tutorial.html">Tutorial &amp; Bibliotheken</a></li>
        <li><a href="index.html#downloads">Downloads</a></li>
        <li><a href="%s" target="_blank" rel="noopener">GitHub</a></li>
        <li><a href="index.html" class="nav-btn">← Zurück zur Startseite</a></li>
      </ul>
    </div>
  </nav>

  <main class="legal-page">
    <div class="legal-card">
      <h1>Impressum & Datenschutz</h1>

      <h2>Angaben gemäß § 5 TMG</h2>
      <div class="legal-contact-box">
        <strong>%s</strong><br>
        %s<br>
        %s<br>
        %s, %s<br><br>
        <strong>Kontakt:</strong><br>
        E-Mail: <a href="mailto:%s" style="color:var(--primary); font-weight:600;">%s</a><br>
        Telefon: %s<br><br>
        %s
      </div>

      <h2>Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV</h2>
      <p>%s</p>

      <h2>Haftungsausschluss (Disclaimer)</h2>
      <p>%s</p>

      <h2>Datenschutzerklärung (DSGVO)</h2>
      <p>%s</p>

      <h2>Urheberrecht & Lizenz</h2>
      <p>Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem deutschen Urheberrecht. Euphorix wird unter den Bedingungen der <strong>%s</strong> als freie Software zur Verfügung gestellt.</p>

      <div style="margin-top: 36px; padding-top: 20px; border-top: 1px solid var(--border-light);">
        <a href="index.html" class="btn btn-secondary">← Zurück zur Startseite</a>
      </div>
    </div>
  </main>

  <!-- Footer -->
  <footer>
    <div class="footer-container">
      <div>
        <p><strong>%s v%s</strong> – %s</p>
        <p style="font-size: 0.85rem; color: #94a3b8; margin-top: 4px;">&copy; %s %s. Lizenziert unter der %s.</p>
      </div>
      <ul class="footer-links">
        <li><a href="index.html">Startseite</a></li>
        <li><a href="tutorial.html">Tutorial &amp; Bibliotheken</a></li>
        <li><a href="index.html#downloads">Downloads</a></li>
        <li><a href="%s" target="_blank" rel="noopener">GitHub</a></li>
      </ul>
    </div>
  </footer>

</body>
</html>`, {
        proj_name,
        proj_name, proj_ver, github_url,
        imp_comp, imp_owner, imp_street, imp_city, imp_country,
        imp_email, imp_email, imp_phone,
        iff(length(imp_taxid) > 0, "Steuernummer: " & imp_taxid & "<br>", ""),
        imp_resp, imp_discl, imp_priv, license,
        proj_name, proj_ver, proj_tagline, "2026", imp_owner, license, github_url
    })
    io:write_file(OUT_DIR & "/impressum.html", imp_html)

    -- 9. Generate lighttpd_sample.conf
    puts(1, "9. Erzeuge Serverkonfiguration 'website/lighttpd_sample.conf'...\n")
    sequence lighttpd_conf = `################################################################################
# lighttpd.conf – Beispiel-Konfiguration für die Euphorix-Webseite
#
# Kopieren Sie diese Datei oder binden Sie die Anweisungen in Ihre
# bestehende /etc/lighttpd/lighttpd.conf auf Ihrem Webserver ein.
################################################################################

server.modules += (
    "mod_access",
    "mod_alias",
    "mod_compress",
    "mod_redirect",
    "mod_setenv"
)

# Pfad zum Web-Root (passen Sie den Pfad an Ihr System an)
server.document-root = "/var/www/html"

# Index-Dateien
index-file.names = ( "index.html", "index.htm" )

# Standard-MIME-Typen
mimetype.assign = (
    ".html" => "text/html; charset=utf-8",
    ".htm"  => "text/html; charset=utf-8",
    ".css"  => "text/css; charset=utf-8",
    ".js"   => "application/javascript; charset=utf-8",
    ".json" => "application/json; charset=utf-8",
    ".svg"  => "image/svg+xml",
    ".png"  => "image/png",
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".ico"  => "image/x-icon",
    ".md"   => "text/markdown; charset=utf-8",
    ".jar"  => "application/java-archive",
    ""      => "application/octet-stream"
)

# GZIP/Brotli-Kompression für Text-Ressourcen aktivieren
compress.cache-dir = "/var/cache/lighttpd/compress/"
compress.filetype  = (
    "text/plain",
    "text/html",
    "text/css",
    "text/markdown",
    "application/javascript",
    "application/json",
    "image/svg+xml"
)

# Download-Header erzwingen für Dateien im downloads/-Verzeichnis
$HTTP["url"] =~ "^/downloads/" {
    setenv.add-response-header = (
        "Content-Disposition" => "attachment"
    )
}

# Caching-Header für statische Stylesheets und Scripts (1 Woche)
$HTTP["url"] =~ "^/(css|js)/" {
    setenv.add-response-header = (
        "Cache-Control" => "public, max-age=604800, immutable"
    )
}
`
    io:write_file(OUT_DIR & "/lighttpd_sample.conf", lighttpd_conf)

    puts(1, "\n=== Webseite erfolgreich generiert! ===\n\n")
    puts(1, "Verzeichnis: website/\n")
    puts(1, "Dateien:\n")
    puts(1, "  ├── website/index.html            (Hauptseite mit Downloads & Code-Preview)\n")
    puts(1, "  ├── website/tutorial.html         (Interaktives Tutorial & Standard-Bibliotheks-Handbuch)\n")
    puts(1, "  ├── website/impressum.html        (Rechtssicheres Impressum & Datenschutz aus Config)\n")
    puts(1, "  ├── website/css/style.css         (Modernes, responsives CSS-Theme)\n")
    puts(1, "  ├── website/js/main.js            (Echtzeit-Suche, Tab-Wechsler, Copy-Buttons)\n")
    puts(1, "  ├── website/downloads/            (Enthält Standalone-Binary, JAR, Handbücher & Tutorial-Code)\n")
    puts(1, "  └── website/lighttpd_sample.conf  (Fertige lighttpd-Konfigurationsvorlage)\n\n")
    puts(1, "Bereit zum Kopieren auf Ihren Webserver via scp / rsync:\n")
    puts(1, "  scp -r website/* user@ihr-server:/var/www/html/\n\n")
end procedure

function iff(integer cond, object true_val, object false_val)
    if cond then return true_val else return false_val end if
end function

main()
