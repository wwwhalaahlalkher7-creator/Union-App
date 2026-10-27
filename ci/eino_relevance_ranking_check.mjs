import assert from 'node:assert/strict';
import { expandEinoSearchTerm, normalizeEinoSearchText, rankStudentMaterialChunks } from '../services/api/src/eino.js';

assert.equal(normalizeEinoSearchText('إلكترونيات  وَالطّاقة'), 'الكترونيات والطاقة');
assert.ok(expandEinoSearchTerm('بالجهد').includes('جهد'), 'Arabic conjunction/preposition/article variants should be expanded conservatively');
const rows = [
  { materialId: 'a', chunkIndex: 0, title: 'رياضيات', subjectName: 'رياضيات هندسية', content: 'المعادلات التفاضلية وتطبيقاتها في الهندسة الكهربائية.' },
  { materialId: 'b', chunkIndex: 2, title: 'دوائر كهربائية', subjectName: 'هندسة كهربائية', content: 'قانون أوم يربط الجهد والتيار والمقاومة في الدائرة الكهربائية.' },
  { materialId: 'c', chunkIndex: 1, title: 'مقدمة عامة', subjectName: 'علوم عامة', content: 'هذا النص لا يحتوي على موضوع الجهد والتيار أو المقاومة.' },
];
const ranked = rankStudentMaterialChunks(rows, 'قانون أوم الجهد والتيار والمقاومة');
assert.equal(ranked[0].materialId, 'b', 'the most relevant electrical-circuits chunk should rank first');
assert.ok(ranked.length <= 4);
assert.ok(ranked.every((row) => !('_score' in row) && !('_coverage' in row)));
assert.deepEqual(rankStudentMaterialChunks(rows, 'من في على هل'), [], 'stopword-only queries must not return arbitrary chunks');
assert.deepEqual(rankStudentMaterialChunks(rows, 'quantum entanglement'), [], 'irrelevant queries must return no chunks');
const duplicates = [rows[1], { ...rows[1] }];
assert.equal(rankStudentMaterialChunks(duplicates, 'قانون أوم الجهد').length, 1, 'duplicate material/chunk pairs must be removed');

const rarityRows = [
  { materialId: 'common', chunkIndex: 0, title: 'مقدمة', subjectName: 'هندسة', content: 'الجهد مهم في الدائرة والجهد يتغير والجهد يؤثر في التيار.' },
  { materialId: 'specific', chunkIndex: 1, title: 'قانون أوم', subjectName: 'دوائر كهربائية', content: 'الجهد والتيار والمقاومة يربطها قانون أوم.' },
];
assert.equal(rankStudentMaterialChunks(rarityRows, 'الجهد قانون أوم')[0].materialId, 'specific', 'distinctive query terms and title matches should outrank repeated generic terms');
const titleRows = [
  { materialId: 'title', chunkIndex: 0, title: 'تحليل فورييه', subjectName: 'رياضيات', content: 'مقدمة عن التحليل الرياضي.' },
  { materialId: 'body', chunkIndex: 0, title: 'مقدمة', subjectName: 'رياضيات', content: 'تحليل فورييه يستخدم لتحليل الإشارات الدورية.' },
];
assert.equal(rankStudentMaterialChunks(titleRows, 'فورييه')[0].materialId, 'title', 'matching material titles should receive a relevance boost');
console.log('Eino relevance ranking checks passed.');

const morphologyRows = [
  { materialId: 'morphology', chunkIndex: 0, title: 'الجهد الكهربائي', subjectName: 'دوائر', content: 'جهد المصدر يحدد فرق الجهد في الدائرة.' },
  { materialId: 'other', chunkIndex: 0, title: 'مقدمة', subjectName: 'رياضيات', content: 'المعادلات التفاضلية وتطبيقاتها.' },
];
assert.equal(rankStudentMaterialChunks(morphologyRows, 'بالجهد الكهربائي')[0].materialId, 'morphology', 'Arabic clitic/article variations should match the underlying term');

const lowSignalRows = [
  { materialId: 'strong', chunkIndex: 0, title: 'قانون أوم', subjectName: 'دوائر كهربائية', content: 'قانون أوم يربط الجهد والتيار والمقاومة.' },
  { materialId: 'weak', chunkIndex: 4, title: 'مقدمة', subjectName: 'علوم عامة', content: 'الجهد قد يظهر في سياقات كثيرة.' },
];
assert.equal(rankStudentMaterialChunks(lowSignalRows, 'قانون أوم الجهد')[0].materialId, 'strong', 'high-confidence source should stay first');
assert.ok(!rankStudentMaterialChunks(lowSignalRows, 'قانون أوم الجهد').some((row) => row.materialId === 'weak'), 'weakly matching chunks should be filtered when stronger evidence exists');
