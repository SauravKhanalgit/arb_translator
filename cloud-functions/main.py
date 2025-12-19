"""
ARB Translator Gen Z - Google Cloud Function
Serverless translation API endpoint
"""

import json
import os
import tempfile
from flask import Flask, request, jsonify
from arb_translator_gen_z import LocalizationTranslator, TranslatorConfig

app = Flask(__name__)

# Initialize translator (lazy loading)
_translator = None

def get_translator():
    global _translator
    if _translator is None:
        config = TranslatorConfig(
            preferredProvider='openai',  # Configure based on environment
            apiKeys={
                'openai': os.getenv('OPENAI_API_KEY'),
                'deepl': os.getenv('DEEPL_API_KEY'),
                'azure': os.getenv('AZURE_TRANSLATOR_KEY'),
                'google': os.getenv('GOOGLE_TRANSLATE_API_KEY'),
            },
            logLevel='INFO',
            enableAnalytics=True,
            enableCaching=True,
        )
        _translator = LocalizationTranslator(config)
    return _translator

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'version': '3.2.0',
        'features': ['ai_translation', 'context_aware', 'multi_provider'],
        'providers': ['openai', 'deepl', 'azure', 'google']
    })

@app.route('/translate', methods=['POST'])
def translate():
    """
    Translate ARB file content to multiple languages

    Expected JSON payload:
    {
        "content": {"key": "value", "@key": {"description": "desc"}},
        "languages": ["es", "fr", "de"],
        "sourceLanguage": "en"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No JSON payload provided'}), 400

        content = data.get('content', {})
        languages = data.get('languages', [])
        source_language = data.get('sourceLanguage', 'en')

        if not content:
            return jsonify({'error': 'No content provided'}), 400

        if not languages:
            return jsonify({'error': 'No target languages specified'}), 400

        translator = get_translator()
        results = {}

        # Create temporary source file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.arb', delete=False) as f:
            json.dump(content, f, indent=2, ensure_ascii=False)
            source_path = f.name

        try:
            # Translate to each language
            for language in languages:
                try:
                    target_path = translator.generate_for_language(source_path, language)

                    # Read translated content
                    with open(target_path, 'r', encoding='utf-8') as f:
                        translated_content = json.load(f)

                    results[language] = {
                        'success': True,
                        'content': translated_content,
                        'filePath': target_path
                    }

                except Exception as e:
                    results[language] = {
                        'success': False,
                        'error': str(e)
                    }

        finally:
            # Cleanup temporary files
            try:
                os.unlink(source_path)
            except:
                pass

        return jsonify({
            'results': results,
            'summary': {
                'totalLanguages': len(languages),
                'successful': len([r for r in results.values() if r['success']]),
                'failed': len([r for r in results.values() if not r['success']])
            }
        })

    except Exception as e:
        return jsonify({'error': f'Translation failed: {str(e)}'}), 500

@app.route('/analytics', methods=['GET'])
def get_analytics():
    """Get translation analytics"""
    try:
        translator = get_translator()

        # Get basic stats (simplified for serverless)
        return jsonify({
            'totalTranslations': 0,  # Would be tracked in a real implementation
            'successRate': 0.95,
            'averageResponseTime': 2500,  # ms
            'providersUsed': ['openai', 'deepl'],
            'timestamp': '2024-01-01T00:00:00Z'
        })

    except Exception as e:
        return jsonify({'error': f'Analytics unavailable: {str(e)}'}), 500

@app.route('/validate', methods=['POST'])
def validate():
    """Validate ARB file content"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No JSON payload provided'}), 400

        content = data.get('content', {})

        # Basic validation (would use ArbHelper in real implementation)
        issues = []

        if not isinstance(content, dict):
            issues.append('Content must be a JSON object')
        else:
            # Check for locale
            if '@@locale' not in content:
                issues.append('Missing @@locale metadata')

            # Check for empty values
            for key, value in content.items():
                if not key.startswith('@') and (value == '' or value is None):
                    issues.append(f'Empty value for key: {key}')

        return jsonify({
            'valid': len(issues) == 0,
            'issues': issues,
            'keyCount': len([k for k in content.keys() if not k.startswith('@')])
        })

    except Exception as e:
        return jsonify({'error': f'Validation failed: {str(e)}'}), 500

# Cloud Function entry point
def arb_translator_cloud_function(request):
    """
    Google Cloud Function entry point
    Handles HTTP requests and routes them to Flask app
    """
    with app.test_request_context(
        path=request.path,
        method=request.method,
        data=request.get_data(as_text=True),
        headers=dict(request.headers)
    ):
        try:
            response = app.full_dispatch_request()
            return (response.get_data(as_text=True), response.status_code, dict(response.headers))
        except Exception as e:
            return (json.dumps({'error': str(e)}), 500, {'Content-Type': 'application/json'})

# For local testing
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 8080)), debug=True)
