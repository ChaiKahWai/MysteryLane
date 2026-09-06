import fs from 'node:fs';
import assert from 'node:assert/strict';
const dir = new URL('./', import.meta.url);
const read = name => fs.readFileSync(new URL(name, dir), 'utf8');
const snapshot = JSON.parse(read('google-pool-snapshot.json'));
const lines = name => read(name).trim().split(/\r?\n/).map(line => line.split('|'));
const locations = lines('google-pool-starter-locations.txt');
const facts = lines('google-pool-starter-facts.txt');
locations.forEach(x => assert.equal(x.length, 8));
facts.forEach(x => assert.equal(x.length, 9));
const known = new Set(snapshot.destinations.map(d => d.name));
for (const row of [...locations, ...facts]) assert(known.has(row[0]), `Unknown destination ${row[0]}`);
const result = snapshot.destinations.map(d => {
  const saved = snapshot.existing_questions.filter(q => q.destination_id === d.destination_id);
  assert.equal(saved.length, d.saved_mcq, `Snapshot mismatch: ${d.name}`);
  const base = [...locations.filter(x => x[0] === d.name), ...facts.filter(x => x[0] === d.name)];
  const drafts = base.map((x, i) => {
    const [name, question, answer, a, b, c, hint1, hint2, source = 'DB'] = x;
    assert(question.endsWith('?'), question);
    assert.equal(new Set([answer, a, b, c]).size, 4, question);
    assert(x.every(Boolean), question);
    const options = [answer, a, b, c];
    const offset = i % 4;
    return { destination_id: d.destination_id, question_text: question,
      options: [...options.slice(offset), ...options.slice(0, offset)],
      correct_answer: answer, hint_1: hint1, hint_2: hint2,
      hint_3: `The correct answer is ${answer}.`,
      evidence_type: source === 'DB' ? 'Saved GOOGLE destination record' : 'Web source',
      source: source === 'DB' ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(d.name)}&query_place_id=${encodeURIComponent(d.google_place_id)}` : source,
      status: 'Draft — not inserted' };
  });
  const keys = [...saved.map(q => q.question_text), ...drafts.map(q => q.question_text)].map(q => q.toLowerCase().trim());
  assert.equal(new Set(keys).size, keys.length, `Duplicate question: ${d.name}`);
  assert(saved.length + drafts.length > 0, `Uncovered destination: ${d.name}`);
  return { ...d, saved, drafts, total: saved.length + drafts.length };
});
assert.equal(result.length, 62);
console.log(JSON.stringify(process.argv.includes('--drafts') ? result.map(({saved, ...d}) => d) : result));
