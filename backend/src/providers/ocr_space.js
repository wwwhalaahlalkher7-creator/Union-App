/** OCR.space adapter. Uses a dedicated OCR endpoint; no generative model is called. */
export async function ocrSpaceFromFile({ apiKey, file, signal }) {
  if (!apiKey) {
    const error = new Error('OCR_SPACE_API_KEY is empty');
    error.code = 'OCR_NOT_CONFIGURED';
    throw error;
  }

  const form = new FormData();
  form.append('file', file, file.name || 'scan.jpg');
  // OCR.space Engine 2 requires/works best with automatic language detection.
  // Explicit legacy language codes can trigger E201 on some OCR.space configurations.
  form.append('language', 'auto');
  form.append('isOverlayRequired', 'false');
  form.append('detectOrientation', 'true');
  form.append('scale', 'true');
  // Engine 2 supports automatic language detection, including Arabic, and table output.
  form.append('OCREngine', '2');

  let response;
  try {
    response = await fetch('https://api.ocr.space/parse/image', {
      method: 'POST', headers: { apikey: apiKey }, body: form, signal,
    });
  } catch (cause) {
    const error = new Error(signal?.aborted ? 'OCR upstream request timed out' : 'OCR upstream network request failed');
    error.code = signal?.aborted ? 'OCR_UPSTREAM_TIMEOUT' : 'OCR_UPSTREAM_NETWORK';
    error.cause = cause;
    throw error;
  }

  const body = await response.json().catch(() => ({}));
  const rawMessage = body?.ErrorMessage;
  const providerMessage = (Array.isArray(rawMessage) ? rawMessage.join(' ') : String(rawMessage || body?.ErrorDetails || ''))
    .replace(/[\r\n\t]+/g, ' ').replace(/\s{2,}/g, ' ').trim().slice(0, 240);
  const providerCode = String(body?.ErrorDetails || body?.OCRExitCode || body?.ErrorCode || '').slice(0, 80);

  if (!response.ok || body?.IsErroredOnProcessing) {
    const combined = `${providerMessage} ${providerCode}`.toLowerCase();
    let status = response.status;
    if (response.ok) {
      if (/api.?key|unauthori[sz]ed|invalid key|not valid key|access denied/.test(combined)) status = 401;
      else if (/quota|limit|credits|rate.?limit|upgrade/.test(combined)) status = 429;
      else if (/too large|file size|maximum.*size|size.*limit/.test(combined)) status = 413;
      else status = 422;
    }
    const error = new Error('OCR.space rejected the request');
    error.status = status;
    error.providerMessage = providerMessage;
    error.providerCode = providerCode;
    error.providerHttpStatus = response.status;
    throw error;
  }

  const results = Array.isArray(body?.ParsedResults) ? body.ParsedResults : [];
  const text = results.map((page) => String(page?.ParsedText || '')).filter(Boolean).join('\n');
  return { text: text.trim(), pageCount: results.length || Number(body?.ParsedResults?.length || 1), raw: body };
}
