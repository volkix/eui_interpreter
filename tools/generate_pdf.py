#!/usr/bin/env python3
"""
Generate professional PDF versions of HANDBUCH.md and MANUAL.md
using Headless Chrome print-to-pdf.
"""

import os
import re
import subprocess
import tempfile

def md_to_html(md_text, title="Dokumentation"):
    lines = md_text.splitlines()
    html_lines = []
    in_code = False
    code_lang = ''
    code_buf = []
    in_table = False
    in_list = False
    list_type = 'ul'

    def inline_fmt(txt):
        txt = txt.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        txt = re.sub(r'`([^`]+)`', r'<code>\1</code>', txt)
        txt = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', txt)
        txt = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', txt)
        txt = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', txt)
        return txt

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Code block fence
        if stripped.startswith('```'):
            if in_code:
                in_code = False
                html_lines.append(f'<pre><code class="language-{code_lang}">' + '\n'.join(code_buf) + '</code></pre>')
                code_buf = []
            else:
                if in_list: html_lines.append(f'</{list_type}>'); in_list = False
                if in_table: html_lines.append('</tbody></table>'); in_table = False
                in_code = True
                code_lang = stripped[3:].strip()
            i += 1
            continue

        if in_code:
            code_buf.append(line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))
            i += 1
            continue

        # Blank line
        if not stripped:
            if in_list: html_lines.append(f'</{list_type}>'); in_list = False
            if in_table: html_lines.append('</tbody></table>'); in_table = False
            i += 1
            continue

        # Tables
        if stripped.startswith('|') and stripped.endswith('|'):
            cells = [c.strip() for c in stripped[1:-1].split('|')]
            if not in_table:
                if in_list: html_lines.append(f'</{list_type}>'); in_list = False
                in_table = True
                html_lines.append('<table class="styled-table"><thead><tr>')
                for c in cells:
                    html_lines.append(f'<th>{inline_fmt(c)}</th>')
                html_lines.append('</tr></thead><tbody>')
                if i + 1 < len(lines) and '---' in lines[i+1]:
                    i += 2
                    continue
            else:
                html_lines.append('<tr>')
                for c in cells:
                    html_lines.append(f'<td>{inline_fmt(c)}</td>')
                html_lines.append('</tr>')
            i += 1
            continue
        elif in_table:
            html_lines.append('</tbody></table>')
            in_table = False

        # Headers
        if stripped.startswith('#### '):
            if in_list: html_lines.append(f'</{list_type}>'); in_list = False
            html_lines.append(f'<h4>{inline_fmt(stripped[5:])}</h4>')
            i += 1
            continue
        if stripped.startswith('### '):
            if in_list: html_lines.append(f'</{list_type}>'); in_list = False
            html_lines.append(f'<h3>{inline_fmt(stripped[4:])}</h3>')
            i += 1
            continue
        if stripped.startswith('## '):
            if in_list: html_lines.append(f'</{list_type}>'); in_list = False
            heading_text = stripped[3:].strip()
            if re.match(r'^\d+\.', heading_text):
                html_lines.append(f'<h2 class="chapter-heading">{inline_fmt(heading_text)}</h2>')
            else:
                html_lines.append(f'<h2>{inline_fmt(heading_text)}</h2>')
            i += 1
            continue
        if stripped.startswith('# '):
            if in_list: html_lines.append(f'</{list_type}>'); in_list = False
            html_lines.append(f'<h1>{inline_fmt(stripped[2:])}</h1>')
            i += 1
            continue

        # Horizontal rule
        if stripped in ('---', '***', '___'):
            if in_list: html_lines.append(f'</{list_type}>'); in_list = False
            html_lines.append('<hr>')
            i += 1
            continue

        # Lists
        if stripped.startswith('* ') or stripped.startswith('- '):
            if not in_list or list_type != 'ul':
                if in_list: html_lines.append(f'</{list_type}>')
                html_lines.append('<ul>')
                in_list = True
                list_type = 'ul'
            html_lines.append(f'<li>{inline_fmt(stripped[2:])}</li>')
            i += 1
            continue
        if re.match(r'^\d+\.\s', stripped):
            match = re.match(r'^\d+\.\s(.*)$', stripped)
            if not in_list or list_type != 'ol':
                if in_list: html_lines.append(f'</{list_type}>')
                html_lines.append('<ol>')
                in_list = True
                list_type = 'ol'
            html_lines.append(f'<li>{inline_fmt(match.group(1))}</li>')
            i += 1
            continue

        if in_list:
            html_lines.append(f'</{list_type}>')
            in_list = False

        # Blockquote / Alert
        if stripped.startswith('> '):
            html_lines.append(f'<blockquote>{inline_fmt(stripped[2:])}</blockquote>')
            i += 1
            continue

        # Regular Paragraph
        html_lines.append(f'<p>{inline_fmt(stripped)}</p>')
        i += 1

    if in_list: html_lines.append(f'</{list_type}>')
    if in_table: html_lines.append('</tbody></table>')
    if in_code: html_lines.append('</pre>')

    body_content = '\n'.join(html_lines)

    html_doc = f"""<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <title>{title}</title>
  <style>
    @page {{
      size: A4;
      margin: 18mm 15mm 18mm 15mm;
    }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 9.5pt;
      line-height: 1.5;
      color: #1e293b;
    }}
    h1 {{
      font-size: 22pt;
      color: #41518b;
      border-bottom: 2pt solid #41518b;
      padding-bottom: 4px;
      margin-top: 18pt;
      margin-bottom: 12pt;
      page-break-before: always;
    }}
    h1:first-of-type {{
      page-break-before: avoid;
    }}
    h2 {{
      font-size: 15pt;
      color: #2b3864;
      border-bottom: 1pt solid #cbd5e1;
      padding-bottom: 3px;
      margin-top: 16pt;
      margin-bottom: 8pt;
      page-break-after: avoid;
    }}
    h2.chapter-heading {{
      page-break-before: always;
      font-size: 16pt;
      color: #1e3a8a;
      border-bottom: 2pt solid #41518b;
      padding-bottom: 4px;
      margin-top: 24pt;
      margin-bottom: 12pt;
      page-break-after: avoid;
    }}
    h3 {{
      font-size: 12pt;
      color: #334155;
      margin-top: 12pt;
      margin-bottom: 6pt;
      page-break-after: avoid;
    }}
    h4 {{
      font-size: 10.5pt;
      color: #41518b;
      margin-top: 10pt;
      margin-bottom: 4pt;
      page-break-after: avoid;
    }}
    p, ul, ol {{
      margin-bottom: 6pt;
    }}
    ul, ol {{
      padding-left: 20px;
    }}
    li {{
      margin-bottom: 3pt;
    }}
    code {{
      font-family: 'JetBrains Mono', Consolas, Monaco, monospace;
      font-size: 8.5pt;
      background: #f1f5f9;
      padding: 1pt 3pt;
      border-radius: 2pt;
      color: #0f172a;
    }}
    pre {{
      background: #0f172a;
      color: #f8fafc;
      padding: 8pt 10pt;
      border-radius: 4pt;
      font-family: 'JetBrains Mono', Consolas, Monaco, monospace;
      font-size: 8pt;
      line-height: 1.4;
      page-break-inside: avoid;
      margin: 6pt 0 10pt;
    }}
    pre code {{
      background: transparent;
      color: inherit;
      padding: 0;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin: 8pt 0 12pt;
      page-break-inside: avoid;
      font-size: 8.5pt;
    }}
    th, td {{
      border: 1pt solid #cbd5e1;
      padding: 4pt 6pt;
      text-align: left;
      vertical-align: top;
    }}
    th {{
      background: #41518b;
      color: white;
      font-weight: 600;
    }}
    tr:nth-child(even) {{
      background: #f8fafc;
    }}
    blockquote {{
      border-left: 3pt solid #41518b;
      padding: 4pt 8pt;
      background: #f1f5f9;
      margin: 6pt 0;
      color: #334155;
    }}
    hr {{
      border: none;
      border-top: 1pt solid #e2e8f0;
      margin: 14pt 0;
    }}
    a {{
      color: #41518b;
      text-decoration: none;
    }}
  </style>
</head>
<body>
{body_content}
</body>
</html>
"""
    return html_doc

