import fs from 'node:fs/promises';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const root = 'C:/Users/User/AndroidStudioProjects/MysteryLane';
const config = await fs.readFile(`${root}/lib/core/config/supabase_config.dart`, 'utf8');
const url = config.match(/supabaseUrl\s*=\s*'([^']+)'/)?.[1];
const key = config.match(/supabaseAnonKey\s*=\s*'([^']+)'/)?.[1];
if (!url || !key) throw new Error('Supabase configuration was not found.');

const rows = [];
for (let from = 0; ; from += 1000) {
  const select = 'puzzle_id,puzzle_type,question_text,display_box_content,correct_answer,hint_1,hint_2,blind_box_destinations(name)';
  const endpoint = `${url}/rest/v1/puzzle_questions?select=${encodeURIComponent(select)}&is_active=eq.true&puzzle_type=in.(Guess%20the%20Word,Multiple%20Choice%20Question,True%20or%20False)&order=puzzle_type.asc,puzzle_id.asc`;
  const response = await fetch(endpoint, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      Range: `${from}-${from + 999}`,
      Prefer: 'count=exact',
    },
  });
  if (!response.ok) throw new Error(`Question retrieval failed: ${response.status}`);
  const page = await response.json();
  rows.push(...page);
  if (page.length < 1000) break;
}

const hint1Counts = new Map();
const hint2Counts = new Map();
for (const row of rows) {
  const h1 = String(row.hint_1 ?? '').trim().toLowerCase();
  const h2 = String(row.hint_2 ?? '').trim().toLowerCase();
  hint1Counts.set(h1, (hint1Counts.get(h1) ?? 0) + 1);
  hint2Counts.set(h2, (hint2Counts.get(h2) ?? 0) + 1);
}

const data = rows.map((row) => {
  const destination = row.blind_box_destinations?.name ?? 'Malaysia General Knowledge';
  const hint1 = String(row.hint_1 ?? '').trim();
  const hint2 = String(row.hint_2 ?? '').trim();
  return [
    destination,
    row.puzzle_type,
    row.question_text,
    row.display_box_content ?? '',
    row.correct_answer,
    hint1,
    hint2,
    hint1Counts.get(hint1.toLowerCase()) === 1 ? 'Unique' : 'Repeated',
    hint2Counts.get(hint2.toLowerCase()) === 1 ? 'Unique' : 'Repeated',
    row.puzzle_id,
  ];
});
data.sort((a, b) => String(a[0]).localeCompare(String(b[0])) || String(a[1]).localeCompare(String(b[1])));

const destinationCounts = new Map();
for (const row of data) {
  const name = row[0];
  const item = destinationCounts.get(name) ?? { scrambled: 0, mcq: 0, tf: 0 };
  if (row[1] === 'Guess the Word') item.scrambled++;
  if (row[1] === 'Multiple Choice Question') item.mcq++;
  if (row[1] === 'True or False') item.tf++;
  destinationCounts.set(name, item);
}

const workbook = Workbook.create();
const summary = workbook.worksheets.add('Destination summary');
const questions = workbook.worksheets.add('Question hints');
summary.showGridLines = false;
questions.showGridLines = false;

summary.getRange('A1:E1').merge();
summary.getRange('A1').values = [['Puzzle hint inventory']];
summary.getRange('A2:E2').merge();
summary.getRange('A2').values = [['Active questions in the three playable categories. Database content is listed for review; no database values were changed.']];
summary.getRange('A4:E4').values = [['Destination', 'Scrambled Anagrams', 'Multiple Choice Trivia', 'True or False', 'Total']];
const summaryRows = [...destinationCounts.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([name, c]) => [name, c.scrambled, c.mcq, c.tf, c.scrambled + c.mcq + c.tf]);
summary.getRange('A5').write(summaryRows);

questions.getRange('A1:J1').values = [[
  'Destination', 'Category', 'Question', 'Answer to check', 'Correct answer',
  'Hint 1', 'Hint 2', 'Hint 1 status', 'Hint 2 status', 'Puzzle ID',
]];
questions.getRange('A2').write(data);

for (const sheet of [summary, questions]) {
  sheet.getUsedRange().format.font = { name: 'Arial', size: 10, color: '#172033' };
  sheet.getRange(sheet === summary ? 'A4:E4' : 'A1:J1').format = {
    fill: '#087FAC',
    font: { name: 'Arial', size: 10, bold: true, color: '#FFFFFF' },
    verticalAlignment: 'center',
    wrapText: true,
  };
}
summary.getRange('A1:E1').format.font = { name: 'Arial', size: 16, bold: true, color: '#172033' };
summary.getRange('A2:E2').format.font = { name: 'Arial', size: 10, italic: true, color: '#64748B' };
summary.getRange(`B5:E${summaryRows.length + 4}`).format.numberFormat = '#,##0';
summary.getRange('A:A').format.columnWidth = 42;
summary.getRange('B:E').format.columnWidth = 20;
summary.freezePanes.freezeRows(4);

questions.getRange('A:A').format.columnWidth = 34;
questions.getRange('B:B').format.columnWidth = 24;
questions.getRange('C:C').format.columnWidth = 55;
questions.getRange('D:G').format.columnWidth = 38;
questions.getRange('H:I').format.columnWidth = 15;
questions.getRange('J:J').format.columnWidth = 36;
questions.getUsedRange().format.wrapText = true;
questions.getUsedRange().format.verticalAlignment = 'top';
questions.freezePanes.freezeRows(1);
questions.freezePanes.freezeColumns(2);
questions.tables.add(`A1:J${data.length + 1}`, true, 'QuestionHintsTable').style = 'TableStyleMedium2';

const outputPath = `${root}/outputs/hint_review_20260906/puzzle_question_hints.xlsx`;
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

const check = await workbook.inspect({ kind: 'table', range: 'Destination summary!A1:E12', include: 'values,formulas', tableMaxRows: 12, tableMaxCols: 5 });
console.log(check.ndjson);
const errors = await workbook.inspect({ kind: 'match', searchTerm: '#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!', options: { useRegex: true, maxResults: 100 }, summary: 'formula error scan' });
console.log(errors.ndjson);
console.log(JSON.stringify({ outputPath, rows: data.length, destinations: destinationCounts.size }));
