import assert from 'node:assert/strict';

let handler;
globalThis.Deno = {
  env: { get: (name) => ({ SUPABASE_URL: 'https://test.invalid', SUPABASE_ANON_KEY: 'test-anon', SUPABASE_SERVICE_ROLE_KEY: 'test-service', GEMINI_PUZZLE_QUESTION_API: 'test-puzzle' })[name] },
  serve: (fn) => { handler = fn; },
};
await import('../supabase/functions/generate-destination-questions/index.ts');
let failResearch = false;
let ownsDestination = true;
let hasTextModel = true;
let destinationName = 'Test Tower';
let puzzleType = 'Multiple Choice Question';
let batch = 0;
let writes = [];
let batchSize = 10;
let timeoutsRemaining = 0;
let generationCalls = 0;
let existingBank = [];
let batchesBeforeFailure = Infinity;
const reply = (data, status = 200) => new Response(JSON.stringify(data), { status });
globalThis.fetch = async (url, options = {}) => {
  const body = options.body ? JSON.parse(options.body) : null;
  if (url.includes('/auth/v1/user')) return reply({ id: 'owner' });
  if (url.includes('/blind_box_history?')) return reply(ownsDestination ? [{ history_id: 'draw' }] : []);
  if (url.includes('/blind_box_destinations?')) return reply([{ name: destinationName, category: 'landmark' }]);
  if (url.includes('en.wikipedia.org')) {
    if (url.includes('list=search')) return reply({ query: { search: [{ title: destinationName, pageid: 123 }] } });
    return reply({ query: { pages: { 123: { title: destinationName, extract: 'Researched facts. '.repeat(60) } } } });
  }
  if (url.includes('generativelanguage')) {
    assert.equal(options.headers['x-goog-api-key'], 'test-puzzle');
    if (url.includes('/models?')) {
      return reply({ models: [
        { name: 'models/gemini-9.0-flash-image', supportedGenerationMethods: ['generateContent'] },
        ...(hasTextModel ? ['models/gemini-2.5-flash','models/gemini-3.5-flash-lite'].map(name => ({ name, supportedGenerationMethods: ['generateContent'] })) : []),
      ] });
    }
    assert.ok(url.includes(body.tools ? '/models/gemini-2.5-flash:generateContent' : '/models/gemini-3.5-flash-lite:generateContent'));
    assert.equal(body.tools, undefined, 'Paid/blocked Gemini Search must not be used');
    generationCalls++;
    assert.equal(body.generationConfig.responseSchema.properties.questions.maxItems, 10);
    if (timeoutsRemaining-- > 0) throw new DOMException('Timed out', 'TimeoutError');
    if (failResearch) return reply({ error: 'quota' }, 429);
    if (batchesBeforeFailure-- <= 0) return reply({ error: 'quota' }, 429);
    if (body.tools) {
      assert.equal(body.generationConfig.responseSchema, undefined);
      if (failResearch) return reply({ error: 'quota' }, 429);
      return reply({ candidates: [{ content: { parts: [{ text: 'Researched facts with source URLs.' }] } }] });
    }
    assert.ok(body.generationConfig.responseSchema);
    assert.ok(body.contents[0].parts[0].text.includes('Researched facts'));
    const questions = Array.from({ length: batchSize }, (_, i) => ({
      question: `How many units are in tower feature ${batch * 25 + i}?`,
      options: ['10', '20', '30', '40'], correct_answer: '10', hint_1: 'Hint', hint_2: 'Hint two', difficulty: 'EASY',
    }));
    if (puzzleType === 'True or False') questions.forEach(q => { q.options = ['True','False']; q.correct_answer = 'True'; });
    if (['Scrambled Word', 'Guess the Word'].includes(puzzleType)) questions.forEach((q,i) => { q.options = []; q.correct_answer = 'WORD' + String.fromCharCode(65+batch,65+i); });
    batch++;
    questions.push({ ...questions[0], question: 'Which destination is at this address?', correct_answer: '10' });
    questions.push({ ...questions[0], question: 'What is the destination name?', options: [destinationName, 'A', 'B', 'C'], correct_answer: destinationName });
    return reply({ candidates: [{ content: { parts: [{ text: JSON.stringify({ questions }) }] } }] });
  }
  if (options.method === 'POST' || options.method === 'PATCH' || options.method === 'DELETE') {
    writes.push({ method: options.method, body });
    return new Response(null, { status: 204 });
  }
  return reply([{ question_text: 'Mystery clue 1: Which address?' }, ...existingBank,
    ...writes.filter(write => write.method === 'POST').flatMap(write => write.body)]);
};
const request = () => new Request('https://test.invalid', { method: 'POST', headers: { Authorization: 'Bearer test' }, body: JSON.stringify({ destination_id: 'destination', puzzle_type: puzzleType }) });
let result = await handler(request());
assert.equal(result.status, 200);
assert.equal(writes[0].body.length, 10);
assert.equal(generationCalls, 1);
assert.equal(writes[1].method, 'PATCH');
assert.deepEqual(writes[1].body, { is_active: false });
assert.ok(writes.every((write) => write.method !== 'DELETE'));
for (const type of ['True or False', 'Scrambled Word', 'Guess the Word']) {
  puzzleType = type;
  writes = [];
  result = await handler(request());
  assert.equal(result.status, 200);
  assert.equal(writes[0].body.length, 10);
  assert.ok(writes[0].body.every(q => q.puzzle_type === type && q.destination_id === 'destination'));
  if (type === 'Scrambled Word') assert.ok(writes[0].body.every(q => q.question_text.split('Unscramble: ')[1].split('').sort().join('') === q.correct_answer.split('').sort().join('')));
}
puzzleType = 'Image Guessing';
writes = [];
result = await handler(request());
assert.equal(result.status, 422);
assert.equal(writes.length, 0);
puzzleType = 'Multiple Choice Question';
writes = [];
batchSize = 10;
result = await handler(request());
assert.equal(result.status, 200);
assert.equal(writes[0].body.length, 10);
assert.equal((await result.json()).bank_complete, false);
writes = [];
batchSize = 8;
result = await handler(request());
assert.equal(result.status, 422);
assert.equal(writes[0].body.length, 8, 'Keep fewer-than-ten valid questions');
existingBank = writes[0].body;
writes = [];
batchSize = 10;
result = await handler(request());
assert.equal(result.status, 200);
assert.equal((await result.json()).available, 18, 'Saved partial banks accumulate');
existingBank = [...existingBank, ...writes[0].body];
writes = [];
const callsBeforeReuse = generationCalls;
result = await handler(request());
assert.equal(result.status, 200);
assert.equal(generationCalls, callsBeforeReuse, 'Playable banks skip generation');
existingBank = [];
writes = [];
batchSize = 10;
batchesBeforeFailure = 1;
result = await handler(request());
assert.equal(result.status, 200, 'A later quota error must not discard a playable batch');
assert.equal(writes[0].body.length, 10);
writes = [];
batchesBeforeFailure = Infinity;
timeoutsRemaining = 1;
result = await handler(request());
assert.equal(result.status, 200, 'One timeout gets one retry');
assert.equal(writes[0].body.length, 10);
writes = [];
timeoutsRemaining = 2;
const callsBeforeTimeout = generationCalls;
result = await handler(request());
assert.equal(result.status, 504);
assert.equal((await result.json()).code, 'PUZZLE_GENERATION_TIMEOUT');
assert.equal(generationCalls - callsBeforeTimeout, 2, 'Retry is bounded');
assert.equal(writes.length, 0);
timeoutsRemaining = 0;
failResearch = true;
result = await handler(request());
assert.equal(result.status, 429);
assert.equal((await result.json()).code, 'PUZZLE_PROVIDER_QUOTA');
assert.equal(writes.length, 0);
failResearch = false;
hasTextModel = false;
result = await handler(request());
assert.equal(result.status, 502);
assert.match((await result.json()).error, /no compatible Flash/);
assert.equal(writes.length, 0);
destinationName = 'Merdeka 118 Precinct';
result = await handler(request());
assert.equal(result.status, 200);
assert.equal(writes[0].body.length, 20);
assert.equal(new Set(writes[0].body.map(q => q.question_text)).size, 20);
assert.ok(writes[0].body.every(q => q.correct_answer !== destinationName && q.question_text.endsWith('?')));
writes = [];
ownsDestination = false;
result = await handler(request());
assert.equal(result.status, 403);
assert.equal(writes.length, 0);
console.log('Passed: ten-question first batch, saved partials, reuse, bounded timeout retry, category validation, quota failure and ownership guard.');