def build_pdf(src_md, dest_pdf, title):
    if not os.path.exists(src_md):
        print(f"Skipping {src_md} (not found)")
        return False

    print(f"Rendering {src_md} -> {dest_pdf}...")
    with open(src_md, 'r', encoding='utf-8') as f:
        md_text = f.read()

    html_content = md_to_html(md_text, title)

    with tempfile.NamedTemporaryFile('w', suffix='.html', encoding='utf-8', delete=False) as tf:
        tf.write(html_content)
        temp_html_path = tf.name

    try:
        cmd = [
            'google-chrome',
            '--headless',
            '--disable-gpu',
            '--no-sandbox',
            '--generate-pdf-document-outline',
            f'--print-to-pdf={dest_pdf}',
            temp_html_path
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0 and os.path.exists(dest_pdf):
            size_mb = os.path.getsize(dest_pdf) / (1024 * 1024)
            print(f"  ✓ Created {dest_pdf} ({size_mb:.2f} MB)")
            return True
        else:
            print(f"  ✗ Chrome error: {res.stderr}")
            return False
    finally:
        if os.path.exists(temp_html_path):
            os.remove(temp_html_path)

if __name__ == '__main__':
    os.makedirs('website/downloads', exist_ok=True)
    build_pdf('HANDBUCH.md', 'website/downloads/HANDBUCH.pdf', 'Euphorix Handbuch (Deutsch)')
    build_pdf('MANUAL.md', 'website/downloads/MANUAL.pdf', 'Euphorix Developer Manual (English)')
