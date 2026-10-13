import { z } from 'zod';
export const dateKey = (date = new Date()) => `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
export const parseDay = (date: string) => new Date(`${date}T12:00:00`);
export function shiftDay(date: string, days: number) { const d=parseDay(date); d.setDate(d.getDate()+days); return dateKey(d); }
export const daySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(d=>!Number.isNaN(parseDay(d).getTime()) && dateKey(parseDay(d))===d);
const idSchema = z.string().uuid();
export const habitSchema = z.object({
 id:idSchema, name:z.string().trim().min(1).max(100), description:z.string().max(300).default(''),
 icon:z.string().min(1).max(24), color:z.string().regex(/^#[\da-fA-F]{6}$/), group:z.string().trim().max(60).default(''),
 type:z.enum(['build','quit']), goal:z.number().finite().min(0).max(1000000000), unit:z.string().trim().max(30),
 period:z.enum(['day','week','month','custom']), periodDays:z.number().int().min(1).max(365),
 frequency:z.enum(['daily','weekdays','week-count','monthdays','month-count','cycle-days','cycle-count']),
 days:z.array(z.number().int().min(1).max(365)).max(365), targetDays:z.number().int().min(1).max(365), cycleDays:z.number().int().min(1).max(365),
 timeOfDay:z.enum(['any','morning','afternoon','evening']), reminders:z.array(z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)).max(10),
 memoAfter:z.boolean(), startDate:daySchema, endDate:daySchema.nullable(), archived:z.boolean().default(false), order:z.number().int().min(0).max(1000000)
}).superRefine((h,c)=>{
 if(h.type==='build' && h.goal<=0) c.addIssue({code:'custom',path:['goal'],message:'La meta debe ser mayor que cero.'});
 if(h.endDate && h.endDate<h.startDate) c.addIssue({code:'custom',path:['endDate'],message:'La fecha final debe ser posterior al inicio.'});
 const max=h.frequency==='weekdays'?7:h.frequency==='monthdays'?31:h.cycleDays;
 if(['weekdays','monthdays','cycle-days'].includes(h.frequency) && (!h.days.length || h.days.some(d=>d>max))) c.addIssue({code:'custom',path:['days'],message:'Selecciona días válidos.'});
 const targetMax=h.frequency==='week-count'?7:h.frequency==='month-count'?31:h.cycleDays;
 if(['week-count','month-count','cycle-count'].includes(h.frequency) && h.targetDays>targetMax) c.addIssue({code:'custom',path:['targetDays'],message:'La frecuencia supera los días del periodo.'});
});
export type Habit = z.infer<typeof habitSchema>;
export type Entry = {habitId:string;date:string;value:number;checked:boolean;note:string;mood:number|null;updatedAt:string};
export type Mood = {date:string;mood:number;note:string};
export type Snapshot = {habits:Habit[];entries:Entry[];moods:Mood[]};
export const mutationSchema = z.discriminatedUnion('op',[
 z.object({op:z.literal('habit'),habit:habitSchema}),
 z.object({op:z.literal('archive'),id:idSchema,archived:z.boolean()}),
 z.object({op:z.literal('entry'),id:idSchema,date:daySchema,mode:z.enum(['increment','set','check','clear','note']),value:z.number().finite().min(-1000000000).max(1000000000).optional(),checked:z.boolean().optional(),note:z.string().max(5000).optional(),mood:z.number().int().min(1).max(5).nullable().optional()}),
 z.object({op:z.literal('mood'),date:daySchema,mood:z.number().int().min(1).max(5),note:z.string().max(5000)})
]);
export type Mutation = z.infer<typeof mutationSchema>;
export const colors=['#FF5B86','#5CBAF0','#3BD6BE','#8D71E1','#F4B357','#EC88B5','#7895E0','#8FC77D','#7D8796','#D4A37C','#76C8D0','#F4756A'];
export const emojis=['⭐','🙏','📚','🧘','💧','🏃','💪','🚶','🛏️','🥗','🍎','🧠','🎨','🎹','🌱','☀️','📝','🦷','🏠','💻','💰','❤️','📵','🚭','☕','🐶','🎯','✨','🧹','🚴','🏊','🗣️'];
export const timeUnits=['sec','min','hr'];
export function blankHabit(order=0):Habit { return {id:crypto.randomUUID(),name:'',description:'',icon:'⭐',color:colors[0],group:'',type:'build',goal:1,unit:'veces',period:'day',periodDays:7,frequency:'daily',days:[1,2,3,4,5,6,7],targetDays:3,cycleDays:7,timeOfDay:'any',reminders:[],memoAfter:false,startDate:dateKey(),endDate:null,archived:false,order}; }
export function weekStart(date:string){const d=parseDay(date);return shiftDay(date,-((d.getDay()+6)%7));}
export function dayDifference(a:string,b:string){return Math.round((Date.UTC(...parts(a))-Date.UTC(...parts(b)))/86400000);}
function parts(d:string):[number,number,number]{const p=d.split('-').map(Number);return [p[0],p[1]-1,p[2]];}
export function inRange(h:Habit,date:string){return date>=h.startDate&&(!h.endDate||date<=h.endDate);}
export function scheduled(h:Habit,date:string){
 if(!inRange(h,date))return false;
 if(h.frequency==='weekdays')return h.days.includes((parseDay(date).getDay()+6)%7+1);
 if(h.frequency==='monthdays')return h.days.includes(parseDay(date).getDate());
 if(h.frequency==='cycle-days')return h.days.includes(dayDifference(date,h.startDate)%h.cycleDays+1);
 return true;
}
export function periodBounds(h:Habit,date:string):[string,string]{
 if(h.period==='week') {const start=weekStart(date);return [start,shiftDay(start,6)];}
 if(h.period==='month'){const d=parseDay(date);return [dateKey(new Date(d.getFullYear(),d.getMonth(),1)),dateKey(new Date(d.getFullYear(),d.getMonth()+1,0))];}
 if(h.period==='custom'){const offset=Math.floor(dayDifference(date,h.startDate)/h.periodDays)*h.periodDays;const start=shiftDay(h.startDate,offset);return [start,shiftDay(start,h.periodDays-1)];}
 return [date,date];
}
export function entryFor(entries:Entry[],id:string,date:string){return entries.find(e=>e.habitId===id&&e.date===date);}
export function progress(h:Habit,date:string,entries:Entry[]){const [start,end]=periodBounds(h,date);const rows=entries.filter(e=>e.habitId===h.id&&e.date>=start&&e.date<=end&&inRange(h,e.date));const value=rows.reduce((s,e)=>s+e.value,0);const checked=rows.some(e=>e.checked);const done=h.type==='quit'?checked&&value<=h.goal:value>=h.goal||checked;return {value,done,ratio:done?1:h.type==='quit'?0:Math.min(1,value/h.goal)};}
export function percentage(habits:Habit[],entries:Entry[],date:string){const list=habits.filter(h=>scheduled(h,date));if(!list.length)return 0;return list.reduce((s,h)=>s+progress(h,date,entries).ratio,0)/list.length;}
export function streaks(h:Habit,entries:Entry[],today:string){
 const blocks=new Map<string,{done:boolean;end:string}>();
 const quota=h.period==='day'&&['week-count','month-count','cycle-count'].includes(h.frequency);
 if(quota){
  const counts=new Map<string,{completed:number;end:string}>();
  for(let d=h.startDate;d<=today;d=shiftDay(d,1)){
   if(!scheduled(h,d))continue;
   let start:string,end:string;
   if(h.frequency==='week-count'){start=weekStart(d);end=shiftDay(start,6);}
   else if(h.frequency==='month-count'){start=d.slice(0,7)+'-01';const x=parseDay(d);end=dateKey(new Date(x.getFullYear(),x.getMonth()+1,0));}
   else{start=shiftDay(h.startDate,Math.floor(dayDifference(d,h.startDate)/h.cycleDays)*h.cycleDays);end=shiftDay(start,h.cycleDays-1);}
   const b=counts.get(start)||{completed:0,end};if(progress(h,d,entries).done)b.completed++;counts.set(start,b);
  }
  for(const [key,b] of counts)blocks.set(key,{done:b.completed>=h.targetDays,end:b.end});
 }else{
  for(let d=h.startDate;d<=today;d=shiftDay(d,1)){
   if(!scheduled(h,d))continue;const [key,end]=periodBounds(h,d);if(!blocks.has(key))blocks.set(key,{done:progress(h,d,entries).done,end});
  }
 }
 let best=0,run=0;for(const b of blocks.values()){if(b.done){run++;best=Math.max(best,run);}else if(b.end<today)run=0;}
 return {best,current:run};
}
export function prettyNumber(n:number){return new Intl.NumberFormat('es-CO',{maximumFractionDigits:2}).format(n);}
export function goalLabel(h:Habit){return `${prettyNumber(h.goal)} ${h.unit}${h.unit?' ':''}/ ${h.period==='day'?'día':h.period==='week'?'semana':h.period==='month'?'mes':`${h.periodDays} días`}`;}
export function rangeStats(h:Habit,entries:Entry[],start:string,end:string){
 const slots=new Map<string,boolean>();for(let d=start;d<=end;d=shiftDay(d,1)){if(scheduled(h,d)){const key=periodBounds(h,d)[0];slots.set(key,progress(h,d,entries).done);}}
 let total=slots.size,done=[...slots.values()].filter(Boolean).length;
 if(h.period==='day' && ['week-count','month-count','cycle-count'].includes(h.frequency)){
  const blocks=new Map<string,{days:number;done:number}>();for(let d=start;d<=end;d=shiftDay(d,1)){if(!scheduled(h,d))continue;const key=h.frequency==='week-count'?weekStart(d):h.frequency==='month-count'?d.slice(0,7):String(Math.floor(dayDifference(d,h.startDate)/h.cycleDays));const b=blocks.get(key)||{days:0,done:0};b.days++;if(progress(h,d,entries).done)b.done++;blocks.set(key,b);}
  total=0;done=0;for(const b of blocks.values()){const quota=Math.min(h.targetDays,b.days);total+=quota;done+=Math.min(quota,b.done);}
 }return {total,done,rate:total?done/total:0};
}
