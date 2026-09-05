import assert from 'node:assert/strict';
import { destinationContext } from '../supabase/functions/generate-destination-questions/destination_context.ts';
const unavailable = async () => { throw new Error('No matching reference'); };
for (const identity of [{ destination_source: 'GOOGLE', google_place_id: 'place-123' }, { destination_source: 'CURATED' }, { google_place_id: 'legacy-google' }]) {
  const result = await destinationContext({ ...identity, name: 'Merdeka Square', address: 'Kuala Lumpur, Malaysia', description: 'A historic square.' }, unavailable);
  assert.equal(result.mode, 'saved_destination');
  assert.match(result.text, /Kuala Lumpur/);
  assert.match(result.text, /Never invent facts/);
  assert.match(result.text, /Do not claim Google supplied facts beyond/);
}
const enriched = await destinationContext({ destination_source: 'GOOGLE', name: 'Merdeka Square' }, async () => 'Verified reference facts');
assert.equal(enriched.mode, 'reference_enriched');
assert.match(enriched.text, /Verified reference facts/);
await assert.rejects(destinationContext({ name: 'Unknown place' }, unavailable));
console.log('Passed: Google/Curated identity survives reference failures; optional enrichment and unknown-source checks.');
