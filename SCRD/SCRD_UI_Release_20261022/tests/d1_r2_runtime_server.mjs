import { webcrypto } from 'node:crypto';
if (!globalThis.crypto) globalThis.crypto = webcrypto;
/**
 * Local Cloudflare Worker + D1 (SQLite) + R2 + Static Assets Runtime Server
 * Runs both SCRD (`backend_worker.js` on port 8787) and EXAM (`EXAM/src/index.js` on port 8788)
 * against a shared SQLite database initialized from `d1_schema_migration.sql`.
 */

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

// Polyfill global File for Node 18 if needed
if (typeof globalThis.File === 'undefined') {
  globalThis.File = class File extends Blob {
    constructor(parts, name, options = {}) {
      super(parts, options);
      this.name = String(name || 'file');
      this.lastModified = options.lastModified || Date.now();
    }
  };
}

// Persistent Python SQLite Bridge for D1 API compatibility
class SqliteBridge {
  constructor(dbPath, schemaPath) {
    this.proc = spawn('python3', ['-u', '-c', `
import sys, json, sqlite3

db_path = sys.argv[1]
schema_path = sys.argv[2]
conn = sqlite3.connect(db_path, isolation_level=None)
conn.row_factory = sqlite3.Row
conn.execute("PRAGMA foreign_keys = ON;")
with open(schema_path, "r", encoding="utf-8") as f:
    conn.executescript(f.read())

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    req = json.loads(line)
    req_id = req.get("id")
    mode = req.get("mode")
    try:
        cur = conn.cursor()
        if mode == "first":
            cur.execute(req["sql"], req.get("params", []))
            row = cur.fetchone()
            res = dict(row) if row else None
            print(json.dumps({"id": req_id, "ok": True, "data": res}), flush=True)
        elif mode == "all":
            cur.execute(req["sql"], req.get("params", []))
            rows = [dict(r) for r in cur.fetchall()]
            print(json.dumps({"id": req_id, "ok": True, "data": {"results": rows}}), flush=True)
        elif mode == "run":
            cur.execute(req["sql"], req.get("params", []))
            print(json.dumps({"id": req_id, "ok": True, "data": {"success": True, "meta": {"changes": cur.rowcount, "last_row_id": cur.lastrowid}}}), flush=True)
        elif mode == "batch":
            cur.execute("BEGIN")
            out = []
            try:
                for st in req.get("statements", []):
                    cur.execute(st["sql"], st.get("params", []))
                    if st["sql"].strip().upper().startswith("SELECT"):
                        rows = [dict(r) for r in cur.fetchall()]
                        out.append({"results": rows, "success": True, "meta": {"changes": 0}})
                    else:
                        out.append({"results": [], "success": True, "meta": {"changes": cur.rowcount, "last_row_id": cur.lastrowid}})
                cur.execute("COMMIT")
                print(json.dumps({"id": req_id, "ok": True, "data": out}), flush=True)
            except Exception as be:
                cur.execute("ROLLBACK")
                raise be
    except Exception as e:
        print(json.dumps({"id": req_id, "ok": False, "error": str(e)}), flush=True)
`, dbPath, schemaPath], { stdio: ['pipe', 'pipe', 'inherit'] });

    this.seq = 0;
    this.pending = new Map();
    this.buffer = '';
    this.proc.stdout.on('data', chunk => {
      this.buffer += chunk.toString('utf8');
      let idx;
      while ((idx = this.buffer.indexOf('\n')) !== -1) {
        const line = this.buffer.slice(0, idx).trim();
        this.buffer = this.buffer.slice(idx + 1);
        if (!line) continue;
        const msg = JSON.parse(line);
        const handler = this.pending.get(msg.id);
        if (handler) {
          this.pending.delete(msg.id);
          if (msg.ok) handler.resolve(msg.data);
          else handler.reject(new Error(msg.error));
        }
      }
    });
  }

  call(payload) {
    const id = ++this.seq;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.proc.stdin.write(JSON.stringify({ id, ...payload }) + '\n');
    });
  }

  close() {
    try { this.proc.kill(); } catch {}
  }
}

class D1PreparedStatement {
  constructor(bridge, sql, params = []) {
    this.bridge = bridge;
    this.sql = sql;
    this.params = params.map(v => (v === undefined ? null : v));
  }
  bind(...params) {
    return new D1PreparedStatement(this.bridge, this.sql, params);
  }
  first() {
    return this.bridge.call({ mode: 'first', sql: this.sql, params: this.params });
  }
  all() {
    return this.bridge.call({ mode: 'all', sql: this.sql, params: this.params });
  }
  run() {
    return this.bridge.call({ mode: 'run', sql: this.sql, params: this.params });
  }
}

export function createD1Database(dbPath = ':memory:', schemaPath = path.join(ROOT_DIR, 'd1_schema_migration.sql')) {
  const bridge = new SqliteBridge(dbPath, schemaPath);
  return {
    prepare(sql) {
      return new D1PreparedStatement(bridge, sql);
    },
    batch(statements) {
      return bridge.call({
        mode: 'batch',
        statements: statements.map(s => ({ sql: s.sql, params: s.params }))
      });
    },
    close() {
      bridge.close();
    }
  };
}

