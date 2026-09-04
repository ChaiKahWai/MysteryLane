import assert from 'node:assert/strict';
import { destinationReference, DestinationReferenceError } from '../supabase/functions/generate-destination-questions/reference.ts';
let title = 'Petaling Street';
globalThis.fetch = async url => {
  const params = new URL(url).searchParams;
  const body = params.get('list') === 'search'
    ? { query: { search: [{ title, pageid: 1825254 }] } }
    : { query: { pages: { 1825254: { title, extract: 'Destination reference facts. '.repeat(40) } } } };
  return new Response(JSON.stringify(body));
};
assert.match(await destinationReference({ name: 'Petaling Street Market' }), /Title: Petaling Street/);
title = 'Central Market';
await assert.rejects(destinationReference({ name: 'Petaling Street Market' }), DestinationReferenceError);
await assert.rejects(destinationReference({ name: 'Central Market Annex' }), DestinationReferenceError);
title = 'National Museum (Malaysia)';
for (const name of ['The National Museum of Malaysia', 'National Museum of Malaysia', 'National Museum (Malaysia)']) {
  assert.match(await destinationReference({ name }), /Title: National Museum \(Malaysia\)/);
}
for (const otherTitle of ['National Museum (Singapore)', 'National History Museum (Malaysia)', 'National Museum']) {
  title = otherTitle;
  await assert.rejects(destinationReference({ name: 'The National Museum of Malaysia' }), DestinationReferenceError);
}
console.log('Passed: reviewed alias and grammatical variants resolve; different museums, countries and generic suffix matches rejected.');
