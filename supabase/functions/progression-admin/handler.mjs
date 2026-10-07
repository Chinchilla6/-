const types=['PROGRESSION','REGRESSION','ALTERNATIVE','PREPARATION','ACTIVATION','MOBILITY','RELEASE'];
const statuses=['AUTO_SUGGESTED','REVIEWED','REJECTED'];
const editable=['relationship_type','progression_dimension','difficulty_delta','required_conditions','contraindications','confidence','evidence_level','evidence_source','ai_reason','notes'];
export function createHandler(admin){
 const cors=req=>({...{'Access-Control-Allow-Headers':'authorization, content-type, apikey, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'},...(req.headers.get('origin')==='https://chinchilla6.github.io'?{'Access-Control-Allow-Origin':'https://chinchilla6.github.io'}:{})});
 async function allRows(table,configure=q=>q){
  const rows=[];
  for(let offset=0;;offset+=500){const {data,error}=await configure(admin.from(table).select('*')).order('id').range(offset,offset+499);if(error)throw error;rows.push(...data);if(data.length<500)return rows;}
 }
 async function profilesFor(ids){const result={};for(let i=0;i<ids.length;i+=200){const {data,error}=await admin.from('exercise_knowledge_view').select('*').in('exercise_id',ids.slice(i,i+200));if(error)throw error;for(const row of data)result[row.exercise_id]=row;}return result;}
 return async req=>{
  const respond=(value,status=200)=>Response.json(value,{status,headers:cors(req)});
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors(req)});
  if(req.method==='GET')return Response.redirect('https://chinchilla6.github.io/-/progression-review/',302);
  if(req.method!=='POST')return respond({error:'Method not allowed'},405);
  try{
   const token=req.headers.get('authorization')?.match(/^Bearer (.+)$/)?.[1];
   if(!token)return respond({error:'Authentication required'},401);
   const {data,error}=await admin.auth.getUser(token);
   if(error||!data?.user)return respond({error:'Invalid session'},401);
   const user=data.user;
   // Only server-owned app_metadata may authorize review; user_metadata is user-editable.
   if(user.app_metadata?.role!=='admin'&&user.app_metadata?.is_admin!==true)return respond({error:'Admin role required'},403);
   let body;try{body=await req.json();}catch{return respond({error:'Invalid JSON'},400);}
   if(!body||typeof body!=='object'||Array.isArray(body))return respond({error:'Body must be an object'},400);
   const action=body.action;
   if(action==='review'){
    if(!Number.isSafeInteger(body.relationship_id)||body.relationship_id<=0||!['APPROVE','REJECT','EDIT'].includes(body.review_action))return respond({error:'Invalid review request'},400);
    const patch=body.patch??{};
    if(typeof patch!=='object'||patch===null||Array.isArray(patch)||Object.keys(patch).some(k=>!editable.includes(k)))return respond({error:'Unsupported patch fields'},400);
    if(body.review_action!=='EDIT'&&Object.keys(patch).length)return respond({error:'Save edits before reviewing'},400);
    const {data,error}=await admin.rpc('review_exercise_relationship',{p_relationship_id:body.relationship_id,p_action:body.review_action,p_reviewer:user.id,p_patch:patch,p_rejection_reason:body.rejection_reason||null});
    if(error)return respond({error:error.message},400);return respond({ok:true,relationship:data});
   }
   if(['list','graph','stats'].includes(action)){
    if(body.status&&body.status!=='ALL'&&!statuses.includes(body.status))return respond({error:'Invalid status'},400);
    if(body.type&&body.type!=='ALL'&&!types.includes(body.type))return respond({error:'Invalid type'},400);
    const edges=await allRows('exercise_relationships',q=>{if(action==='graph')q=q.in('review_status',body.include_pending===true?['AUTO_SUGGESTED','REVIEWED']:['REVIEWED']);if(action==='list'&&body.status&&body.status!=='ALL')q=q.eq('review_status',body.status);if(action==='list'&&body.type&&body.type!=='ALL')q=q.eq('relationship_type',body.type);return q;});
    const profiles=await profilesFor([...new Set(edges.flatMap(e=>[e.from_exercise_id,e.to_exercise_id]))]);
    if(action==='graph'){
     const {data,error}=await admin.from('exercise_knowledge_view').select('*').in('movement_family',['GLUTE','HIP']);if(error)throw error;
     for(const profile of data)profiles[profile.exercise_id]=profile;
    }
    if(action==='stats'){
     const {count,error}=await admin.from('rehab_exercise_metadata').select('*',{count:'exact',head:true}).in('movement_family',['GLUTE','HIP']);if(error)throw error;
     const result={profiles:count,by_status:{},by_type:{}};for(const e of edges){result.by_status[e.review_status]=(result.by_status[e.review_status]||0)+1;result.by_type[e.relationship_type]=(result.by_type[e.relationship_type]||0)+1;}return respond(result);
    }
    return respond({edges:edges.filter(e=>!body.family||body.family==='ALL'||profiles[e.from_exercise_id]?.movement_family===body.family||profiles[e.to_exercise_id]?.movement_family===body.family),profiles});
   }
   if(action==='validation'){const {data,error}=await admin.from('exercise_graph_validation').select('*');if(error)throw error;return respond({issues:data});}
   if(action==='audit'){if(!Number.isSafeInteger(body.relationship_id)||body.relationship_id<=0)return respond({error:'Invalid relationship ID'},400);return respond({events:await allRows('exercise_relationship_audit',q=>q.eq('relationship_id',body.relationship_id))});}
   return respond({error:'Unknown action'},400);
  }catch{return respond({error:'Request failed. Check server logs.'},500);}
 };
}

