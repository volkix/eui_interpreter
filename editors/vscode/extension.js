// Euphorix Language Support Extension for VS Code
// Zero external dependencies - pure VS Code API + Node.js child_process stdio JSON-RPC
// Works seamlessly in both modes:
// 1. Full IDE Mode (with Euphorix LSP: Live diagnostics, cross-file definition, parameter hints)
// 2. Standalone Editor Mode (without Euphorix installed: Syntax highlighting, snippets, formatting, outline)

const vscode = require('vscode');
const cp = require('child_process');
const path = require('path');
const fs = require('fs');

let lspProcess = null;
let msgId = 1;
const pendingRequests = new Map();
let incomingBuffer = Buffer.alloc(0);
let diagCollection = null;
let statusBarItem = null;

function resolveExecutable() {
    const config = vscode.workspace.getConfiguration('euphorix');
    const custom = config.get('executablePath', 'euphorix');
    if (custom && custom !== 'euphorix' && fs.existsSync(custom)) {
        return custom;
    }

    // Try common workspace paths
    const workspaceRoot = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
        ? vscode.workspace.workspaceFolders[0].uri.fsPath : null;

    if (workspaceRoot) {
        const localBin = path.join(workspaceRoot, 'euphorix');
        if (fs.existsSync(localBin)) return localBin;
    }

    if (fs.existsSync('/home/volkix/prj/intpret/euphorix')) {
        return '/home/volkix/prj/intpret/euphorix';
    }

    return 'euphorix';
}

function sendRpc(method, params, id) {
    if (!lspProcess || !lspProcess.stdin || !lspProcess.stdin.writable) return;
    const msg = { jsonrpc: '2.0', method, params };
    if (id !== undefined) msg.id = id;
    const body = Buffer.from(JSON.stringify(msg), 'utf8');
    const header = Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, 'ascii');
    try {
        lspProcess.stdin.write(header);
        lspProcess.stdin.write(body);
    } catch (e) {
        console.error('[Euphorix LSP] Write error:', e);
    }
}

function callRpc(method, params) {
    if (!lspProcess) return Promise.resolve(null);
    const id = msgId++;
    return new Promise((resolve) => {
        pendingRequests.set(id, resolve);
        sendRpc(method, params, id);
        setTimeout(() => {
            if (pendingRequests.has(id)) {
                pendingRequests.delete(id);
                resolve(null);
            }
        }, 3500);
    });
}

function handleRpcMessage(msg) {
    if (msg.id !== undefined && pendingRequests.has(msg.id)) {
        const resolve = pendingRequests.get(msg.id);
        pendingRequests.delete(msg.id);
        resolve(msg.result);
        return;
    }

    if (msg.method === 'textDocument/publishDiagnostics' && msg.params) {
        const uri = vscode.Uri.parse(msg.params.uri);
        const diags = (msg.params.diagnostics || []).map(d => {
            const range = new vscode.Range(
                Math.max(0, d.range.start.line),
                Math.max(0, d.range.start.character),
                Math.max(0, d.range.end.line),
                Math.max(0, d.range.end.character)
            );
            const severity = d.severity === 1 ? vscode.DiagnosticSeverity.Error
                : d.severity === 2 ? vscode.DiagnosticSeverity.Warning
                : vscode.DiagnosticSeverity.Information;
            const diag = new vscode.Diagnostic(range, d.message, severity);
            diag.source = d.source || 'euphorix';
            return diag;
        });
        if (diagCollection) {
            diagCollection.set(uri, diags);
        }
    }
}

function syncDocument(doc) {
    if (!doc || doc.languageId !== 'euphoria') return;
    sendRpc('textDocument/didOpen', {
        textDocument: {
            uri: doc.uri.toString(),
            languageId: 'euphoria',
            version: doc.version,
            text: doc.getText()
        }
    });
}

