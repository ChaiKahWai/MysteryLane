// Reviewed starter bank. Exact aliases only: never reuse a bank for another place.
// Sources checked 2026-09-04:
// https://www.arup.com/projects/merdeka-118/
// https://www.thorntontomasetti.com/project/merdeka-118
// This is a 20-question starter, not the completed 80–100-question bank.
const merdeka = [
  ['How tall is Merdeka 118, including its spire?', '678.9 metres', '451.9 metres', '421 metres', '828 metres'],
  ['How many storeys does Merdeka 118 have?', '118', '88', '101', '124'],
  ['What shape characterises the faceted exterior of Merdeka 118?', 'A diamond', 'A cylinder', 'A smooth sphere', 'A crescent'],
  ['What gesture inspired the form of Merdeka 118?', 'An outstretched hand declaring independence', 'A royal bow', 'A two-handed wave', 'A sporting victory salute'],
  ['What national event does the design of Merdeka 118 commemorate?', 'The declaration of independence', 'The first Formula One race', 'The opening of the national airport', 'The founding of ASEAN'],
  ['In which year did the independence declaration that inspired Merdeka 118 take place?', '1957', '1963', '1971', '1988'],
  ['Which historic stadium in the Merdeka 118 precinct hosted the independence declaration?', 'Stadium Merdeka', 'Bukit Jalil National Stadium', 'Shah Alam Stadium', 'Stadium Darul Aman'],
  ['Which other historic national stadium stands beside the Merdeka 118 development?', 'Stadium Negara', 'Stadium Sultan Ibrahim', 'Stadium Hang Tuah', 'Stadium Perak'],
  ['What type of development is Merdeka 118?', 'A mixed-use tower', 'A broadcasting-only mast', 'A single-purpose factory', 'A sports-only arena'],
  ['What is the slender structure above the main body of Merdeka 118 called?', 'A spire', 'A moat', 'An arcade', 'A courtyard'],
  ['Which natural force was a major consideration in engineering the Merdeka 118 spire?', 'Wind', 'Ocean tides', 'Avalanches', 'Volcanic lava'],
  ['Which testing method helped engineers study wind effects on the Merdeka 118 spire?', 'Wind-tunnel testing', 'Deep-sea testing', 'Crash-barrier testing', 'Ice-core sampling'],
  ['What special material was developed for the core and mega-columns of Merdeka 118?', 'High-performance concrete', 'Compressed paper', 'Unreinforced clay', 'Solid copper'],
  ['What shape was used for the excavation cofferdam at Merdeka 118?', 'Circular', 'Star-shaped', 'Triangular', 'Crescent-shaped'],
  ['Why did engineers closely monitor the ground around the Merdeka 118 construction site?', 'To protect the historic neighbourhood from ground movement', 'To find offshore oil', 'To measure snowfall', 'To map coral reefs'],
  ['Which engineering firm served as civil and structural engineer of record for Merdeka 118?', 'Arup', 'AECOM', 'WSP', 'Mott MacDonald'],
  ['Which company owns the Merdeka 118 development?', 'PNB Merdeka Ventures', 'Genting Malaysia', 'Malaysia Airports', 'Telekom Malaysia'],
  ['Which firm provided structural peer review for Merdeka 118?', 'Thornton Tomasetti', 'Ramboll', 'Atkins', 'Jacobs'],
  ['In which year was the Merdeka 118 tower initially proposed, according to its structural peer reviewer?', '2010', '1980', '1995', '2020'],
  ['Which tower did Merdeka 118 surpass to become the world\'s second-tallest building?', 'Shanghai Tower', 'Eiffel Tower', 'Tokyo Tower', 'Leaning Tower of Pisa'],
];

export function curatedQuestions(name: string) {
  if (!['merdeka 118', 'merdeka 118 precinct'].includes(name.trim().toLowerCase())) return [];
  return merdeka.map(([question, answer, ...others], index) => {
    const options = [answer, ...others];
    // Rotate correct positions; do not make every correct option A.
    const offset = index % 4;
    return { question, options: [...options.slice(offset), ...options.slice(0, offset)],
      correct_answer: answer, difficulty: 'MEDIUM' as const,
      hint_1: 'Think about the tower\'s architecture, engineering and independence heritage.',
      hint_2: 'Focus on the specific feature or event named in the question.' };
  });
}
