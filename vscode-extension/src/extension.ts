import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { spawn } from 'child_process';

let outputChannel: vscode.OutputChannel;
let diagnosticCollection: vscode.DiagnosticCollection;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('ARB Translator');
    diagnosticCollection = vscode.languages.createDiagnosticCollection('arb');

    context.subscriptions.push(
        outputChannel,
        diagnosticCollection,
        vscode.commands.registerCommand('arbTranslator.translate', translateFile),
        vscode.commands.registerCommand('arbTranslator.validate', validateFile),
        vscode.commands.registerCommand('arbTranslator.analyze', analyzeProject),
        vscode.commands.registerCommand('arbTranslator.showDashboard', showDashboard)
    );

    // Register real-time validation for ARB files
    const config = vscode.workspace.getConfiguration('arbTranslator');
    if (config.get('enableRealTimeValidation', true)) {
        setupRealTimeValidation(context);
    }

    outputChannel.appendLine('🎉 ARB Translator Gen Z extension activated!');
    outputChannel.appendLine('🚀 Features: AI translation, validation, analytics');
    vscode.window.showInformationMessage('ARB Translator Gen Z is now active!');
}

export function deactivate() {
    outputChannel.dispose();
    diagnosticCollection.dispose();
}

async function translateFile(uri?: vscode.Uri) {
    const fileUri = uri || vscode.window.activeTextEditor?.document.uri;

    if (!fileUri) {
        vscode.window.showErrorMessage('No ARB file selected');
        return;
    }

    if (!fileUri.fsPath.endsWith('.arb')) {
        vscode.window.showErrorMessage('Selected file is not an ARB file');
        return;
    }

    try {
        const config = vscode.workspace.getConfiguration('arbTranslator');
        const targetLanguages = config.get('targetLanguages', ['es', 'fr', 'de']) as string[];
        const cliPath = config.get('cliPath', 'arb_translator') as string;

        // Show language selection
        const selectedLanguages = await vscode.window.showQuickPick(
            targetLanguages.map(lang => ({
                label: lang,
                description: getLanguageName(lang),
                picked: true
            })),
            {
                canPickMany: true,
                placeHolder: 'Select target languages'
            }
        );

        if (!selectedLanguages || selectedLanguages.length === 0) {
            return;
        }

        const languages = selectedLanguages.map(item => item.label);

        outputChannel.appendLine(`🌐 Translating ${path.basename(fileUri.fsPath)} to: ${languages.join(', ')}`);

        // Show progress
        await vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'Translating ARB file...',
            cancellable: true
        }, async (progress, token) => {
            progress.report({ increment: 0, message: 'Starting translation...' });

            const result = await runCliCommand(cliPath, [
                '-s', fileUri.fsPath,
                '-l', languages.join(',')
            ], token);

            if (result.success) {
                progress.report({ increment: 100, message: 'Translation completed!' });
                vscode.window.showInformationMessage(
                    `ARB file translated successfully to ${languages.length} languages!`
                );

                // Refresh file explorer
                vscode.commands.executeCommand('workbench.files.action.refreshFilesExplorer');
            } else {
                throw new Error(result.error);
            }
        });

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        vscode.window.showErrorMessage(`Translation failed: ${message}`);
        outputChannel.appendLine(`❌ Translation error: ${message}`);
    }
}

