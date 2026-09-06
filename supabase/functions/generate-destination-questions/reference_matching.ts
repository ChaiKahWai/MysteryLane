const tokens = (text: string) => text.toLowerCase().normalize('NFKD')
  .replace(/[\u0300-\u036f]/g, '').match(/[a-z0-9]+/g) ?? [];
const generic = new Set('the of at in and a an plaza shopping mall centre center park museum mosque national malaysia tourist attraction official precinct'.split(' '));
export const destinationKeywords = (name: string) => [...new Set(tokens(name).filter(t => t.length >= 3 && !generic.has(t)))];

export function keywordReferenceMatches(name: string, address: string, title: string, intro: string): boolean {
  const keys = destinationKeywords(name);
  if (!keys.length) return false;
  const titleTokens = new Set(tokens(title));
  // All distinctive name words must match the title, not just an incidental
  // mention. Only generic/category wording may differ.
  if (!keys.every(key => titleTokens.has(key))) return false;
  const source = tokens(`${title} ${intro}`).join(' ');
  const localityParts = address.split(',').map(part => tokens(part).filter(t => !/^\d+$/.test(t)).join(' '))
    .filter(part => part.length >= 5 && part !== 'malaysia' && !/\b(jalan|street|road|no|block)\b/.test(part));
  return localityParts.some(part => source.includes(part));
}
