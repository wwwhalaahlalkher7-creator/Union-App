const DEFAULT_IMAGE_MODEL = '@cf/black-forest-labs/flux-1-schnell';

export async function cloudflareImage({ ai, model = DEFAULT_IMAGE_MODEL, prompt, steps = 4, seed, signal }) {
  if (!ai?.run) throw new Error('Cloudflare Workers AI binding is not configured');
  if (!String(prompt || '').trim()) throw new Error('Image prompt is empty');
  if (signal?.aborted) throw Object.assign(new Error('Aborted'), { name: 'AbortError' });
  const result = await ai.run(model, { prompt: String(prompt).trim().slice(0, 2048), steps: Math.min(8, Math.max(1, Number(steps) || 4)), ...(seed == null ? {} : { seed: Number(seed) }) });
  if (!result?.image) throw Object.assign(new Error('Cloudflare Workers AI returned no image'), { status: 502, provider: 'cloudflare-ai' });
  return { provider: 'cloudflare-ai', model, imageBase64: result.image, contentType: 'image/jpeg', raw: null };
}
