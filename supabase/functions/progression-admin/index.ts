import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.95.0'

const url = Deno.env.get('SUPABASE_URL')!
function secretKey() {
  const s = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (s) return JSON.parse(s).default
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
}
function publishableKey() {
  const s = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
  if (s) return JSON.parse(s).default
  return Deno.env.get('SUPABASE_ANON_KEY')!
}
const admin = createClient(url, secretKey(), { auth: { persistSession: false } })

async function requireAdmin(req: Request) {
  const auth = req.headers.get('authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return { error: new Response(JSON.stringify({ error: 'Authentication required' }), { status: 401, headers: { 'content-type':'application/json' } }) }
  const { data, error } = await admin.auth.getUser(token)
  const user = data?.user
  if (error || !user) return { error: new Response(JSON.stringify({ error: 'Invalid session' }), { status: 401, headers: { 'content-type':'application/json' } }) }
  const isAdmin = user.app_metadata?.role === 'admin' || user.app_metadata?.is_admin === true
  if (!isAdmin) return { error: new Response(JSON.stringify({ error: 'Admin role required', hint: 'Set app_metadata.role=admin for the reviewer account.' }), { status: 403, headers: { 'content-type':'application/json' } }) }
  return { user }
}

async function profilesFor(ids: number[]) {
  if (!ids.length) return {}
  const { data, error } = await admin.from('exercise_knowledge_view').select('*').in('exercise_id', ids)
  if (error) throw error
  return Object.fromEntries((data || []).map((x:any) => [x.exercise_id, x]))
}

async function api(req: Request) {
  const guard = await requireAdmin(req)
  if ('error' in guard) return guard.error
  const body = await req.json().catch(() => ({}))
  const action = body.action || 'list'

  if (action === 'list') {
    let q = admin.from('exercise_relationships').select('*').order('confidence', { ascending: false }).order('id')
    if (body.status && body.status !== 'ALL') q = q.eq('review_status', body.status)
    if (body.type && body.type !== 'ALL') q = q.eq('relationship_type', body.type)
    const { data, error } = await q.limit(300)
    if (error) throw error
    const edges = data || []
    const ids = [...new Set(edges.flatMap((e:any) => [e.from_exercise_id, e.to_exercise_id]))]
    const profiles = await profilesFor(ids as number[])
    const filtered = edges.filter((e:any) => {
      const f:any = profiles[e.from_exercise_id], t:any = profiles[e.to_exercise_id]
      return !body.family || body.family === 'ALL' || f?.movement_family === body.family || t?.movement_family === body.family
    })
    return Response.json({ edges: filtered, profiles })
  }

  if (action === 'review') {
    const reviewAction = String(body.review_action || '').toUpperCase()
    const { data, error } = await admin.rpc('review_exercise_relationship', {
      p_relationship_id: body.relationship_id,
      p_action: reviewAction,
      p_reviewer: guard.user!.id,
      p_patch: body.patch || {},
      p_rejection_reason: body.rejection_reason || null,
    })
    if (error) throw error
    return Response.json({ ok: true, relationship: data })
  }

  if (action === 'graph') {
    const { data: edges, error } = await admin.from('exercise_relationships').select('*').in('review_status', body.include_pending ? ['AUTO_SUGGESTED','REVIEWED'] : ['REVIEWED']).limit(500)
    if (error) throw error
    const ids = [...new Set((edges || []).flatMap((e:any) => [e.from_exercise_id, e.to_exercise_id]))]
    const profiles = await profilesFor(ids as number[])
    return Response.json({ edges: edges || [], profiles })
  }

  if (action === 'validation') {
    const { data, error } = await admin.from('exercise_graph_validation').select('*').limit(500)
    if (error) throw error
    return Response.json({ issues: data || [] })
  }

  if (action === 'stats') {
    const { data: edges, error: e1 } = await admin.from('exercise_relationships').select('review_status,relationship_type')
    if (e1) throw e1
    const { data: p, error: e2 } = await admin.from('rehab_exercise_metadata').select('movement_family,classification_status').in('movement_family',['GLUTE','HIP'])
    if (e2) throw e2
    const stats:any = { profiles: p?.length || 0, by_status:{}, by_type:{} }
    for (const e of edges || []) {
      stats.by_status[e.review_status]=(stats.by_status[e.review_status]||0)+1
      stats.by_type[e.relationship_type]=(stats.by_type[e.relationship_type]||0)+1
    }
    return Response.json(stats)
  }

  return Response.json({ error: 'Unknown action' }, { status: 400 })
}

function html() {
  const config = JSON.stringify({ url, key: publishableKey() })
  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Progression Review</title>
<style>
:root{color-scheme:dark;--bg:#070a08;--panel:#111612;--line:#273128;--green:#b7ff2a;--muted:#9aa49b;--red:#ff7272}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:#eef5ee;font:14px system-ui,-apple-system,sans-serif}header{position:sticky;top:0;background:#090d0acc;padding:18px 22px;border-bottom:1px solid var(--line);backdrop-filter:blur(10px);z-index:3}h1{margin:0;color:var(--green);font-size:22px}.sub{color:var(--muted);margin-top:4px}.wrap{max-width:1280px;margin:auto;padding:20px}.panel{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:16px;margin-bottom:16px}.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}button,input,select,textarea{background:#0b0f0c;color:#eef5ee;border:1px solid #344035;border-radius:9px;padding:9px 11px}button{cursor:pointer}button.primary{background:var(--green);color:#0a0c0a;border-color:var(--green);font-weight:700}button.danger{border-color:#7b3434;color:#ffb0b0}.tabs button.active{border-color:var(--green);color:var(--green)}.hidden{display:none}.edge{padding:16px;border:1px solid var(--line);border-radius:14px;margin:12px 0;background:#0c110d}.compare{display:grid;grid-template-columns:1fr 44px 1fr;gap:12px;align-items:stretch}.card{background:#111812;border:1px solid #253026;border-radius:12px;padding:12px}.arrow{display:flex;align-items:center;justify-content:center;color:var(--green);font-size:24px}.name{font-size:17px;font-weight:700}.chips{display:flex;flex-wrap:wrap;gap:5px;margin-top:8px}.chip{border:1px solid #354337;border-radius:999px;padding:3px 7px;color:#c8d3c9;font-size:12px}.meta{color:var(--muted);font-size:12px}.vector{display:grid;grid-template-columns:repeat(4,minmax(80px,1fr));gap:6px;margin-top:9px}.metric{background:#0b0f0c;border-radius:7px;padding:6px}.reason{margin:12px 0;color:#d9e5da}.status{font-weight:700}.AUTO_SUGGESTED{color:#ffd86f}.REVIEWED{color:var(--green)}.REJECTED{color:var(--red)}#graphSvg{width:100%;min-height:520px;background:#090d0a;border:1px solid var(--line);border-radius:12px}.issue{padding:10px;border-bottom:1px solid var(--line)}@media(max-width:760px){.compare{grid-template-columns:1fr}.arrow{transform:rotate(90deg)}.vector{grid-template-columns:1fr 1fr}}
</style></head><body><header><h1>Progression Review</h1><div class="sub">GLUTE + HIP reviewed graph · AUTO_SUGGESTED never reaches users</div></header><main class="wrap">
<div id="authPanel" class="panel"><div class="row"><input id="email" type="email" placeholder="Admin email"><button id="login">Send magic link</button><span id="authMsg" class="meta"></span></div></div>
<div id="app" class="hidden"><div class="panel row tabs"><button data-tab="review" class="active">Review</button><button data-tab="graph">Graph</button><button data-tab="validation">Validation</button><span id="stats" class="meta"></span><button id="logout">Log out</button></div>
<section id="review" class="tab"><div class="panel row"><select id="status"><option>AUTO_SUGGESTED</option><option>REVIEWED</option><option>REJECTED</option><option>ALL</option></select><select id="rtype"><option>ALL</option><option>PROGRESSION</option><option>REGRESSION</option><option>ALTERNATIVE</option><option>PREPARATION</option><option>ACTIVATION</option><option>MOBILITY</option><option>RELEASE</option></select><select id="family"><option>ALL</option><option>GLUTE</option><option>HIP</option></select><button id="refresh">Refresh</button></div><div id="edges"></div></section>
<section id="graph" class="tab hidden"><div class="panel row"><input id="rootId" type="number" placeholder="Root exercise ID, e.g. 265"><label><input id="pendingGraph" type="checkbox" checked> include pending</label><button id="loadGraph">Load graph</button></div><div class="panel"><svg id="graphSvg" viewBox="0 0 1100 520"></svg><div id="graphList"></div></div></section>
<section id="validation" class="tab hidden"><div class="panel"><button id="loadValidation">Run graph checks</button><div id="issues"></div></div></section></div></main>
<script type="module">
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.95.0/+esm';
const cfg=${config};const sb=createClient(cfg.url,cfg.key,{auth:{persistSession:true,detectSessionInUrl:true}});const fn=location.pathname;const $=id=>document.getElementById(id);
async function call(action,payload={}){const s=(await sb.auth.getSession()).data.session;if(!s)throw new Error('Sign in first');const r=await fetch(fn,{method:'POST',headers:{'content-type':'application/json','authorization':'Bearer '+s.access_token},body:JSON.stringify({action,...payload})});const j=await r.json();if(!r.ok)throw new Error(j.error||'Request failed');return j}
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function prof(p){if(!p)return '<div class="card">Missing profile</div>';const m=[['STR',p.strength_demand],['STAB',p.stability_demand],['COORD',p.coordination_demand],['BAL',p.balance_demand],['ROM',p.rom_demand],['MOB',p.mobility_demand],['LOAD',p.load_potential]];return '<div class="card"><div class="name">'+esc(p.name_en||('#'+p.exercise_id))+'</div><div class="meta">#'+p.exercise_id+' · '+esc(p.movement_family||'')+' · '+esc(p.movement_pattern||'')+'</div><div class="chips">'+(p.primary_muscles||[]).map(x=>'<span class="chip">'+esc(x)+'</span>').join('')+(p.equipment||[]).map(x=>'<span class="chip">⚙ '+esc(x)+'</span>').join('')+'</div><div class="vector">'+m.map(x=>'<div class="metric">'+x[0]+': <b>'+((x[1]??'–'))+'</b></div>').join('')+'</div></div>'}
async function refresh(){const j=await call('list',{status:$('status').value,type:$('rtype').value,family:$('family').value});$('edges').innerHTML=j.edges.map(e=>'<div class="edge"><div class="compare">'+prof(j.profiles[e.from_exercise_id])+'<div class="arrow">→</div>'+prof(j.profiles[e.to_exercise_id])+'</div><div class="row" style="margin-top:10px"><b>'+e.relationship_type+'</b><span class="status '+e.review_status+'">'+e.review_status+'</span><span class="chips">'+(e.progression_dimension||[]).map(x=>'<span class="chip">'+x+'</span>').join('')+'</span><span>confidence '+(e.confidence??'–')+'</span><span>evidence '+(e.evidence_level??'–')+'</span></div><div class="reason">'+esc(e.ai_reason||'')+'</div><div class="row"><button class="primary" data-approve="'+e.id+'">APPROVE</button><button class="danger" data-reject="'+e.id+'">REJECT</button><button data-edit="'+e.id+'">EDIT</button></div></div>').join('')||'<div class="panel">No relationships</div>';bindActions();await loadStats()}
function bindActions(){document.querySelectorAll('[data-approve]').forEach(b=>b.onclick=async()=>{await call('review',{review_action:'APPROVE',relationship_id:+b.dataset.approve});await refresh()});document.querySelectorAll('[data-reject]').forEach(b=>b.onclick=async()=>{const reason=prompt('Optional rejection reason')||null;await call('review',{review_action:'REJECT',relationship_id:+b.dataset.reject,rejection_reason:reason});await refresh()});document.querySelectorAll('[data-edit]').forEach(b=>b.onclick=async()=>{const raw=prompt('Edit JSON, e.g. {"progression_dimension":["LOAD"],"confidence":0.9,"notes":"..."}','{}');if(!raw)return;await call('review',{review_action:'EDIT',relationship_id:+b.dataset.edit,patch:JSON.parse(raw)});await refresh()})}
async function loadStats(){const j=await call('stats');$('stats').textContent='Profiles '+j.profiles+' · '+Object.entries(j.by_status).map(([k,v])=>k+' '+v).join(' · ')}
async function graph(){const j=await call('graph',{include_pending:$('pendingGraph').checked});const root=+$('rootId').value||265;const relevant=j.edges.filter(e=>e.from_exercise_id===root||e.to_exercise_id===root);$('graphList').innerHTML=relevant.map(e=>'<div class="issue">'+esc(j.profiles[e.from_exercise_id]?.name_en)+' → '+esc(j.profiles[e.to_exercise_id]?.name_en)+' · '+e.relationship_type+' · '+(e.progression_dimension||[]).join('/')+' · '+e.review_status+'</div>').join('');const out=relevant.filter(e=>e.from_exercise_id===root);const svg=$('graphSvg');const rootName=j.profiles[root]?.name_en||('#'+root);let s='<rect x="420" y="25" width="260" height="54" rx="12" fill="#182118" stroke="#b7ff2a"/><text x="550" y="58" text-anchor="middle" fill="#eef5ee" font-size="16">'+esc(rootName)+'</text>';out.forEach((e,i)=>{const x=80+(i%4)*270,y=150+Math.floor(i/4)*120;const name=j.profiles[e.to_exercise_id]?.name_en||('#'+e.to_exercise_id);s+='<line x1="550" y1="79" x2="'+(x+110)+'" y2="'+y+'" stroke="#4e6150"/><rect x="'+x+'" y="'+y+'" width="220" height="64" rx="10" fill="#111612" stroke="'+(e.review_status==='REVIEWED'?'#b7ff2a':'#6a6337')+'"/><text x="'+(x+110)+'" y="'+(y+25)+'" text-anchor="middle" fill="#eef5ee" font-size="13">'+esc(name).slice(0,28)+'</text><text x="'+(x+110)+'" y="'+(y+47)+'" text-anchor="middle" fill="#9aa49b" font-size="11">'+e.relationship_type+' '+(e.progression_dimension||[]).join('/')+'</text>'});svg.innerHTML=s}
async function validation(){const j=await call('validation');$('issues').innerHTML=j.issues.map(x=>'<div class="issue"><b>'+x.issue_type+'</b> · exercise '+x.exercise_id+'<pre>'+esc(JSON.stringify(x.details,null,2))+'</pre></div>').join('')||'<div class="issue">No issues</div>'}
$('login').onclick=async()=>{const email=$('email').value.trim();const {error}=await sb.auth.signInWithOtp({email,options:{emailRedirectTo:location.href}});$('authMsg').textContent=error?error.message:'Magic link sent'};$('logout').onclick=async()=>{await sb.auth.signOut();location.reload()};$('refresh').onclick=refresh;$('loadGraph').onclick=graph;$('loadValidation').onclick=validation;document.querySelectorAll('.tabs [data-tab]').forEach(b=>b.onclick=()=>{document.querySelectorAll('.tab').forEach(x=>x.classList.add('hidden'));$(b.dataset.tab).classList.remove('hidden');document.querySelectorAll('.tabs [data-tab]').forEach(x=>x.classList.remove('active'));b.classList.add('active')});
async function boot(){const session=(await sb.auth.getSession()).data.session;if(session){$('authPanel').classList.add('hidden');$('app').classList.remove('hidden');try{await refresh()}catch(e){$('edges').innerHTML='<div class="panel">'+esc(e.message)+'</div>'}}}boot();
</script></body></html>`
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method === 'GET') return new Response(html(), { headers: { 'content-type':'text/html; charset=utf-8', 'cache-control':'no-store' } })
    if (req.method === 'POST') return await api(req)
    return new Response('Method not allowed', { status: 405 })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    return Response.json({ error: message }, { status: 500 })
  }
})
