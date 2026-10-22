import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { webcrypto } from 'node:crypto';
import scrd from '../backend_worker.js';
import exam from '../EXAM/src/index.js';
import { createD1Database, createR2Bucket, createAssetsBinding } from './d1_r2_runtime_server.mjs';
if (!globalThis.crypto) globalThis.crypto = webcrypto;
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const DB=createD1Database(':memory:',path.join(ROOT,'d1_schema_migration.sql'));
const FILES=createR2Bucket();
const scrdEnv={DB,FILES,ASSETS:createAssetsBinding(path.join(ROOT,'public')),BOOTSTRAP_SECRET_TOKEN:'Integration-bootstrap-secret-2026-long-enough',ID_ENCRYPTION_KEY:'Integration-identity-encryption-key-2026-long',EXAM_PORTAL_URL:'https://exam.skyfirst.io.vn'};
const examEnv={DB,FILES,ASSETS:createAssetsBinding(path.join(ROOT,'EXAM','public')),CONTROL_ORIGIN:'https://scrd.skyfirst.io.vn'};
let passes=0;
async function callWorker(worker,origin,pathName,{method='GET',body,headers={}}={}){const h=new Headers(headers);if(body!==undefined)h.set('Content-Type','application/json');const req=new Request(origin+pathName,{method,headers:h,body:body===undefined?undefined:JSON.stringify(body)});const res=await worker.fetch(req,worker===scrd?scrdEnv:examEnv);const ct=res.headers.get('content-type')||'';return {res,data:ct.includes('json')?await res.json():await res.text()}}
async function check(name,fn){await fn();passes++;console.log(`PASS ${passes}: ${name}`)}
try{
  await check('SCRD first-admin bootstrap and authentication support real Exam launch',async()=>{
    const init=await callWorker(scrd,'https://scrd.skyfirst.io.vn','/api/bootstrap/init',{method:'POST',headers:{'X-Bootstrap-Token':scrdEnv.BOOTSTRAP_SECRET_TOKEN},body:{email:'admin@integration.test',full_name:'Integration Admin',password:'IntegrationAdminPass123!'}});assert.equal(init.res.status,201,JSON.stringify(init.data));
  });
  const login=await callWorker(scrd,'https://scrd.skyfirst.io.vn','/api/auth/login',{method:'POST',body:{email:'admin@integration.test',password:'IntegrationAdminPass123!'}});
  assert.equal(login.res.status,200,JSON.stringify(login.data));
  const auth={Authorization:`Bearer ${login.data.token}`,'X-CSRF-Token':login.data.csrf_token};
  const examId='exam-integration-internal';
  await DB.prepare(`INSERT INTO exams(id,code,title,title_en,duration_minutes,time_limit_enabled,show_score,pass_score,status,question_json,created_at,updated_at) VALUES(?,?,?,?,60,1,1,70,'published',?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`).bind(examId,'INTEGRATION-EXAM','Bài kiểm tra tích hợp','Integration exam',JSON.stringify([{id:'q1',type:'mcq',question:'2+2?',options:['3','4'],answer:'4',points:1}])).run();
  const started=await callWorker(scrd,'https://scrd.skyfirst.io.vn',`/api/exams/${examId}/start`,{method:'POST',headers:auth,body:{}});assert.equal(started.res.status,201,JSON.stringify(started.data));
  const launchToken=new URL(started.data.launch_url).searchParams.get('launch');assert.ok(launchToken);
  await check('one-time SCRD launch token redeems at EXAM and issues a short-lived access token',async()=>{
    const redeem=await callWorker(exam,'https://exam.skyfirst.io.vn','/api/public/exam-launch/redeem',{method:'POST',body:{launch_token:launchToken}});assert.equal(redeem.res.status,200,JSON.stringify(redeem.data));assert.ok(redeem.data.access_token);assert.equal(redeem.data.attempt_id,started.data.attempt_id);
    const replay=await callWorker(exam,'https://exam.skyfirst.io.vn','/api/public/exam-launch/redeem',{method:'POST',body:{launch_token:launchToken}});assert.equal(replay.res.status,401);
    started.data.access_token=redeem.data.access_token;
  });
  const session={Authorization:`Bearer ${started.data.access_token}`,'X-Exam-Session':'integration-session-000001'};
  let loaded;
  await check('Exam runtime reads attempt directly from shared D1 without exposing answers',async()=>{
    loaded=await callWorker(exam,'https://exam.skyfirst.io.vn',`/api/exam-attempts/${started.data.attempt_id}`,{headers:session});assert.equal(loaded.res.status,200,JSON.stringify(loaded.data));assert.equal(loaded.data.exam.questions[0].answer,undefined);assert.equal(loaded.data.exam.questions.length,1);
  });
  let saved;
  await check('revisioned autosave and server-authoritative scoring/receipt work end-to-end',async()=>{
    saved=await callWorker(exam,'https://exam.skyfirst.io.vn',`/api/exam-attempts/${started.data.attempt_id}/save`,{method:'POST',headers:session,body:{answers:{q1:'4'},events:[],revision:loaded.data.answer_revision}});assert.equal(saved.res.status,200,JSON.stringify(saved.data));
    const done=await callWorker(exam,'https://exam.skyfirst.io.vn',`/api/exam-attempts/${started.data.attempt_id}/submit`,{method:'POST',headers:session,body:{answers:{q1:'4'},events:[],revision:saved.data.answer_revision}});assert.equal(done.res.status,200,JSON.stringify(done.data));assert.equal(done.data.score,1);assert.ok(done.data.receipt_code);
    const repeat=await callWorker(exam,'https://exam.skyfirst.io.vn',`/api/exam-attempts/${started.data.attempt_id}/submit`,{method:'POST',headers:session,body:{answers:{q1:'3'},revision:saved.data.answer_revision}});assert.equal(repeat.res.status,200);assert.equal(repeat.data.receipt_code,done.data.receipt_code);assert.equal(repeat.data.score,1);
  });
  await check('Exam reports runtime health against shared schema',async()=>{
    const h=await callWorker(exam,'https://exam.skyfirst.io.vn','/health');assert.equal(h.res.status,200,JSON.stringify(h.data));assert.equal(h.data.runtime.attempt_api,'local-d1');
  });
  console.log(`SCRD ↔ EXAM INTEGRATION: ${passes}/${passes} PASS`);
}catch(e){console.error(`FAIL after ${passes} passed checks:`,e?.stack||e);process.exitCode=1}finally{DB.close()}