function startLspServer(context) {
    const execPath = resolveExecutable();
    try {
        lspProcess = cp.spawn(execPath, ['--lsp'], {
            stdio: ['pipe', 'pipe', 'pipe']
        });

        lspProcess.on('error', err => {
            console.log('[Euphorix LSP] Server binary not available, falling back to Editor Mode:', err.message);
            lspProcess = null;
            if (statusBarItem) {
                statusBarItem.text = '$(pencil) Euphorix: Editor-Modus';
                statusBarItem.tooltip = 'Syntax-Highlighting, Snippets und Formatierung aktiv (ohne installierten Euphorix-Compiler).';
                statusBarItem.show();
            }
        });

        lspProcess.stdout.on('data', chunk => {
            incomingBuffer = Buffer.concat([incomingBuffer, chunk]);
            while (true) {
                const headerEnd = incomingBuffer.indexOf('\r\n\r\n');
                if (headerEnd === -1) break;
                const headerStr = incomingBuffer.subarray(0, headerEnd).toString('ascii');
                const match = headerStr.match(/content-length:\s*(\d+)/i);
                if (!match) {
                    incomingBuffer = incomingBuffer.subarray(headerEnd + 4);
                    continue;
                }
                const contentLength = parseInt(match[1], 10);
                const totalLen = headerEnd + 4 + contentLength;
                if (incomingBuffer.length < totalLen) break;
                const bodyBytes = incomingBuffer.subarray(headerEnd + 4, totalLen);
                incomingBuffer = incomingBuffer.subarray(totalLen);
                try {
                    const msg = JSON.parse(bodyBytes.toString('utf8'));
                    handleRpcMessage(msg);
                } catch (e) {
                    console.error('[Euphorix LSP] JSON parse error:', e);
                }
            }
        });

        lspProcess.stderr.on('data', data => {
            console.log('[Euphorix LSP stderr]', data.toString());
        });

        lspProcess.on('exit', (code, sig) => {
            if (lspProcess) {
                if (statusBarItem) statusBarItem.text = '$(pencil) Euphorix: Editor-Modus';
                lspProcess = null;
            }
        });

        // Initialize server
        const rootUri = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
            ? vscode.workspace.workspaceFolders[0].uri.toString() : null;

        sendRpc('initialize', {
            processId: process.pid,
            rootUri: rootUri,
            capabilities: {
                textDocument: {
                    completion: { dynamicRegistration: false },
                    hover: { dynamicRegistration: false },
                    definition: { dynamicRegistration: false },
                    documentSymbol: { dynamicRegistration: false },
                    signatureHelp: { dynamicRegistration: false },
                    formatting: { dynamicRegistration: false }
                }
            }
        }, 0);

        if (statusBarItem) {
            statusBarItem.text = '$(check) Euphorix LSP: Aktiv';
            statusBarItem.tooltip = 'Euphorix Language Server 1.0 (Live-Diagnostik & IntelliSense)';
            statusBarItem.show();
        }

        vscode.workspace.textDocuments.forEach(doc => {
            if (doc.languageId === 'euphoria') {
                syncDocument(doc);
            }
        });

    } catch (err) {
        console.log('[Euphorix LSP] Spawn failed, switching to Editor Mode:', err.message);
        lspProcess = null;
        if (statusBarItem) {
            statusBarItem.text = '$(pencil) Euphorix: Editor-Modus';
            statusBarItem.tooltip = 'Syntax-Highlighting und Snippets aktiv.';
            statusBarItem.show();
        }
    }
}

