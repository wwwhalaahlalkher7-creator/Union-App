/** OCR.space adapter. Uses a dedicated OCR endpoint; no generative model is called. */
export async function ocrSpaceFromFile({ apiKey, file, signal }) {
  if (!apiKey) throw new Error('OCR_SPACE_API_KEY is empty');
  const form = new FormData();
  form.append('file', file, file.name || 'scan.jpg');
  form.append('language', 'ara');
  form.append('isOverlayRequired', 'false');
  form.append('detectOrientation', 'true');
  form.append('scale', 'true');
  // Engine 1 is the safer choice for Arabic-heavy academic tables.
  // Engine 2 is optimized primarily for alphanumeric/Latin documents and can
  // reject or perform poorly on Arabic scans on some OCR.space plans.
  form.append('OCREngine', '1');
  const response = await fetch('https://api.ocr.space/parse/image', {
    method: 'POST', headers: { apikey: apiKey }, body: form, signal,
  });
  const body = await response.json().catch(() => ({}));
  const providerMessage = String(
    body?.ErrorMessage?.join?.(' ') ||
    body?.ErrorMessage ||
    body?.ErrorDetails ||
    body?.Error ||
    ''
  ).slice(0, 240);
  if (!response.ok || body?.IsErroredOnProcessing) {
    const error = new Error('OCR.space request failed');
    error.status = response.status;
    error.providerMessage = providerMessage;
    error.providerExitCode = Number(body?.OCRExitCode || 0);
    throw error;
  }
  const results = Array.isArray(body?.ParsedResults) ? body.ParsedResults : [];
  const text = results.map((page) => String(page?.ParsedText || '')).filter(Boolean).join('\n');
  return { text: text.trim(), pageCount: results.length || Number(body?.ParsedResults?.length || 1), raw: body };
}
