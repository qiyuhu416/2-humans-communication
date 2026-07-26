import http from "node:http";

const port = Number(process.env.PORT || 8787);
const apiKey = process.env.OPENAI_API_KEY;
const model = process.env.OPENAI_MODEL || "gpt-5.6-terra";

function sendJSON(response, status, value) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(value));
}

async function readJSON(request) {
  let body = "";
  for await (const chunk of request) {
    body += chunk;
    if (body.length > 1_000_000) {
      throw new Error("Request is too large.");
    }
  }
  return JSON.parse(body || "{}");
}

function extractOutputText(envelope) {
  if (typeof envelope.output_text === "string") return envelope.output_text;
  for (const item of envelope.output || []) {
    for (const content of item.content || []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }
  return null;
}

function validateRounds(payload) {
  if (!payload || !Array.isArray(payload.rounds) || payload.rounds.length < 3) {
    throw new Error("The model did not return at least three rounds.");
  }

  for (const round of payload.rounds) {
    if (!Array.isArray(round.scenarios) || round.scenarios.length !== 2) {
      throw new Error("Every round must contain exactly two scenarios.");
    }
    if (
      !round.opening ||
      !round.testedVariableLabel ||
      !round.testVariable ||
      !round.rationale
    ) {
      throw new Error("A generated round is missing required research fields.");
    }
  }

  return { rounds: payload.rounds.slice(0, 6) };
}

function generationPrompt(input) {
  const receiver = input.receiver;
  const actor = receiver === "Qiyu" ? "Samar" : "Qiyu";

  return `
Create six face-to-face relationship conversation rounds from the supplied user text and profiles.

The person being understood is ${receiver}. ${receiver} chooses what would feel good to receive. ${actor} independently chooses what they could comfortably do in real life.

Research constraints:
- Start with the user's concrete uncertainty. Do not diagnose or resolve it.
- Each round tests one observable behavioral variable while holding the rest of the moment constant.
- Give exactly two neutral, plausible options. Neither may read as more caring, mature, or correct.
- Every opening and option is a short, casual narrative using observable actions, words, timing, or constraints.
- Do not infer that either person wants to meet, is available, is thinking about the relationship, or feels an emotion unless the input explicitly says so.
- Avoid personality labels, therapy labels, happy endings, and headings that reveal an intended answer.
- Order rounds from the typed concern toward adjacent uncertainties.
- Use unique lowercase-hyphenated IDs.
- currentDayIndex and targetDayIndex are integers from 0 through 6.
- potentialVariables has 3–5 concise labels.
- heldConstant has 2–4 factual constants.
- discussionQuestions has 2–3 concrete follow-ups.
- suggestedReadings is always [].

Return JSON only:
{
  "rounds": [{
    "id": "lowercase-id",
    "opening": "short factual story opening",
    "openingQuestion": "short neutral transition",
    "currentDayIndex": 0,
    "targetDayIndex": 0,
    "timelineTargetLabel": "",
    "focusPerspective": "${receiver}",
    "qiyuPrompt": "${receiver === "Qiyu" ? "Which would feel good for Qiyu to receive?" : "Which could Qiyu comfortably do?"}",
    "samarPrompt": "${receiver === "Samar" ? "Which would feel good for Samar to receive?" : "Which could Samar comfortably do?"}",
    "testedVariableLabel": "short variable label",
    "testVariable": "precise description of the one changed behavior",
    "potentialVariables": ["variable"],
    "heldConstant": ["fact"],
    "rationale": "why this comparison isolates the variable without interpreting either person",
    "scenarios": [
      {"id":"option-a","title":"short title","summary":"one sentence","body":"short narrative"},
      {"id":"option-b","title":"short title","summary":"one sentence","body":"short narrative"}
    ],
    "discussionQuestions": ["specific question"],
    "suggestedReadings": []
  }]
}

Input:
${JSON.stringify(input.request)}
`.trim();
}

const server = http.createServer(async (request, response) => {
  if (request.method === "GET" && request.url === "/health") {
    return sendJSON(response, 200, {
      ok: true,
      model,
      apiKeyConfigured: Boolean(apiKey),
    });
  }

  if (request.method !== "POST" || request.url !== "/generate") {
    return sendJSON(response, 404, { error: "Not found." });
  }

  if (!apiKey) {
    return sendJSON(response, 503, {
      error: "OPENAI_API_KEY is not configured on the backend.",
    });
  }

  try {
    const input = await readJSON(request);
    if (!["Qiyu", "Samar"].includes(input.receiver) || !input.request?.userText) {
      return sendJSON(response, 400, {
        error: "receiver and request.userText are required.",
      });
    }

    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        authorization: `Bearer ${apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        input: generationPrompt(input),
        text: { verbosity: "low" },
        store: false,
      }),
    });

    const envelope = await openAIResponse.json();
    if (!openAIResponse.ok) {
      const message =
        envelope?.error?.message || `OpenAI returned HTTP ${openAIResponse.status}.`;
      return sendJSON(response, 502, { error: message });
    }

    let outputText = extractOutputText(envelope);
    if (!outputText) throw new Error("The model returned no output text.");
    outputText = outputText
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/, "")
      .trim();

    const generated = validateRounds(JSON.parse(outputText));
    return sendJSON(response, 200, generated);
  } catch (error) {
    return sendJSON(response, 500, {
      error: error instanceof Error ? error.message : "Generation failed.",
    });
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Between Us AI backend listening on http://127.0.0.1:${port}`);
});
