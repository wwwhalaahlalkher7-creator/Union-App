function providerError(provider, status, body) {
  const e = new Error(`${provider} request failed with status ${status}`);
  e.provider = provider; e.status = status; e.body = body;
  return e;
}

export async function tavilySearch({ apiKey, query, maxResults = 5, searchDepth = 'basic', signal }) {
  if (!apiKey) throw new Error('TAVILY_API_KEY is empty');
  const response = await fetch('https://api.tavily.com/search', {
    method: 'POST', headers: { 'content-type': 'application/json' }, signal,
    body: JSON.stringify({ api_key: apiKey, query, max_results: Math.min(10, Math.max(1, maxResults)), search_depth: searchDepth, include_answer: false, include_raw_content: false }),
  });
  if (!response.ok) throw providerError('tavily', response.status, await response.text().catch(() => ''));
  const data = await response.json();
  return { provider: 'tavily', results: Array.isArray(data?.results) ? data.results : [], raw: data };
}

export async function exaSearch({ apiKey, query, maxResults = 5, signal }) {
  if (!apiKey) throw new Error('EXA_API_KEY is empty');
  const response = await fetch('https://api.exa.ai/search', {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` }, signal,
    body: JSON.stringify({ query, numResults: Math.min(10, Math.max(1, maxResults)), type: 'auto', contents: { highlights: { maxCharacters: 1200 } } }),
  });
  if (!response.ok) throw providerError('exa', response.status, await response.text().catch(() => ''));
  const data = await response.json();
  return { provider: 'exa', results: Array.isArray(data?.results) ? data.results : [], raw: data };
}

export function formatSearchContext(results = []) {
  return results.map((item, index) => {
    const title = String(item?.title || item?.name || `مصدر ${index + 1}`);
    const url = String(item?.url || item?.link || '').trim();
    const text = String(item?.content || item?.highlight || item?.highlights?.join?.(' ') || item?.summary || '').trim();
    return `[${index + 1}] ${title}\nURL: ${url}\n${text}`;
  }).join('\n\n');
}
