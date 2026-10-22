export async function onRequestGet() {
  let dependency = 'unavailable';
  try {
    const r = await fetch('https://scrd.skyfirst.io.vn/api/health', { headers: { accept: 'application/json' } });
    if (r.ok) dependency = 'available';
  } catch {}
  return Response.json({
    ok: dependency === 'available',
    service: 'Sky First Exam',
    version: '2026.10.22' ,
    status: dependency === 'available' ? 'available' : 'degraded',
    dependency: { scrd: dependency },
    time: new Date().toISOString()
  }, {
    status: dependency === 'available' ? 200 : 503,
    headers: { 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' }
  });
}
