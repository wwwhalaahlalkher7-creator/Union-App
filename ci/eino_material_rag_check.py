from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
eino = (ROOT / 'backend/src/eino.js').read_text(encoding='utf-8')
repo = (ROOT / 'flutter/lib/data/repositories/eino_repository.dart').read_text(encoding='utf-8')

checks = {
    'material task retrieval': 'retrieveEinoMaterial(ctx, session, query)' in eino,
    'student department isolation': 's.department_id = ?' in eino and 'session.department_id' in eino,
    'registered semester isolation': 'session.current_semester_id' in eino and 's.semester_id = ?' in eino,
    'drive file retrieval': 'https://drive.google.com/uc?export=download&id=' in eino,
    'file size guard': '20 * 1024 * 1024' in eino,
    'specialist file route': 'routeFileAnalysis(ctx.env' in eino,
    'material grounded response': "capability: 'material-rag'" in eino and "type: 'student-material'" in eino,
    'material source metadata': 'materialId: materialGrounding.materialId' in eino,
    'flutter source model': 'class EinoSource' in repo,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS ' if ok else 'FAIL ') + name)
if failed:
    raise SystemExit('EINO MATERIAL RAG CHECK FAILED: ' + ', '.join(failed))
print('EINO MATERIAL RAG CHECK PASSED')
