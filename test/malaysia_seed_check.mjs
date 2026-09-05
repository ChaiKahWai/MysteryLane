import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const rows = readFileSync(new URL('../supabase/seeds/malaysia_general_mcq.txt', import.meta.url),'utf8').trim().split(/\r?\n/).map(line => line.split('|'));
assert.equal(rows.length,100);
assert.equal(new Set(rows.map(r=>r[0])).size,100);
for (const row of rows) {
  assert.equal(row.length,6);
  assert.equal(new Set(row.slice(1,5)).size,4);
  assert.ok(/^[ABCD]$/.test(row[5]));
  assert.ok(row[0].endsWith('?'));
}
if (process.argv.includes('--sql')) {
  const quote = text => "'" + text.replaceAll("'", "''") + "'";
  const hints = readFileSync(new URL('../supabase/seeds/malaysia_general_hints.txt', import.meta.url),'utf8').trim().split(/\r?\n/);
  assert.equal(hints.length,100);
  const values = rows.map((r,i)=>{
    const index='ABCD'.indexOf(r[5]);
    const answer=r[1+index];
    const pair=[answer,r[1+(index+1)%4]].sort();
    return '('+[...r.slice(0,5),answer,hints[i],`Narrow it down to these two choices: ${pair[0]} or ${pair[1]}.`,`The correct answer is ${answer}. ${hints[i]}`].map(quote).join(',')+')';
  }).join(',\n');
  console.log(`insert into public.puzzle_questions(category,puzzle_type,question_text,option_a,option_b,option_c,option_d,correct_answer,difficulty_level,is_active,hint_1,hint_2,hint_3)
select 'Malaysia General Knowledge','Multiple Choice Question',q,a,b,c,d,answer,'EASY',true,
h1,h2,h3
from (values ${values}) as approved(q,a,b,c,d,answer,h1,h2,h3)
where not exists(select 1 from public.puzzle_questions p where p.destination_id is null and p.category='Malaysia General Knowledge' and p.puzzle_type='Multiple Choice Question' and p.question_text=approved.q);`);
} else console.log('Passed: 100 approved questions, unique text, four options and valid answer mappings.');
