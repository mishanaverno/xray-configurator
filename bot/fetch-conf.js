
const DEFAULT_TIMEOUT_MS = 4000;

async function fetchConfig(path, timeoutMs = DEFAULT_TIMEOUT_MS) {
  const baseUrl = process.env.XRAY_API_BASE || "http://127.0.0.1:8080";
  const url = baseUrl + path;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(url, {
      method: "GET",
      signal: controller.signal,
      headers: { Accept: "text/plain" }
    });

    const body = (await res.text()).trim();

    return {
      ok: res.ok,
      status: res.status,
      body
    };
  } catch (e) {
    return {
      ok: false,
      status: 0,
      body: `Request failed: ${e?.message || String(e)}`
    };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { fetchConfig };