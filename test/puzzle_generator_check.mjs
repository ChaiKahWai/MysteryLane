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
let randomMode = false;
let excludedIds = [];
let referenceAvailable = true;
let existingBank = [];
let batchesBeforeFailure = Infinity;
let overloaded = false;
let usedModels = [];
let leaseHeld = false;
let claimedCategories = [];
const reply = (data, status = 200) => new Response(JSON.stringify(data), { status });
globalThis.fetch = async (url, options = {}) => {
  const body = options.body ? JSON.parse(options.body) : null;
  if (url.includes('/rpc/claim_puzzle_preparation')) {
    claimedCategories.push(body.p_puzzle_type);
    return reply(!leaseHeld);
  }
  if (url.includes('/puzzle_preparation_leases?')) return new Response(null, { status: 204 });
  if (url.includes('/auth/v1/user')) return reply({ id: 'owner' });
  if (url.includes('/blind_box_history?')) return reply(ownsDestination ? [{ history_id: 'draw' }] : []);
  if (url.includes('/blind_box_destinations?')) return reply([{ name: destinationName, category: 'landmark', destination_source: 'GOOGLE', google_place_id: 'test-place', address: 'Kuala Lumpur, Malaysia' }]);
  if (url.includes('select=destination_id&')) return reply([{ destination_id: 'server-chosen' }]);
  if (url.includes('en.wikipedia.org')) {
    if (!referenceAvailable) return reply({ query: { search: [], pages: { '-1': { missing: '' } } } });
    if (url.includes('list=search')) return reply({ query: { search: [{ title: destinationName, pageid: 123 }] } });
    return reply({ query: { pages: { 123: { title: destinationName, extract: 'Researched facts. '.repeat(60) } } } });
  }
  if (url.includes('generativelanguage')) {
    assert.equal(options.headers['x-goog-api-key'], 'test-puzzle');
    if (url.includes('/models?')) {
      return reply({ models: [
        { name: 'models/gemini-9.0-flash-image', supportedGenerationMethods: ['generateContent'] },
        ...(hasTextModel ? ['models/gemini-2.5-flash','models/gemini-2.5-flash-lite','models/gemini-3.5-flash','models/gemini-3.5-flash-lite','models/gemini-flash-lite-latest'].map(name => ({ name, supportedGenerationMethods: ['generateContent'] })) : []),
      ] });
    }
    assert.ok(/\/models\/gemini-3.5-flash(?:-lite)?:generateContent/.test(url));
    usedModels.push(url);
    assert.equal(body.tools, undefined, 'Paid/blocked Gemini Search must not be used');
    generationCalls++;
    if (overloaded && url.includes('3.5-flash-lite')) return reply({ error: { status: 'UNAVAILABLE' } }, 503);
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
    assert.ok(body.contents[0].parts[0].text.includes(referenceAvailable ? 'Researched facts' : 'No additional reference was retrieved'));
    const questions = Array.from({ length: batchSize }, (_, i) => ({
      question: `How many units are in tower feature ${batch * 25 + i}?`,
      options: ['10', '20', '30', '40'], correct_answer: '10', hint_1: 'Hint', hint_2: 'Hint two', difficulty: 'EASY',
    }));
    if (puzzleType === 'True or False') questions.forEach(q => { q.options = ['True','False']; q.correct_answer = 'True'; q.box_content = 'A supported proposed answer'; });
    questions.forEach(q => { if (q.box_content === undefined) q.box_content = ''; });
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
const request = () => new Request('https://test.invalid', { method: 'POST', headers: { Authorization: 'Bearer test' }, body: JSON.stringify({ destination_id: 'destination', puzzle_type: puzzleType, random_mode: randomMode, exclude_question_ids: excludedIds }) });
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
batchesBeforeFailure = 1;
result = await handler(request());
assert.equal(result.status, 422);
assert.equal(writes[0].body.length, 8, 'Keep fewer-than-ten valid questions');
existingBank = writes[0].body;
batchesBeforeFailure = Infinity;
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
hasTextModel = true;
destinationName = 'Test Tower';
randomMode = true;
result = await handler(request());
assert.equal(result.status, 200, 'Random mode works without a draw');
assert.ok(writes[0].body.every(q => q.destination_id === 'server-chosen'), 'Client cannot pick an unowned destination via random mode');
randomMode = false;
ownsDestination = true;
existingBank = writes[0].body.map((q, i) => ({ ...q, puzzle_id: `seen-${i}` }));
excludedIds = existingBank.map(q => q.puzzle_id);
writes = [];
const callsBeforeTopup = generationCalls;
result = await handler(request());
assert.equal(result.status, 200);
assert.equal(generationCalls, callsBeforeTopup + 1, 'Seen ten-question bank gets fresh generation');
assert.ok(writes[0].body.every(q => !existingBank.some(old => old.question_text === q.question_text)));
console.log('Passed: random mode ownership isolation, fresh top-up, ten-question batches, reuse, partial saves and bounded retries.');
referenceAvailable = false;
existingBank = [];
writes = [];
excludedIds = [];
result = await handler(request());
assert.equal(result.status, 200, 'Google destination generates without matching an outside title');
assert.equal((await result.json()).context_mode, 'saved_destination');
assert.equal(writes[0].body.length, 10);
console.log('Passed: saved Google identity reaches generation and save when references are missing.');
referenceAvailable = true;
existingBank = [];
writes = [];
batchSize = 6;
const callsBeforeRefill = generationCalls;
result = await handler(request());
assert.equal(result.status, 200, 'Automatically fill a six-question batch');
assert.equal(generationCalls - callsBeforeRefill, 2);
assert.equal(writes[0].body.length, 12);
assert.equal(new Set(writes[0].body.map(q => q.question_text)).size, 12);
console.log('Passed: short first batch automatically topped up without another draw or click.');
overloaded = true;
usedModels = [];
existingBank = [];
writes = [];
batchSize = 10;
result = await handler(request());
assert.equal(result.status, 200);
assert.equal(usedModels.length, 2);
assert.ok(usedModels[1].includes('gemini-3.5-flash:'));
assert.equal(writes[0].body.length, 10);
console.log('Passed: overloaded primary switches to a discovered fallback and saves ten questions.');
overloaded = false;
existingBank = [];
writes = [];
result = await handler(new Request('https://test.invalid', { method: 'POST', headers: { Authorization: 'Bearer test' }, body: JSON.stringify({ destination_id: 'destination', grow_bank: true }) }));
assert.equal(result.status, 200);
assert.equal(writes[0].body.length, 20, 'Background growth does not stop at ten');
leaseHeld = true;
writes = [];
const beforeLease = generationCalls;
result = await handler(request());
assert.equal(result.status, 202);
assert.equal(generationCalls, beforeLease, 'An existing worker prevents duplicate generation');
let background;
globalThis.EdgeRuntime = { waitUntil: promise => { background = promise; } };
claimedCategories = [];
result = await handler(new Request('https://test.invalid', { method: 'POST', headers: { Authorization: 'Bearer test' }, body: JSON.stringify({ destination_id: 'destination', prepare_all: true }) }));
assert.equal(result.status, 202);
await background;
assert.deepEqual(new Set(claimedCategories), new Set(['Multiple Choice Question','Missing Word Challenge','True or False','Scrambled Word','Guess the Word']));
assert.equal(generationCalls, beforeLease);
console.log('Passed: background growth, five-bank scheduling and shared lease contention.');
