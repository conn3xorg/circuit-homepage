// Run with Node in the homepage container, which shares the host's network:
// `podman exec -i homepage node --input-type=module - < check.mjs`.
// It waits for Homepage, loads the dashboard, sees a wrong Host refused,
// reads back the services and bookmarks from the config files, with the
// {{HOMEPAGE_VAR_GREETING}} placeholder filled in from the env file, and has
// Homepage check one site that answers and one that doesn't.
import http from "node:http";

const u = "http://127.0.0.1:3000";
const fail = (m) => {
  console.error("FAIL: " + m);
  process.exit(1);
};
const json = async (path) => {
  const r = await fetch(u + path);
  if (!r.ok) fail(path + " answered " + r.status);
  return r.json();
};

for (let i = 0; ; i++) {
  try {
    if ((await fetch(u + "/api/healthcheck")).ok) break;
  } catch {}
  if (i === 300) fail("Homepage didn't answer in 5 minutes");
  await new Promise((r) => setTimeout(r, 1000));
}

const page = await fetch(u + "/");
const html = await page.text();
if (!page.ok || !html.includes("Conn3x example")) fail("dashboard " + page.status);

// fetch won't send another Host header, so this one goes through node:http.
const evil = await new Promise((resolve, reject) =>
  http.get(u + "/", { headers: { host: "evil.example:3000" } }, (r) => resolve(r.statusCode)).on("error", reject),
);
if (evil !== 400) fail("a wrong Host header got " + evil);

const services = await json("/api/services");
const group = services.find((g) => g.name === "This host");
const self = group?.services.find((s) => s.name === "Homepage");
if (self?.description !== "hello-from-an-env-file") fail("services: " + JSON.stringify(services));

const bookmarks = await json("/api/bookmarks");
if (!bookmarks.some((g) => g.name === "Conn3x" && g.bookmarks[0]?.name === "Docs")) fail("bookmarks: " + JSON.stringify(bookmarks));

const up = await json("/api/siteMonitor?groupName=This%20host&serviceName=Homepage");
if (up.status !== 200) fail("siteMonitor for Homepage: " + JSON.stringify(up));
const down = await fetch(u + "/api/siteMonitor?groupName=This%20host&serviceName=Closed");
const d = await down.json();
if (down.ok && d.status < 500) fail("siteMonitor for a closed port: " + JSON.stringify(d));

console.log("ok");