export function createR2Bucket() {
  const store = new Map();
  return {
    async put(key, value, options = {}) {
      let buf;
      if (value instanceof ArrayBuffer) {
        buf = Buffer.from(value);
      } else if (ArrayBuffer.isView(value)) {
        buf = Buffer.from(value.buffer, value.byteOffset, value.byteLength);
      } else if (typeof value === 'string') {
        buf = Buffer.from(value, 'utf8');
      } else if (value && typeof value.getReader === 'function') {
        const reader = value.getReader();
        const chunks = [];
        while (true) {
          const { done, value: chunk } = await reader.read();
          if (done) break;
          chunks.push(Buffer.from(chunk));
        }
        buf = Buffer.concat(chunks);
      } else {
        buf = Buffer.from([]);
      }
      store.set(key, { body: buf, options, uploadedAt: new Date().toISOString() });
      return { key, size: buf.length };
    },
    async get(key) {
      const item = store.get(key);
      if (!item) return null;
      return {
        key,
        size: item.body.length,
        body: new Uint8Array(item.body),
        httpMetadata: item.options?.httpMetadata || {}
      };
    },
    async head(key) {
      const item = store.get(key);
      return item ? { key, size: item.body.length } : null;
    },
    async delete(key) {
      store.delete(key);
    },
    _store: store
  };
}

export function createAssetsBinding(publicDir) {
  const mimeMap = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.json': 'application/json; charset=utf-8'
  };
  return {
    async fetch(request) {
      const url = new URL(request.url);
      let relPath = decodeURIComponent(url.pathname);
      if (relPath === '/yeu-cau-cap-tai-khoan') {
        return Response.redirect(new URL('/dang-ky', url.origin).href, 301);
      }
      if (relPath === '/tra-cuu-yeu-cau') {
        return Response.redirect(new URL('/tra-cuu', url.origin).href, 301);
      }
      if (relPath === '/') relPath = '/index.html';
      let fullPath = path.join(publicDir, relPath);
      if (!fullPath.startsWith(publicDir)) {
        return new Response('Forbidden', { status: 403 });
      }
      if (!fs.existsSync(fullPath) || fs.statSync(fullPath).isDirectory()) {
        // SPA Fallback
        fullPath = path.join(publicDir, 'index.html');
      }
      const ext = path.extname(fullPath).toLowerCase();
      const body = fs.readFileSync(fullPath);
      return new Response(body, {
        status: 200,
        headers: {
          'Content-Type': mimeMap[ext] || 'application/octet-stream',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'SAMEORIGIN',
          'Referrer-Policy': 'strict-origin-when-cross-origin'
        }
      });
    }
  };
}

// Start HTTP Server wrapping a Cloudflare Worker
export function startWorkerHttpServer(workerModule, env, port) {
  const server = http.createServer(async (req, res) => {
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const bodyBuf = Buffer.concat(chunks);
      const fullUrl = `http://127.0.0.1:${port}${req.url}`;
      const headers = new Headers();
      for (const [k, v] of Object.entries(req.headers)) {
        if (Array.isArray(v)) headers.set(k, v.join(', '));
        else if (v !== undefined) headers.set(k, v);
      }
      const init = {
        method: req.method,
        headers
      };
      if (!['GET', 'HEAD'].includes(req.method) && bodyBuf.length > 0) {
        init.body = bodyBuf;
      }
      const webReq = new Request(fullUrl, init);
      const webResp = await workerModule.fetch(webReq, env, { waitUntil() {} });
      res.statusCode = webResp.status;
      webResp.headers.forEach((val, key) => {
        res.setHeader(key, val);
      });
      const respBuf = Buffer.from(await webResp.arrayBuffer());
      res.end(respBuf);
    } catch (err) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ ok: false, error: 'Server error' }));
    }
  });
  return new Promise(resolve => {
    server.listen(port, '127.0.0.1', () => resolve(server));
  });
}

// If invoked directly with `--serve`, run SCRD on 8787 and EXAM on 8788
if (process.argv.includes('--serve')) {
  const scrdWorker = (await import(path.join(ROOT_DIR, 'backend_worker.js'))).default;
  const examWorker = (await import(path.join(ROOT_DIR, 'EXAM', 'src', 'index.js'))).default;
  const dbPath = process.env.TEST_SQLITE_PATH || ':memory:';
  const DB = createD1Database(dbPath);
  const FILES = createR2Bucket();
  const scrdEnv = {
    DB,
    FILES,
    ASSETS: createAssetsBinding(path.join(ROOT_DIR, 'public')),
    BOOTSTRAP_SECRET_TOKEN: process.env.BOOTSTRAP_SECRET_TOKEN || 'ProdTest_Bootstrap_Secret_2026_UniqueKey_998877!',
    ID_ENCRYPTION_KEY: process.env.ID_ENCRYPTION_KEY || 'ProdTest_AES256GCM_SecretKey_2026_998877665544!',
    EXAM_PORTAL_URL: 'http://127.0.0.1:8788'
  };
  const examEnv = {
    DB,
    FILES,
    ASSETS: createAssetsBinding(path.join(ROOT_DIR, 'EXAM', 'public')),
    CONTROL_ORIGIN: 'http://127.0.0.1:8787'
  };
  await startWorkerHttpServer(scrdWorker, scrdEnv, 8787);
  await startWorkerHttpServer(examWorker, examEnv, 8788);
  console.log('SERVERS_READY 8787 8788');
}