function localFormat(text, options) {
    const tabSize = options.tabSize || 4;
    const indentStr = options.insertSpaces ? ' '.repeat(tabSize) : '\t';
    const lines = text.split(/\r?\n/);
    let currentIndent = 0;
    const formatted = [];

    for (let i = 0; i < lines.length; i++) {
        const raw = lines[i];
        const trimmed = raw.trim();
        if (trimmed.length === 0) {
            formatted.push('');
            continue;
        }

        const lower = trimmed.toLowerCase();
        let dedentThis = false;
        if (lower.startsWith('end ') || lower === 'end' ||
            lower.startsWith('else') || lower.startsWith('elsif ') ||
            lower.startsWith('case ') || lower === 'case' ||
            lower.startsWith('until ') || lower.startsWith('entry')) {
            dedentThis = true;
        }

        if (dedentThis && currentIndent > 0) {
            currentIndent--;
        }

        formatted.push(indentStr.repeat(currentIndent) + trimmed);

        let indentNext = false;
        if (lower.startsWith('function ') || lower.startsWith('procedure ') || lower.startsWith('type ') ||
            lower.startsWith('public function ') || lower.startsWith('public procedure ') || lower.startsWith('public type ') ||
            lower.startsWith('export function ') || lower.startsWith('export procedure ') || lower.startsWith('export type ') ||
            lower.startsWith('global function ') || lower.startsWith('global procedure ') || lower.startsWith('global type ') ||
            (lower.startsWith('if ') && lower.endsWith('then')) ||
            (lower.startsWith('elsif ') && lower.endsWith('then')) ||
            lower === 'else' ||
            (lower.startsWith('while ') && lower.endsWith('do')) ||
            (lower.startsWith('for ') && lower.endsWith('do')) ||
            lower === 'loop' ||
            (lower.startsWith('switch ') && lower.includes('do')) ||
            (lower.startsWith('case ') && lower.endsWith('then'))) {
            indentNext = true;
        }

        if (indentNext) {
            currentIndent++;
        }
    }
    return formatted.join('\n');
}

