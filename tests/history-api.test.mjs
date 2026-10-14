import test from 'node:test';
import assert from 'node:assert/strict';
import { blankHabit, preserveMetricHistory, progress } from '../lib/habits.ts';
const base = process.env.REPEAT_TEST_URL || 'http://127.0.0.1:5173';
if (!['127.0.0.1','localhost','[::1]'].includes(new URL(base).hostname)) throw new Error('Estas pruebas solo se ejecutan contra el servidor local.');
test('API local: editar una meta conserva historial, registros y compatibilidad', async () => {
 const signed = await fetch(base + '/signin-with-chatgpt?return_to=%2F', { redirect:'manual' });
 const cookie = signed.headers.get('set-cookie')?.split(';')[0]; assert.ok(cookie);
 async function post(body) {
  const response = await fetch(base + '/api/state', { method:'POST', headers:{ Cookie:cookie, 'Content-Type':'application/json', Origin:base }, body:JSON.stringify({ ...body, requestId:crypto.randomUUID() }) });
  return { status:response.status, data:await response.json() };
 }
 const h = { ...blankHabit(), name:'Prueba API historial', goal:20, unit:'min', startDate:'2026-10-01' };
 try {
  assert.equal((await post({ op:'habit', habit:h })).status,200);
  assert.equal((await post({ op:'entry', id:h.id, date:'2026-10-13', mode:'set', value:20 })).status,200);
  const updated = preserveMetricHistory({ ...h, goal:30 }, h, '2026-10-14');
  const saved = await post({ op:'habit', habit:updated }); assert.equal(saved.status,200);
  assert.deepEqual(saved.data.habits.find(x=>x.id===h.id).metricHistory,updated.metricHistory);
  assert.equal(progress(saved.data.habits.find(x=>x.id===h.id),'2026-10-13',saved.data.entries).done,true);
  const reload = await fetch(base+'/api/state',{ headers:{ Cookie:cookie } }); assert.equal(reload.status,200);
  assert.deepEqual((await reload.json()).habits.find(x=>x.id===h.id).metricHistory,updated.metricHistory);
  const older = { ...updated, name:'Renombrado desde cliente anterior' }; delete older.metricHistory;
  const renamed = await post({ op:'habit', habit:older }); assert.equal(renamed.status,200);
  assert.deepEqual(renamed.data.habits.find(x=>x.id===h.id).metricHistory,updated.metricHistory);
  assert.equal((await post({ op:'habit', habit:{ ...older, goal:40 } })).status,409);
 } finally { assert.equal((await post({ op:'delete', id:h.id })).status,200); }
});
