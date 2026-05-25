/**
 * Minimal OpenRouter chat client for JudgeServiceLive.
 * Default model aligns with Pi settings.json: openrouter/free.
 */

export const DEFAULT_JUDGE_MODEL = "openrouter/free";
export const OPENROUTER_CHAT_URL =
  "https://openrouter.ai/api/v1/chat/completions";

export type FetchFn = typeof fetch;

export interface OpenRouterChatOptions {
  readonly apiKey: string;
  readonly model: string;
  readonly prompt: string;
  readonly temperature?: number;
  readonly maxTokens?: number;
  readonly fetchFn?: FetchFn;
}

export async function openRouterChatCompletion(
  options: OpenRouterChatOptions
): Promise<string> {
  const fetchFn = options.fetchFn ?? fetch;
  const response = await fetchFn(OPENROUTER_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${options.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: options.model,
      messages: [{ role: "user", content: options.prompt }],
      temperature: options.temperature ?? 0.3,
      max_tokens: options.maxTokens ?? 500,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `OpenRouter request failed (${response.status}): ${body.slice(0, 400)}`
    );
  }

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };

  const content = data.choices?.[0]?.message?.content;
  if (!content || content.trim().length === 0) {
    throw new Error("OpenRouter returned empty completion");
  }

  return content;
}

export function resolveJudgeModel(): string {
  return process.env.PI_JUDGE_MODEL ?? DEFAULT_JUDGE_MODEL;
}

export function resolveOpenRouterApiKey(): string | undefined {
  return process.env.OPENROUTER_API_KEY;
}
