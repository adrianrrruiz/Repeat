import { z } from 'zod';
import { env } from 'cloudflare:workers';
import { getChatGPTUser } from '../../chatgpt-auth';
import { mutationSchema, type Habit } from '@/lib/habits';
export const dynamic='force-dynamic';
const response=(data:unknown,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'no-store'}});
async function snapshot(userId:string){
 const db=env.DB!;
 const [habits,entries,moods]=await db.batch([
  db.prepare('SELECT content FROM habits WHERE user_id=?').bind(userId),
  db.prepare('SELECT habit_id AS habitId,date,value,checked,note,mood,updated_at AS updatedAt FROM entries WHERE user_id=?').bind(userId),
  db.prepare('SELECT date,mood,note FROM moods WHERE user_id=?').bind(userId)
 ]);
 return {habits:(habits.results as {content:string}[]).map(r=>JSON.parse(r.content) as Habit).sort((a,b)=>a.order-b.order),entries:(entries.results as Record<string,unknown>[]).map(r=>({...r,checked:!!r.checked})),moods:moods.results};
}
export async function GET(){
 const user=await getChatGPTUser();if(!user)return response({error:'Inicia sesión para ver tus hábitos.'},401);
 try{return response(await snapshot(user.userId));}catch{return response({error:'No pudimos cargar tus hábitos. Inténtalo de nuevo.'},503);}
}
export async function POST(request:Request){
 const user=await getChatGPTUser();if(!user)return response({error:'Tu sesión terminó. Inicia sesión de nuevo.'},401);
 const origin=request.headers.get('origin');if(!origin||origin!==new URL(request.url).origin)return response({error:'Origen no permitido.'},403);
 if(Number(request.headers.get('content-length')||0)>20000)return response({error:'Solicitud demasiado grande.'},413);
 let body:unknown;try{const raw=await request.text();if(raw.length>20000)return response({error:'Solicitud demasiado grande.'},413);body=JSON.parse(raw);}catch{return response({error:'Solicitud inválida.'},400);}
 const parsed=mutationSchema.safeParse(body);if(!parsed.success)return response({error:parsed.error.issues[0]?.message||'Revisa los datos.'},400);
 const m=parsed.data;const rid=z.string().uuid().safeParse(body && typeof body==='object' ? (body as {requestId?:unknown}).requestId : undefined);if(m.op==='entry'&&m.mode==='increment'&&!rid.success)return response({error:'Identificador de registro inválido.'},400);const db=env.DB; if(!db)return response({error:'La sincronización no está disponible.'},503);
 const uid=user.userId,now=new Date().toISOString();
 try{
  if(m.op==='habit')await db.prepare('INSERT INTO habits(user_id,id,content,updated_at) VALUES(?,?,?,?) ON CONFLICT(user_id,id) DO UPDATE SET content=excluded.content,updated_at=excluded.updated_at').bind(uid,m.habit.id,JSON.stringify(m.habit),now).run();
  else if(m.op==='mood')await db.prepare('INSERT INTO moods(user_id,date,mood,note) VALUES(?,?,?,?) ON CONFLICT(user_id,date) DO UPDATE SET mood=excluded.mood,note=excluded.note').bind(uid,m.date,m.mood,m.note).run();
  else{
   const row=await db.prepare('SELECT content FROM habits WHERE user_id=? AND id=?').bind(uid,m.id).first<{content:string}>();if(!row)return response({error:'No encontramos ese hábito.'},404);
   const h=JSON.parse(row.content) as Habit;
   if(m.op==='archive'){h.archived=m.archived;await db.prepare('UPDATE habits SET content=?,updated_at=? WHERE user_id=? AND id=?').bind(JSON.stringify(h),now,uid,m.id).run();}
   else{
    if(m.mode==='clear')await db.prepare('UPDATE entries SET value=0,checked=0 WHERE user_id=? AND habit_id=? AND date=?').bind(uid,m.id,m.date).run();
    else if(m.mode==='note')await db.prepare('INSERT INTO entries(user_id,habit_id,date,note,mood,updated_at) VALUES(?,?,?,?,?,?) ON CONFLICT(user_id,habit_id,date) DO UPDATE SET note=excluded.note,mood=excluded.mood,updated_at=excluded.updated_at').bind(uid,m.id,m.date,m.note??'',m.mood??null,now).run();
    else if(m.mode==='check')await db.prepare('INSERT INTO entries(user_id,habit_id,date,checked,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(user_id,habit_id,date) DO UPDATE SET checked=excluded.checked,updated_at=excluded.updated_at').bind(uid,m.id,m.date,m.checked?1:0,now).run();
    else{
     if(m.value===undefined || (m.mode==='set'&&m.value<0))return response({error:'Ingresa un valor válido.'},400);
     const value=Math.max(0,m.value);
     if(m.mode==='increment'&&rid.success){
      const guard='NOT EXISTS(SELECT 1 FROM operation_receipts WHERE user_id=? AND request_id=?)';
      await db.batch([
       db.prepare(`INSERT INTO entries(user_id,habit_id,date,value,updated_at) SELECT ?,?,?,?,? WHERE ${guard} ON CONFLICT(user_id,habit_id,date) DO UPDATE SET value=MIN(1000000000,MAX(0,entries.value+?)),checked=0,updated_at=excluded.updated_at WHERE ${guard}`).bind(uid,m.id,m.date,value,now,uid,rid.data,m.value,uid,rid.data),
       db.prepare('INSERT OR IGNORE INTO operation_receipts(user_id,request_id,created_at) VALUES(?,?,?)').bind(uid,rid.data,now)
      ]);
     }else await db.prepare('INSERT INTO entries(user_id,habit_id,date,value,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(user_id,habit_id,date) DO UPDATE SET value=excluded.value,checked=0,updated_at=excluded.updated_at').bind(uid,m.id,m.date,value,now).run();
    }
   }
  }
  return response(await snapshot(uid));
 }catch{return response({error:'No pudimos guardar el cambio. Tu información anterior sigue guardada.'},503);}
}
