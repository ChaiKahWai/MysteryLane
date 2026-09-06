import assert from 'node:assert/strict';
import { keywordReferenceMatches } from '../supabase/functions/generate-destination-questions/reference_matching.ts';
import { destinationReference } from '../supabase/functions/generate-destination-questions/reference.ts';
assert.equal(keywordReferenceMatches('Arkadia Shopping Plaza', 'Desa ParkCity, Kuala Lumpur, Malaysia', 'Plaza Arkadia', 'Desa ParkCity, Kuala Lumpur'), true);
assert.equal(keywordReferenceMatches('Plaza Arkadia', 'Desa ParkCity, Kuala Lumpur, Malaysia', 'Arkadia', 'A shopping centre in Warsaw, Poland'), false);
assert.equal(keywordReferenceMatches('National Museum', 'Kuala Lumpur, Malaysia', 'National Museum', 'Kuala Lumpur'), false, 'Generic words alone cannot identify a place');
assert.equal(keywordReferenceMatches('Central Market Annex', 'Kuala Lumpur, Malaysia', 'Central Market', 'Kuala Lumpur'), false, 'Identifying qualifiers must not disappear');
let ambiguous = false;
globalThis.fetch = async url => {
  const p = new URL(url).searchParams;
  let query;
  if (p.get('list') === 'search') query = { search: [{ title: 'Example Gardens', pageid: 1 }] };
  else if (p.has('titles')) query = { pages: { '-1': { missing: '' } } };
  else if (p.get('generator') === 'search') query = { pages: {
    1: { pageid: 1, title: 'Example Gardens', extract: 'Public gardens in Kuala Lumpur, Malaysia.' },
    ...(ambiguous ? { 2: { pageid: 2, title: 'Example Gardens Centre', extract: 'A different site in Kuala Lumpur, Malaysia.' } } : {}),
  } };
  else query = { pages: { 1: { title: 'Example Gardens', extract: 'Verified garden reference. '.repeat(40) } } };
  return new Response(JSON.stringify({ query }));
};
const place = { name: 'The Example Gardens Park', address: 'Kuala Lumpur, Malaysia' };
assert.match(await destinationReference(place), /Title: Example Gardens/);
ambiguous = true;
await assert.rejects(destinationReference(place), /Destination facts/);
console.log('Passed: keyword fallback, location confirmation, qualifier preservation and ambiguous-result rejection.');
