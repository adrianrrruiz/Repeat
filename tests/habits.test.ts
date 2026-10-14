import test from 'node:test';
import assert from 'node:assert/strict';
import { blankHabit, habitSchema, scheduled, progress, rangeStats, streaks, shiftDay, weekStart, type Entry } from '../lib/habits.ts';
const habit=()=>({...blankHabit(),name:'Leer',goal:30,unit:'min',startDate:'2026-10-01'});
const entry=(date:string,value:number,id:string,checked=false):Entry=>({habitId:id,date,value,checked,note:'',mood:null,updatedAt:'2026-10-13T00:00:00Z'});
test('repeticiones y días de semana respetan fecha inicial y final',()=>{const h={...habit(),frequency:'weekdays' as const,days:[1,3,5],endDate:'2026-10-20'};assert.equal(scheduled(h,'2026-10-12'),true);assert.equal(scheduled(h,'2026-10-13'),false);assert.equal(scheduled(h,'2026-10-21'),false);assert.equal(scheduled(h,'2026-09-30'),false);});
test('meta semanal suma cantidades de varios días y se reinicia',()=>{const h={...habit(),goal:60,period:'week' as const};const es=[entry('2026-10-12',20,h.id),entry('2026-10-13',40,h.id),entry('2026-10-19',15,h.id)];assert.equal(progress(h,'2026-10-13',es).value,60);assert.equal(progress(h,'2026-10-13',es).done,true);assert.equal(progress(h,'2026-10-19',es).done,false);});
test('evitar un hábito requiere confirmación explícita, incluso con límite cero',()=>{const h={...habit(),type:'quit' as const,goal:0};assert.equal(progress(h,'2026-10-13',[]).done,false);assert.equal(progress(h,'2026-10-13',[entry('2026-10-13',0,h.id,true)]).done,true);assert.equal(progress(h,'2026-10-13',[entry('2026-10-13',1,h.id,true)]).done,false);});
test('días por semana usan la cuota y no siete metas en el informe',()=>{const h={...habit(),frequency:'week-count' as const,targetDays:3};const es=['2026-10-12','2026-10-13','2026-10-14','2026-10-15'].map(d=>entry(d,30,h.id));const s=rangeStats(h,es,'2026-10-12','2026-10-18');assert.equal(s.total,3);assert.equal(s.done,3);assert.equal(s.rate,1);});
test('una racha omite los días que no estaban programados',()=>{const h={...habit(),startDate:'2026-10-09',frequency:'weekdays' as const,days:[1,5]};const es=['2026-10-09','2026-10-12'].map(d=>entry(d,30,h.id));assert.deepEqual(streaks(h,es,'2026-10-13'),{best:2,current:2});});
test('ciclos se calculan desde el día inicial',()=>{const h={...habit(),frequency:'cycle-days' as const,cycleDays:3,days:[1]};assert.equal(scheduled(h,'2026-10-01'),true);assert.equal(scheduled(h,'2026-10-02'),false);assert.equal(scheduled(h,'2026-10-04'),true);assert.equal(weekStart('2026-10-13'),'2026-10-12');assert.equal(shiftDay('2026-12-31',1),'2027-01-01');});
test('validación rechaza fechas inválidas, cuota imposible y meta vacía',()=>{assert.equal(habitSchema.safeParse({...habit(),startDate:'2026-02-30'}).success,false);assert.equal(habitSchema.safeParse({...habit(),frequency:'week-count',targetDays:8}).success,false);assert.equal(habitSchema.safeParse({...habit(),goal:0}).success,false);});

test('una semana en curso no rompe una racha semanal anterior',()=>{const h={...habit(),startDate:'2026-10-05',period:'week' as const,goal:60};const es=[entry('2026-10-05',60,h.id)];assert.deepEqual(streaks(h,es,'2026-10-13'),{best:1,current:1});});
test('frecuencia de tres días semanales mide rachas por semana',()=>{const h={...habit(),startDate:'2026-10-05',frequency:'week-count' as const,targetDays:3};const es=['2026-10-05','2026-10-07','2026-10-09','2026-10-12'].map(d=>entry(d,30,h.id));assert.deepEqual(streaks(h,es,'2026-10-13'),{best:1,current:1});});

test('saltar un día conserva racha y lo excluye del informe',()=>{
 const h={...blankHabit(0),startDate:'2026-10-10',goal:1};
 const entries=['2026-10-10','2026-10-11','2026-10-12'].map(date=>({habitId:h.id,date,value:1,checked:false,note:'',mood:null,updatedAt:''}));
 const skipped=[...entries,{habitId:h.id,date:'2026-10-13',value:0,checked:false,skipped:true,note:'',mood:null,updatedAt:''}];
 assert.equal(streaks(h,skipped,'2026-10-14').current,3);
 assert.equal(rangeStats(h,skipped,'2026-10-10','2026-10-13').total,3);
});