async function validateFile(uri?: vscode.Uri) {
    const fileUri = uri || vscode.window.activeTextEditor?.document.uri;

    if (!fileUri) {
        vscode.window.showErrorMessage('No ARB file selected');
        return;
    }

    if (!fileUri.fsPath.endsWith('.arb')) {
        vscode.window.showErrorMessage('Selected file is not an ARB file');
        return;
    }

    try {
        const config = vscode.workspace.getConfiguration('arbTranslator');
        const cliPath = config.get('cliPath', 'arb_translator') as string;

        outputChannel.appendLine(`🔍 Validating ${path.basename(fileUri.fsPath)}`);

        const result = await runCliCommand(cliPath, [
            '-s', fileUri.fsPath,
            '--validate-only'
        ]);

        if (result.success) {
            // Parse validation output
            const lines = result.output.split('\n');
            const issues: string[] = [];

            for (const line of lines) {
                if (line.includes('❌') || line.includes('issues') || line.includes('missing')) {
                    issues.push(line);
                }
            }

            if (issues.length === 0) {
                vscode.window.showInformationMessage('✅ ARB file is valid!');
                outputChannel.appendLine('✅ Validation passed');
            } else {
                // Show issues in a new document
                const doc = await vscode.workspace.openTextDocument({
                    content: issues.join('\n'),
                    language: 'plaintext'
                });
                await vscode.window.showTextDocument(doc, { preview: false });
                outputChannel.appendLine(`⚠️  Validation found ${issues.length} issues`);
            }
        } else {
            throw new Error(result.error);
        }

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        vscode.window.showErrorMessage(`Validation failed: ${message}`);
        outputChannel.appendLine(`❌ Validation error: ${message}`);
    }
}

async function analyzeProject() {
    try {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No workspace folder open');
            return;
        }

        const config = vscode.workspace.getConfiguration('arbTranslator');
        const cliPath = config.get('cliPath', 'arb_translator') as string;

        // Find ARB files in workspace
        const arbPattern = new vscode.RelativePattern(workspaceFolder, '**/*.arb');
        const arbFiles = await vscode.workspace.findFiles(arbPattern, '**/node_modules/**');

        if (arbFiles.length === 0) {
            vscode.window.showInformationMessage('No ARB files found in workspace');
            return;
        }

        // Find l10n directory
        const l10nPattern = new vscode.RelativePattern(workspaceFolder, 'lib/l10n');
        const l10nDirs = await vscode.workspace.findFiles(l10nPattern, null, 1);

        const l10nPath = l10nDirs.length > 0 ? 'lib/l10n' : '.';

        outputChannel.appendLine(`🔍 Analyzing ARB files in ${l10nPath}`);

        const result = await runCliCommand(cliPath, [
            '--analyze',
            '-s', path.join(workspaceFolder.uri.fsPath, l10nPath)
        ]);

        if (result.success) {
            // Show analysis in output channel
            outputChannel.show();
            outputChannel.appendLine('📊 Analysis Results:');
            outputChannel.appendLine(result.output);

            // Parse for issues
            const lines = result.output.split('\n');
            const issues = lines.filter(line =>
                line.includes('❌') || line.includes('missing') || line.includes('issues')
            );

            if (issues.length > 0) {
                const message = `${issues.length} issues found. Check output for details.`;
                vscode.window.showWarningMessage(message);
            } else {
                vscode.window.showInformationMessage('✅ All ARB files are valid and complete!');
            }
        } else {
            throw new Error(result.error);
        }

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        vscode.window.showErrorMessage(`Analysis failed: ${message}`);
        outputChannel.appendLine(`❌ Analysis error: ${message}`);
    }
}

async function showDashboard() {
    try {
        const config = vscode.workspace.getConfiguration('arbTranslator');
        const cliPath = config.get('cliPath', 'arb_translator') as string;

        outputChannel.appendLine('📊 Loading analytics dashboard...');

        const result = await runCliCommand(cliPath, ['--analytics']);

        if (result.success) {
            // Create a new document with the dashboard
            const doc = await vscode.workspace.openTextDocument({
                content: result.output,
                language: 'plaintext'
            });

            await vscode.window.showTextDocument(doc, {
                viewColumn: vscode.ViewColumn.Beside,
                preview: false
            });

            outputChannel.appendLine('📈 Analytics dashboard displayed');
        } else {
            throw new Error(result.error);
        }

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        vscode.window.showErrorMessage(`Dashboard failed: ${message}`);
        outputChannel.appendLine(`❌ Dashboard error: ${message}`);
    }
}

function setupRealTimeValidation(context: vscode.ExtensionContext) {
    // Watch for ARB file changes
    const watcher = vscode.workspace.createFileSystemWatcher('**/*.arb');

    watcher.onDidChange(uri => validateArbFile(uri));
    watcher.onDidCreate(uri => validateArbFile(uri));
    watcher.onDidDelete(uri => {
        // Clear diagnostics for deleted files
        diagnosticCollection.delete(uri);
    });

    context.subscriptions.push(watcher);

    // Validate currently open ARB files
    vscode.workspace.textDocuments
        .filter(doc => doc.languageId === 'json' && doc.fileName.endsWith('.arb'))
        .forEach(doc => validateArbFile(doc.uri));
}

