from pathlib import Path
root = Path(__file__).resolve().parents[1]
index = '\n'.join(p.read_text() for p in (root / 'backend/src').rglob('*.js'))
registry = (root / 'backend/src/providers/registry.js').read_text()
workflow_path = root / '.github/workflows/release.yml'
workflow = workflow_path.read_text(encoding='utf-8') if workflow_path.exists() else ''
wrangler = (root / 'backend/wrangler.toml').read_text()
provider_file = root / 'backend/src/providers/omniroute.js'
checks = {
    'omniroute adapter removed': not provider_file.exists(),
    'no omniroute runtime references': 'OMNIROUTE' not in index and 'omniroute' not in index.lower(),
    'capability registry exists': 'EINO_CAPABILITIES' in registry and 'getProvidersForCapability' in registry,
    'text uses registry': 'getProvidersForCapability(ctx.env, EINO_CAPABILITIES.TEXT)' in index,
    'media uses capability registry': all(x in index for x in [
        'EINO_CAPABILITIES.VISION', 'EINO_CAPABILITIES.OCR',
        'EINO_CAPABILITIES.STT', 'EINO_CAPABILITIES.TTS'
    ]),
    'release workflow exists': bool(workflow),
    'no omniroute workflow references': 'OMNIROUTE' not in workflow and 'OmniRoute' not in workflow,
    'no omniroute wrangler references': 'OMNIROUTE' not in wrangler and 'OmniRoute' not in wrangler,
    'text model is explicit': 'EINO_TEXT_MODEL' in wrangler,
    'embedding provider is separate': 'EINO_EMBEDDING_BASE_URL' in index and 'EINO_EMBEDDING_MODEL' in index,
}
for k, v in checks.items(): print(('PASS' if v else 'FAIL'), k)
if not all(checks.values()): raise SystemExit(1)
print('EINO PROVIDER CHECK PASSED')
