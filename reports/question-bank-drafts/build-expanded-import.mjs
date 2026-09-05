import fs from 'node:fs';
import assert from 'node:assert/strict';
const dir = new URL('./', import.meta.url);
const base = JSON.parse(fs.readFileSync(new URL('base-drafts-2026-09-05.json',dir),'utf8'));
const groups = JSON.parse(fs.readFileSync(new URL('expanded-groups-2026-09-05.json',dir),'utf8'));
const known = new Set(base.map(d=>d.name));
for(const [name] of groups) assert(known.has(name),`Unknown destination: ${name}`);
const data=base.map(d=>{
 const added=groups.filter(g=>g[0]===d.name).flatMap(([name,source,lines])=>lines.split('\n').map(line=>{
  const x=line.split('|'); assert.equal(x.length,7,line);
  const [question_text,correct_answer,b,c,e,hint_1,hint_2]=x;
  assert(x.every(t=>t.trim()),line); assert(question_text.endsWith('?'),line);
  const options=[correct_answer,b,c,e]; assert.equal(new Set(options.map(s=>s.toLowerCase())).size,4,line);
  return {destination_id:d.destination_id,question_text,correct_answer,options,hint_1,hint_2,hint_3:`The correct answer is ${correct_answer}.`,source,evidence_type:'Web source'};
 }));
 const drafts=[...d.drafts,...added].map((q,i)=>({...q,options:q.options.slice(i%4).concat(q.options.slice(0,i%4))}));
 const keys=drafts.map(q=>q.question_text.toLowerCase().replace(/[^a-z0-9]/g,''));
 assert.equal(new Set(keys).size,keys.length,`Duplicate in ${d.name}`);
 return {destination_id:d.destination_id,name:d.name,category:d.category||'Destination Trivia',saved_before:d.saved_mcq,drafts,total:d.saved_mcq+drafts.length};
});
console.log(JSON.stringify(process.argv.includes('--counts')?data.map(({drafts,...d})=>d):data));
