import fs from 'node:fs/promises';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const sourcePath = 'C:/Users/User/.codex/attachments/f9a14a5f-7b5a-4507-bda5-2077f6c7c7f1/pasted-text.txt';
const outputDir = 'C:/Users/User/AndroidStudioProjects/MysteryLane/outputs/curated-question-review';
const outputPath = `${outputDir}/curated_destination_questions_review.xlsx`;
const sql = await fs.readFile(sourcePath, 'utf8');
const tuplePattern = /\(\s*'((?:[^']|'')+)'\s*,\s*'((?:[^']|'')+)'\s*,\s*'((?:[^']|'')+)'\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'((?:[^']|'')+)'\s*\)/gms;
const clean = value => value.replaceAll("''", "'");
const places = [...sql.matchAll(tuplePattern)].map((m, i) => ({
  no: i + 1, name: clean(m[1]), description: clean(m[2]), category: clean(m[3]),
  latitude: Number(m[4]), longitude: Number(m[5]), address: clean(m[6]),
}));
if (places.length !== 40) throw new Error(`Expected 40 destinations, found ${places.length}`);

const catLabel = { ART: 'Art', CULTURE: 'Culture', HERITAGE: 'Heritage', NATURE: 'Nature', PARK: 'Park', MUSEUM: 'Museum' };
const profileByCategory = {
  ART: ['creative arts', 'art exhibitions', 'gallery visits', 'visual culture', 'art lovers', 'creative venue'],
  CULTURE: ['cultural heritage', 'cultural learning', 'heritage discovery', 'local traditions', 'culture lovers', 'cultural venue'],
  HERITAGE: ['built heritage', 'heritage learning', 'historic discovery', 'local history', 'history lovers', 'heritage site'],
  NATURE: ['natural environment', 'nature recreation', 'outdoor exploration', 'green landscapes', 'nature lovers', 'nature site'],
  PARK: ['urban recreation', 'park recreation', 'outdoor leisure', 'open green space', 'park visitors', 'public park'],
  MUSEUM: ['museum heritage', 'museum learning', 'exhibition viewing', 'historical collections', 'museum visitors', 'museum'],
};
const keywordLabels = [
  ['waterfall', 'waterfalls'], ['wetland', 'wetlands'], ['forest', 'forest'], ['lake', 'lakeside'],
  ['river', 'riverside'], ['railway', 'railway heritage'], ['telecommunication', 'telecommunications'],
  ['polic', 'policing history'], ['prime minister', 'prime-minister history'], ['royal', 'royal heritage'],
  ['fort', 'historic fort'], ['warehouse', 'historic warehouse'], ['church', 'historic church'],
  ['temple', 'traditional temple'], ['calligraphy', 'Islamic calligraphy'], ['street-art', 'street art'],
  ['mural', 'murals'], ['library', 'public library'], ['orchard', 'urban orchard'],
  ['fruit tree', 'fruit trees'], ['hiking', 'hiking trails'], ['walking', 'walking routes'],
  ['jogging', 'jogging paths'], ['picnic', 'picnic areas'], ['artefact', 'regional artefacts'],
  ['craft', 'traditional craftsmanship'], ['architecture', 'distinctive architecture'],
  ['gallery', 'art gallery'], ['music', 'independent music'], ['book', 'independent books'],
  ['artist', 'Malaysian artists'], ['designer', 'local designers'], ['event', 'cultural events'],
  ['exhibition', 'exhibitions'], ['rainforest', 'rainforest trails'], ['stream', 'forest streams'],
  ['wildlife', 'wildlife habitats'], ['lighthouse', 'lighthouse'], ['mausoleum', 'royal mausoleum'],
];
function regionOf(p) { return p.address.includes('Selangor') ? 'Selangor' : 'Kuala Lumpur'; }
function localityOf(p) {
  const known = ['Kampung Attap','Brickfields','Sentul West','Pantai Dalam','Kepong','Ampang Hilir','Wangsa Maju','Shah Alam','Klang','Petaling Jaya','Kota Damansara','Rawang','Selayang','Hulu Langat','Dengkil','Sepang','Puchong','Setia Alam','Jugra','Banting'];
  return known.find(x => p.address.toLowerCase().includes(x.toLowerCase())) || regionOf(p);
}
function featureLabels(p) {
  const text = `${p.name} ${p.description}`.toLowerCase();
  const found = keywordLabels.filter(([key]) => text.includes(key)).map(([,label]) => label);
  const defaults = profileByCategory[p.category] || ['visitor attraction','local interest'];
  return [...new Set([...found, ...defaults])].slice(0, 2);
}
function factsFor(p) {
  const profile = profileByCategory[p.category] || ['visitor interest','visitor learning','local exploration','local identity','visitors','destination'];
  const features = featureLabels(p);
  return [
    { key:'region', q:`In which state or federal territory is ${p.name} located?`, a:regionOf(p), h1:`It is in the Greater Kuala Lumpur area.`, h2:`Choose between Kuala Lumpur and its neighbouring states.` },
    { key:'locality', q:`Which locality is associated with ${p.name} in the curated destination list?`, a:localityOf(p), h1:`Look at the destination's listed address.`, h2:`It is the local area named in the address.` },
    { key:'category', q:`Which destination category best describes ${p.name}?`, a:catLabel[p.category] || p.category, h1:`Think about the destination's main purpose.`, h2:`The supplied description classifies it as ${profile[5]}.` },
    { key:'theme', q:`What main theme is most closely associated with ${p.name}?`, a:profile[0], h1:`Focus on what visitors primarily experience here.`, h2:`The theme follows its ${catLabel[p.category] || p.category.toLowerCase()} classification.` },
    { key:'experience', q:`What type of visitor experience best fits ${p.name}?`, a:profile[1], h1:`Consider the activities described for this place.`, h2:`It is an experience connected with ${profile[0]}.` },
    { key:'activity', q:`Which activity is most suitable at ${p.name}?`, a:profile[2], h1:`Choose an activity consistent with the destination description.`, h2:`The activity relates to ${profile[1]}.` },
    { key:'setting', q:`Which setting is most characteristic of ${p.name}?`, a:profile[3], h1:`Think about the surroundings or collections described.`, h2:`The setting supports ${profile[2]}.` },
    { key:'audience', q:`Which visitors are most likely to appreciate ${p.name}?`, a:profile[4], h1:`Consider the destination's central subject.`, h2:`These visitors are interested in ${profile[0]}.` },
    { key:'feature1', q:`Which feature is specifically associated with ${p.name}?`, a:features[0], h1:`It appears in the supplied destination description.`, h2:`It helps define this ${profile[5]}.` },
    { key:'feature2', q:`Which additional subject or feature is linked with ${p.name}?`, a:features[1], h1:`Review the activities, displays, or surroundings in the supplied description.`, h2:`It is another element connected with this ${profile[5]}.` },
    { key:'venue', q:`What type of place is ${p.name} best understood as?`, a:profile[5], h1:`Use the destination's category and description together.`, h2:`The answer describes the venue rather than a single activity.` },
    { key:'identity', q:`Which destination matches this description: ${p.description}`, a:p.name, h1:`The answer is one of the curated hidden-gem destinations.`, h2:`It is located in ${regionOf(p)}.` },
  ].map((f, i) => ({...f, factNo:i+1}));
}

const facts = places.flatMap(p => factsFor(p).map(f => ({...f, place:p})));
function optionPool(fact, answer) {
  const candidates = facts.filter(x => x.key === fact.key && x.a !== answer).map(x => x.a);
  const unique = [...new Set(candidates)];
  for (const fallback of ['Johor','Penang','historical research','family entertainment','shopping centre','sports arena','industrial site']) {
    if (fallback !== answer && !unique.includes(fallback)) unique.push(fallback);
  }
  return [answer, ...unique.slice((fact.factNo * 3) % Math.max(1, unique.length), (fact.factNo * 3) % Math.max(1, unique.length) + 3)].slice(0,4);
}
function rotate(arr, n) { const k=n%arr.length; return [...arr.slice(k),...arr.slice(0,k)]; }
function scramble(answer, seed) {
  const clean = answer.toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (clean.length < 2) return clean;
  const chars = clean.split('');
  let state = (seed * 2654435761) >>> 0;
  for (let i = chars.length - 1; i > 0; i--) {
    state = (state * 1664525 + 1013904223) >>> 0;
    const j = state % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  const mixed = chars.join('');
  return mixed === clean ? clean.slice(1) + clean[0] : mixed;
}
const rows = [];
for (const fact of facts) {
  const options = rotate(optionPool(fact, fact.a), fact.place.no + fact.factNo);
  while (options.length < 4) options.push(`Alternative ${options.length}`);
  const common = { destinationNo:fact.place.no, destination:fact.place.name, factNo:fact.factNo, sourceDescription:fact.place.description, sourceAddress:fact.place.address };
  rows.push({...common, puzzleType:'Multiple Choice Question', question:fact.q, boxContent:'', options, answer:fact.a, hint1:fact.h1, hint2:fact.h2, hint3:`The correct answer is ${fact.a}.`});
  rows.push({...common, puzzleType:'Missing Word Challenge', question:fact.q, boxContent:'', options, answer:fact.a, hint1:fact.h1, hint2:fact.h2, hint3:`The missing answer is ${fact.a}.`});
  const makeFalse = fact.factNo % 2 === 0;
  const checked = makeFalse ? options.find(x => x !== fact.a) : fact.a;
  rows.push({...common, puzzleType:'True or False', question:fact.q, boxContent:checked, options:['True','False','',''], answer:makeFalse?'False':'True', hint1:fact.h1, hint2:makeFalse?`${checked} is not the correct answer.`:`${checked} matches the supplied destination data.`, hint3:`The correct answer is ${makeFalse?'False':'True'}.`});
  rows.push({...common, puzzleType:'Scrambled Anagrams', question:fact.q, boxContent:scramble(fact.a, fact.place.no * 100 + fact.factNo), options:['','','',''], answer:fact.a, hint1:fact.h1, hint2:`The answer has ${fact.a.replace(/[^A-Za-z0-9]/g,'').length} letters or digits when spaces and punctuation are removed.`, hint3:`The correct answer is ${fact.a}.`});
}

const duplicateKey = r => `${r.destination}|${r.puzzleType}|${r.question}`.toLowerCase().replace(/[^a-z0-9|]/g,'');
const keys = new Set();
for (const row of rows) {
  const key = duplicateKey(row);
  if (keys.has(key)) throw new Error(`Duplicate: ${key}`);
  keys.add(key);
  if (!row.question.trim() || !row.answer.trim() || !row.hint1.trim() || !row.hint2.trim() || !row.hint3.trim()) throw new Error('Incomplete row');
  if (/[“”] correctly answers:/.test(row.question)) throw new Error(`Wrapped question found: ${row.destination}`);
  if (['True or False','Scrambled Anagrams'].includes(row.puzzleType) && !row.boxContent.trim()) throw new Error(`Missing box content: ${row.destination}`);
  if (['Multiple Choice Question','Missing Word Challenge'].includes(row.puzzleType) && (new Set(row.options).size !== 4 || !row.options.includes(row.answer))) throw new Error(`Invalid options: ${row.destination}`);
}

const wb = Workbook.create();
const summary = wb.worksheets.add('Destination Summary');
const bank = wb.worksheets.add('Question Bank');
const notes = wb.worksheets.add('Review Notes');
summary.showGridLines = false; bank.showGridLines = false; notes.showGridLines = false;

summary.getRange('A1:H1').merge();
summary.getRange('A1').values = [['Curated destination question coverage']];
summary.getRange('A2:H2').merge();
summary.getRange('A2').values = [['Draft questions for review only. No database records were inserted.']];
summary.getRange('A4:H4').values = [['No.','Destination','Region','Category','MCQ','Missing Word','True or False','Scrambled']];
const factsPerDestination = facts.length / places.length;
const summaryRows = places.map(p => [p.no,p.name,regionOf(p),catLabel[p.category]||p.category,factsPerDestination,factsPerDestination,factsPerDestination,factsPerDestination]);
summary.getRange(`A5:H${4+summaryRows.length}`).values = summaryRows;
summary.getRange('A45:D45').values = [['Total destinations',40,'Total category records',rows.length]];

const headers = ['Destination No.','Destination','Fact No.','Puzzle Type','Question','Box Below Question','Option A','Option B','Option C','Option D','Correct Answer','Hint 1','Hint 2','Hint 3','Source Description','Source Address','Review Status'];
bank.getRange('A1:Q1').values = [headers];
bank.getRange(`A2:Q${rows.length+1}`).values = rows.map(r => [r.destinationNo,r.destination,r.factNo,r.puzzleType,r.question,r.boxContent,...r.options,r.answer,r.hint1,r.hint2,r.hint3,r.sourceDescription,r.sourceAddress,'Pending review']);
bank.tables.add(`A1:Q${rows.length+1}`, true, 'CuratedQuestionBank');
bank.freezePanes.freezeRows(1); bank.freezePanes.freezeColumns(2);
bank.getRange(`Q2:Q${rows.length+1}`).dataValidation = { rule: { type:'list', values:['Pending review','Approved','Revise','Reject'] } };

notes.getRange('A1:F1').merge(); notes.getRange('A1').values = [['How to review this question bank']];
notes.getRange('A3:B9').values = [
  ['Scope',`40 curated destinations; ${factsPerDestination} source-grounded facts per destination; four puzzle formats per fact.`],
  ['Total records',rows.length],
  ['Destination priority',`Each category has ${factsPerDestination} specific records, so general Malaysia fallback is not needed for the first round.`],
  ['Multiple Choice','Direct question with four choices.'],
  ['Missing Word','Direct question with four choices.'],
  ['True or False','Shows the direct question, with the proposed answer in the separate box below it.'],
  ['Scrambled Anagrams','Shows the direct question, with mixed letters in the separate box below it.'],
];
notes.getRange('A11:B13').values = [
  ['Source','The supplied 40-destination SQL list.'],
  ['Review action','Filter the Question Bank by destination and set Review Status.'],
  ['Important','These drafts intentionally remain outside Supabase until approved.'],
];

for (const sheet of [summary, bank, notes]) sheet.getUsedRange().format.font = {name:'Arial',size:10,color:'#172033'};
for (const [sheet, range] of [[summary,'A1:H1'],[notes,'A1:F1']]) {
  sheet.getRange(range).format.font = {name:'Arial',size:16,bold:true,color:'#172033'};
  sheet.getRange(range).format.rowHeight = 28;
}
summary.getRange('A4:H4').format = {fill:'#0F4C5C',font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center'};
bank.getRange('A1:Q1').format = {fill:'#0F4C5C',font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true};
summary.getRange('A2:H2').format.font = {name:'Arial',size:10,italic:true,color:'#526071'};
summary.getRange('A5:H44').format.borders = {insideHorizontal:{style:'thin',color:'#DCE3EA'}};
summary.getRange('E5:H44').format.horizontalAlignment = 'center';
bank.getRange(`A2:Q${rows.length+1}`).format.verticalAlignment = 'top';
bank.getRange(`E2:Q${rows.length+1}`).format.wrapText = true;
bank.getRange(`A2:D${rows.length+1}`).format.horizontalAlignment = 'center';
notes.getRange('A3:A13').format.font = {name:'Arial',size:10,bold:true,color:'#0F4C5C'};
notes.getRange('A3:B13').format.wrapText = true;

summary.getRange('A:H').format.autofitColumns();
summary.getRange('B:B').format.columnWidth = 34;
bank.getRange('A:Q').format.autofitColumns();
bank.getRange('B:B').format.columnWidth = 30; bank.getRange('D:D').format.columnWidth = 22;
bank.getRange('E:E').format.columnWidth = 52; bank.getRange('F:F').format.columnWidth = 28; bank.getRange('G:K').format.columnWidth = 23;
bank.getRange('L:N').format.columnWidth = 38; bank.getRange('O:P').format.columnWidth = 48; bank.getRange('Q:Q').format.columnWidth = 18;
notes.getRange('A:A').format.columnWidth = 24; notes.getRange('B:B').format.columnWidth = 88;

await fs.mkdir(outputDir,{recursive:true});
const out = await SpreadsheetFile.exportXlsx(wb); await out.save(outputPath);
const inspect = await wb.inspect({kind:'table',range:'Destination Summary!A1:H12',include:'values,formulas',tableMaxRows:12,tableMaxCols:8});
console.log(inspect.ndjson);
const errors = await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:100},summary:'final formula error scan'});
console.log(errors.ndjson);
for (const [sheetName, range, file] of [['Destination Summary','A1:H45','summary.png'],['Question Bank','A1:Q16','questions.png'],['Review Notes','A1:F13','notes.png']]) {
  const image = await wb.render({sheetName,range,scale:1,format:'png'});
  await fs.writeFile(`${outputDir}/${file}`,new Uint8Array(await image.arrayBuffer()));
}
console.log(JSON.stringify({outputPath,destinations:places.length,baseFacts:facts.length,records:rows.length,duplicates:rows.length-keys.size}));
await fs.writeFile(`${outputDir}/question_rows.json`, JSON.stringify({places,rows}));
