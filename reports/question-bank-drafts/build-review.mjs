import fs from 'node:fs';
import assert from 'node:assert/strict';
const path = new URL('./zoo-negara-50.txt', import.meta.url);
const rows = fs.readFileSync(path, 'utf8').trim().split(/\r?\n/).map((line, i) => {
  const fields = line.split('|');
  assert.equal(fields.length, 8, `Fields in question ${i + 1}`);
  const [question, answer, ...rest] = fields;
  const distractors = rest.slice(0, 3);
  const options = [answer, ...distractors];
  assert.equal(new Set(options).size, 4, `Distinct options ${i + 1}`);
  assert(question.endsWith('?'), `Question punctuation ${i + 1}`);
  assert(fields.every(Boolean), `Missing field ${i + 1}`);
  // Rotate answer position; source facts and authored hints remain unchanged.
  const offset = i % 4;
  const rotated = [...options.slice(offset), ...options.slice(0, offset)];
  return { question, options: rotated, correct_answer: answer,
    hint_1: fields[5], hint_2: fields[6], hint_3: `The correct answer is ${answer}.`,
    source: `https://www.zoonegara.my/${fields[7]}` };
});
assert.equal(rows.length, 50);
assert.equal(new Set(rows.map(r => r.question.toLowerCase())).size, 50);
console.log('PASS: 50 unique questions, four distinct options, three hints, and source links. Content still requires editorial review; no database writes.');
if (process.argv.includes('--json')) console.log(JSON.stringify(rows));
