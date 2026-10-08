import fs from 'node:fs';
const core = fs.readFileSync(new URL('../backend/src/core.js', import.meta.url), 'utf8');
const eino = fs.readFileSync(new URL('../backend/src/eino.js', import.meta.url), 'utf8');
const required = [
  ['EINO_WINDOW_LIMIT', '8'],
  ['EINO_STUDENT_DAILY_LIMIT_DEFAULT', '50'],
  ['EINO_GUEST_DAILY_LIMIT_DEFAULT', '10'],
  ['EINO_GLOBAL_DAILY_LIMIT_DEFAULT', '1000'],
];
for (const [name, value] of required) {
  if (!core.includes(`export const ${name} = ${value};`)) throw new Error(`missing quota ${name}`);
}
for (const needle of [
  'case \'image-generation\': return 5;',
  'case \'file-analysis\': return 4;',
  'case EINO_CAPABILITIES.VISION: return 3;',
  'case EINO_CAPABILITIES.STT: return 2;',
  'case EINO_CAPABILITIES.TTS: return 2;',
  'case \'long-summary\': return 4;',
  'consumeEinoQuota(ctx, actorKey, einoTaskCost(task))',
  'WHERE request_count + ? <= ?',
]) if (!eino.includes(needle)) throw new Error(`missing weighted quota rule: ${needle}`);
console.log('EINO QUOTA POLICY CHECK PASSED');