async function validateArbFile(uri: vscode.Uri) {
    try {
        const content = await vscode.workspace.fs.readFile(uri);
        const text = Buffer.from(content).toString('utf-8');

        // Basic JSON validation
        try {
            JSON.parse(text);
        } catch (e) {
            const diagnostic = new vscode.Diagnostic(
                new vscode.Range(0, 0, 0, 1),
                'Invalid JSON format',
                vscode.DiagnosticSeverity.Error
            );
            diagnosticCollection.set(uri, [diagnostic]);
            return;
        }

        // ARB-specific validation
        const json = JSON.parse(text);
        const diagnostics: vscode.Diagnostic[] = [];

        // Check for @@locale
        if (!json['@@locale']) {
            diagnostics.push(new vscode.Diagnostic(
                new vscode.Range(0, 0, 0, 1),
                'Missing @@locale metadata',
                vscode.DiagnosticSeverity.Warning
            ));
        }

        // Check for empty values
        let line = 0;
        const lines = text.split('\n');
        for (const [key, value] of Object.entries(json)) {
            if (key.startsWith('@')) continue;

            if (value === '' || (typeof value === 'string' && value.trim() === '')) {
                // Find the line with this key
                const keyLine = lines.findIndex(l => l.includes(`"${key}"`));
                if (keyLine !== -1) {
                    diagnostics.push(new vscode.Diagnostic(
                        new vscode.Range(keyLine, 0, keyLine, lines[keyLine].length),
                        `Empty translation for key "${key}"`,
                        vscode.DiagnosticSeverity.Warning
                    ));
                }
            }
        }

        diagnosticCollection.set(uri, diagnostics);

    } catch (error) {
        outputChannel.appendLine(`Error validating ${uri.fsPath}: ${error}`);
    }
}

async function runCliCommand(
    command: string,
    args: string[],
    cancellationToken?: vscode.CancellationToken
): Promise<{ success: boolean; output: string; error: string }> {
    return new Promise((resolve) => {
        const process = spawn(command, args, {
            cwd: vscode.workspace.workspaceFolders?.[0]?.uri.fsPath
        });

        let stdout = '';
        let stderr = '';

        process.stdout.on('data', (data) => {
            const output = data.toString();
            stdout += output;
            outputChannel.append(output);
        });

        process.stderr.on('data', (data) => {
            const output = data.toString();
            stderr += output;
            outputChannel.append(output);
        });

        process.on('close', (code) => {
            resolve({
                success: code === 0,
                output: stdout,
                error: stderr
            });
        });

        process.on('error', (error) => {
            resolve({
                success: false,
                output: stdout,
                error: error.message
            });
        });

        // Handle cancellation
        cancellationToken?.onCancellationRequested(() => {
            process.kill();
            resolve({
                success: false,
                output: stdout,
                error: 'Cancelled by user'
            });
        });
    });
}

function getLanguageName(code: string): string {
    const languages: { [key: string]: string } = {
        'en': 'English',
        'es': 'Spanish',
        'fr': 'French',
        'de': 'German',
        'it': 'Italian',
        'pt': 'Portuguese',
        'ru': 'Russian',
        'ja': 'Japanese',
        'ko': 'Korean',
        'zh': 'Chinese',
        'ar': 'Arabic',
        'hi': 'Hindi',
        'nl': 'Dutch',
        'sv': 'Swedish',
        'da': 'Danish',
        'no': 'Norwegian',
        'fi': 'Finnish',
        'pl': 'Polish',
        'tr': 'Turkish',
        'cs': 'Czech',
        'hu': 'Hungarian',
        'th': 'Thai',
        'vi': 'Vietnamese',
        'he': 'Hebrew',
        'el': 'Greek'
    };

    return languages[code] || code.toUpperCase();
}
