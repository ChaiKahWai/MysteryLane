import assert from 'node:assert/strict';
import { destinationReference, DestinationReferenceError } from '../supabase/functions/generate-destination-questions/reference.ts';
let title = 'Petaling Street';
let redirectPage;
let sectionRedirect = false;
globalThis.fetch = async url => {
  const params = new URL(url).searchParams;
  if (params.has('titles')) return new Response(JSON.stringify({ query: {
    redirects: sectionRedirect ? [{ tofragment: 'Nearby attractions' }] : [],
    pages: redirectPage ? { 54379666: redirectPage } : { '-1': { missing: '' } },
  } }));
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
title = 'Jamek Mosque';
redirectPage = { pageid: 54379666, title };
assert.match(await destinationReference({ name: 'Sultan Abdul Samad Jamek Mosque' }), /Title: Jamek Mosque/);
redirectPage = { pageid: 54379666, title, pageprops: { disambiguation: '' } };
await assert.rejects(destinationReference({ name: 'Sultan Abdul Samad Jamek Mosque' }), DestinationReferenceError);
redirectPage = { pageid: 54379666, title };
sectionRedirect = true;
await assert.rejects(destinationReference({ name: 'Sultan Abdul Samad Jamek Mosque' }), DestinationReferenceError);
console.log('Passed: alternate-name redirects, grammatical variants, unrelated-place rejection and disambiguation/section guards.');
