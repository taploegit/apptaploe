export const config = {
  api: {
    bodyParser: false,
  },
};

function supabaseFunctionsUrl() {
  const url = process.env.SUPABASE_URL ||
    "https://gmpiygcnzlxllnablxmk.supabase.co";
  return `${url.replace(/\/+$/, "")}/functions/v1/stripe-webhook`;
}

async function readRawBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.status(405).json({ code: "METHOD_NOT_ALLOWED" });
    return;
  }

  const signature = req.headers["stripe-signature"];
  if (!signature) {
    res.status(400).json({ code: "SIGNATURE_MISSING" });
    return;
  }

  const rawBody = await readRawBody(req);
  const response = await fetch(supabaseFunctionsUrl(), {
    method: "POST",
    headers: {
      "content-type": req.headers["content-type"] || "application/json",
      "stripe-signature": signature,
    },
    body: rawBody,
  });

  const text = await response.text();
  res.status(response.status);
  const contentType = response.headers.get("content-type");
  if (contentType) res.setHeader("content-type", contentType);
  res.send(text);
}