function activate(context) {
    const config = vscode.workspace.getConfiguration('euphorix');
    if (!config.get('lsp.enable', true)) {
        return;
    }

    diagCollection = vscode.languages.createDiagnosticCollection('euphorix');
    context.subscriptions.push(diagCollection);

    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.text = '$(sync~spin) Euphorix: Initialisiere...';
    statusBarItem.tooltip = 'Euphorix Language Support';
    context.subscriptions.push(statusBarItem);

    startLspServer(context);

    // Document synchronization with debounced change notification
    let changeTimer = null;
    context.subscriptions.push(
        vscode.workspace.onDidOpenTextDocument(doc => syncDocument(doc)),
        vscode.workspace.onDidChangeTextDocument(evt => {
            if (evt.document.languageId === 'euphoria' && lspProcess) {
                if (changeTimer) clearTimeout(changeTimer);
                changeTimer = setTimeout(() => {
                    sendRpc('textDocument/didChange', {
                        textDocument: {
                            uri: evt.document.uri.toString(),
                            version: evt.document.version
                        },
                        contentChanges: [{ text: evt.document.getText() }]
                    });
                }, 150);
            }
        }),
        vscode.workspace.onDidCloseTextDocument(doc => {
            if (doc.languageId === 'euphoria') {
                if (lspProcess) {
                    sendRpc('textDocument/didClose', {
                        textDocument: { uri: doc.uri.toString() }
                    });
                }
                diagCollection.delete(doc.uri);
            }
        })
    );

    // Commands: Run and Compile File
    context.subscriptions.push(
        vscode.commands.registerCommand('euphorix.runFile', () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) return;
            const doc = editor.document;
            const execPath = resolveExecutable();
            if (!fs.existsSync(execPath) && execPath === 'euphorix') {
                vscode.window.showInformationMessage(
                    'Zum Ausführen von Euphorix-Skripten wird die Euphorix-Laufzeitumgebung benötigt. Installieren Sie "euphorix" oder tragen Sie den Pfad in den Einstellungen ein.'
                );
                return;
            }
            doc.save().then(() => {
                const term = vscode.window.terminals.find(t => t.name === 'Euphorix') || vscode.window.createTerminal('Euphorix');
                term.show();
                term.sendText(`"${execPath}" "${doc.fileName}"`);
            });
        }),
        vscode.commands.registerCommand('euphorix.compileFile', () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) return;
            const doc = editor.document;
            const execPath = resolveExecutable();
            if (!fs.existsSync(execPath) && execPath === 'euphorix') {
                vscode.window.showInformationMessage(
                    'Zum Kompilieren von Euphorix-Skripten zu Bytecode (.exb) wird die Euphorix-Laufzeitumgebung benötigt.'
                );
                return;
            }
            doc.save().then(() => {
                const outPath = doc.fileName.replace(/\.(ex|e|ew|eu)$/, '') + '.exb';
                const term = vscode.window.terminals.find(t => t.name === 'Euphorix') || vscode.window.createTerminal('Euphorix');
                term.show();
                term.sendText(`"${execPath}" --compile "${doc.fileName}" -o "${outPath}"`);
            });
        }),
        vscode.commands.registerCommand('euphorix.restartServer', () => {
            if (lspProcess) {
                try { lspProcess.kill(); } catch (e) {}
                lspProcess = null;
            }
            startLspServer(context);
            vscode.window.showInformationMessage('Euphorix Language Server wurde neu gestartet.');
        })
    );

    // Completion Provider (Uses LSP when available, falls back gracefully)
    context.subscriptions.push(
        vscode.languages.registerCompletionItemProvider('euphoria', {
            async provideCompletionItems(document, position, token, context) {
                if (!lspProcess) return [];

                const res = await callRpc('textDocument/completion', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character },
                    context: {
                        triggerKind: context.triggerKind,
                        triggerCharacter: context.triggerCharacter
                    }
                });

                if (!res || !res.items) return [];

                return res.items.map(it => {
                    const kindMap = {
                        1: vscode.CompletionItemKind.Text,
                        2: vscode.CompletionItemKind.Method,
                        3: vscode.CompletionItemKind.Function,
                        5: vscode.CompletionItemKind.Class,
                        6: vscode.CompletionItemKind.Variable,
                        9: vscode.CompletionItemKind.Module,
                        10: vscode.CompletionItemKind.Enum,
                        12: vscode.CompletionItemKind.Function,
                        14: vscode.CompletionItemKind.Keyword,
                        15: vscode.CompletionItemKind.Snippet,
                        17: vscode.CompletionItemKind.File,
                        21: vscode.CompletionItemKind.Constant
                    };
                    const item = new vscode.CompletionItem(it.label, kindMap[it.kind] || vscode.CompletionItemKind.Property);
                    item.detail = it.detail;
                    if (it.documentation) {
                        item.documentation = new vscode.MarkdownString(it.documentation);
                    }
                    if (it.insertTextFormat === 2) {
                        item.insertText = new vscode.SnippetString(it.insertText || it.label);
                    } else if (it.insertText) {
                        item.insertText = it.insertText;
                    }
                    return item;
                });
            }
        }, ':', '.', '%', '/', ' ', '(', '"')
    );

    // Signature Help Provider (Parameter Hints)
    context.subscriptions.push(
        vscode.languages.registerSignatureHelpProvider('euphoria', {
            async provideSignatureHelp(document, position, token, context) {
                if (!lspProcess) return null;

                const res = await callRpc('textDocument/signatureHelp', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character },
                    context: {
                        triggerKind: context.triggerKind,
                        triggerCharacter: context.triggerCharacter
                    }
                });

                if (!res || !res.signatures || res.signatures.length === 0) return null;

                const help = new vscode.SignatureHelp();
                help.activeSignature = res.activeSignature || 0;
                help.activeParameter = res.activeParameter || 0;
                help.signatures = res.signatures.map(s => {
                    const docStr = s.documentation?.value || s.documentation || '';
                    const sig = new vscode.SignatureInformation(s.label, new vscode.MarkdownString(docStr));
                    if (Array.isArray(s.parameters)) {
                        sig.parameters = s.parameters.map(p => new vscode.ParameterInformation(p.label));
                    }
                    return sig;
                });
                return help;
            }
        }, '(', ',')
    );

    // Hover Provider
    context.subscriptions.push(
        vscode.languages.registerHoverProvider('euphoria', {
            async provideHover(document, position) {
                if (!lspProcess) return null;

                const res = await callRpc('textDocument/hover', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character }
                });

                if (res && res.contents && res.contents.value) {
                    return new vscode.Hover(new vscode.MarkdownString(res.contents.value));
                }
                return null;
            }
        })
    );

    // Definition Provider (Go-To-Definition across files)
    context.subscriptions.push(
        vscode.languages.registerDefinitionProvider('euphoria', {
            async provideDefinition(document, position) {
                if (!lspProcess) return null;

                const res = await callRpc('textDocument/definition', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character }
                });

                if (res && res.uri && res.range) {
                    const targetUri = vscode.Uri.parse(res.uri);
                    const targetRange = new vscode.Range(
                        res.range.start.line, res.range.start.character,
                        res.range.end.line, res.range.end.character
                    );
                    return new vscode.Location(targetUri, targetRange);
                }
                return null;
            }
        })
    );

    // Document Symbol Provider (Outline & Breadcrumbs)
    context.subscriptions.push(
        vscode.languages.registerDocumentSymbolProvider('euphoria', {
            async provideDocumentSymbols(document) {
                if (lspProcess) {
                    const res = await callRpc('textDocument/documentSymbol', {
                        textDocument: { uri: document.uri.toString() }
                    });

                    if (Array.isArray(res)) {
                        return res.map(sym => {
                            const kindMap = {
                                5: vscode.SymbolKind.Class,
                                6: vscode.SymbolKind.Method,
                                10: vscode.SymbolKind.Enum,
                                12: vscode.SymbolKind.Function,
                                13: vscode.SymbolKind.Variable,
                                14: vscode.SymbolKind.Constant
                            };
                            const range = new vscode.Range(
                                sym.range.start.line, sym.range.start.character,
                                sym.range.end.line, sym.range.end.character
                            );
                            const selRange = sym.selectionRange
                                ? new vscode.Range(
                                    sym.selectionRange.start.line, sym.selectionRange.start.character,
                                    sym.selectionRange.end.line, sym.selectionRange.end.character
                                ) : range;

                            return new vscode.DocumentSymbol(
                                sym.name,
                                sym.detail || '',
                                kindMap[sym.kind] || vscode.SymbolKind.Variable,
                                range,
                                selRange
                            );
                        });
                    }
                }

                // Fallback: Client-side regex symbol extractor for Editor Mode
                const text = document.getText();
                const lines = text.split(/\r?\n/);
                const symbols = [];
                const regex = /^\s*(public|export|global)?\s*(function|procedure|type|constant|enum)\s+([a-zA-Z0-9_]+)/i;

                for (let i = 0; i < lines.length; i++) {
                    const match = lines[i].match(regex);
                    if (match) {
                        const type = match[2].toLowerCase();
                        const name = match[3];
                        const kind = type === 'function' ? vscode.SymbolKind.Function
                            : type === 'procedure' ? vscode.SymbolKind.Method
                            : type === 'type' ? vscode.SymbolKind.Class
                            : type === 'constant' ? vscode.SymbolKind.Constant
                            : type === 'enum' ? vscode.SymbolKind.Enum : vscode.SymbolKind.Variable;

                        const range = new vscode.Range(i, 0, i, lines[i].length);
                        symbols.push(new vscode.DocumentSymbol(name, type, kind, range, range));
                    }
                }
                return symbols;
            }
        })
    );

    // Formatting Provider (Works in both LSP mode and client-side Editor Mode!)
    context.subscriptions.push(
        vscode.languages.registerDocumentFormattingEditProvider('euphoria', {
            async provideDocumentFormattingEdits(document, options, token) {
                if (lspProcess) {
                    const res = await callRpc('textDocument/formatting', {
                        textDocument: { uri: document.uri.toString() },
                        options: {
                            tabSize: options.tabSize,
                            insertSpaces: options.insertSpaces
                        }
                    });

                    if (Array.isArray(res) && res.length > 0) {
                        return res.map(e => new vscode.TextEdit(
                            new vscode.Range(
                                e.range.start.line, e.range.start.character,
                                e.range.end.line, e.range.end.character
                            ),
                            e.newText
                        ));
                    }
                }

                // Client-side fallback formatting (works 100% offline without Euphorix binary!)
                const formatted = localFormat(document.getText(), options);
                const fullRange = new vscode.Range(
                    0, 0,
                    document.lineCount, 0
                );
                return [new vscode.TextEdit(fullRange, formatted)];
            }
        })
    );
}

function deactivate() {
    if (statusBarItem) {
        statusBarItem.dispose();
    }
    if (lspProcess) {
        sendRpc('shutdown', null, msgId++);
        setTimeout(() => {
            if (lspProcess) {
                lspProcess.kill();
                lspProcess = null;
            }
        }, 500);
    }
}

module.exports = {
    activate,
    deactivate
};
