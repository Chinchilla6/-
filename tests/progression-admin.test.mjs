import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../supabase/functions/progression-admin/handler.mjs';
import {layoutGraph} from '../admin/progression-review/graph.mjs';
import {emailVerification} from '../admin/progression-review/login.mjs';
const request=(body,token='valid',origin='https://chinchilla6.github.io')=>new Request('https://example.test',{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),Origin:origin},body:typeof body==='string'?body:JSON.stringify(body)});
function fixture(user={id:'verified-reviewer',app_metadata:{role:'admin'}}){let calls=[];return {calls,handler:createHandler({auth:{getUser:async token=>({data:{user:token==='valid'?user:null},error:token==='valid'?null:{message:'bad'}})},rpc:async(name,args)=>{calls.push({name,args});return {data:{id:args.p_relationship_id},error:null}},from(){throw Error('must not touch database')}})};}
test('Missing token cannot reach data',async()=>{const f=fixture();assert.equal((await f.handler(request({action:'list'},null))).status,401);assert.equal(f.calls.length,0)});
test('Invalid token is rejected',async()=>assert.equal((await fixture().handler(request({action:'list'},'invalid'))).status,401));
test('Ordinary user and forged user_metadata admin cannot review',async()=>{for(const user of [{id:'u',app_metadata:{}},{id:'u',app_metadata:{},user_metadata:{role:'admin',is_admin:true}}])assert.equal((await fixture(user).handler(request({action:'review',review_action:'APPROVE',relationship_id:1}))).status,403)});
test('Approved review uses authenticated actor, ignores spoofed reviewer',async()=>{const f=fixture();assert.equal((await f.handler(request({action:'review',relationship_id:1,review_action:'APPROVE',p_reviewer:'spoof'}))).status,200);assert.equal(f.calls[0].args.p_reviewer,'verified-reviewer')});
test('Malformed JSON and invalid review IDs/actions return 400',async()=>{for(const body of ['{',null,[],{action:'review',relationship_id:-1,review_action:'APPROVE'},{action:'review',relationship_id:1,review_action:'AUTO_APPROVE'}])assert.equal((await fixture().handler(request(body))).status,400)});
test('Patch cannot set review status or actor',async()=>{for(const patch of [{review_status:'REVIEWED'},{reviewed_by:'spoof'},{from_exercise_id:4},[]])assert.equal((await fixture().handler(request({action:'review',relationship_id:1,review_action:'EDIT',patch}))).status,400)});
test('Approve cannot silently edit conditions',async()=>assert.equal((await fixture().handler(request({action:'review',relationship_id:1,review_action:'APPROVE',patch:{required_conditions:{}}}))).status,400));
test('Unknown action and invalid filters return 400',async()=>{for(const body of [{action:'delete'},{action:'list',status:'APPROVED'},{action:'graph',type:'FUZZY'}])assert.equal((await fixture().handler(request(body))).status,400)});
test('CORS does not trust hostile origin',async()=>{const r=await fixture().handler(request({},null,'https://evil.test'));assert.equal(r.headers.get('access-control-allow-origin'),null)});
test('GET resolves published Pages artifact path',async()=>{const r=await fixture().handler(new Request('https://example.test'));assert.equal(r.headers.get('location'),'https://chinchilla6.github.io/-/progression-review/')});
test('Full graph retains multi-hop and incoming edges',()=>{const edges=[{from_exercise_id:1,to_exercise_id:2},{from_exercise_id:2,to_exercise_id:3},{from_exercise_id:4,to_exercise_id:1},{from_exercise_id:8,to_exercise_id:9}];const full=layoutGraph(edges,{}),component=layoutGraph(edges,{},1);assert.equal(full.edges.length,4);assert.equal(component.edges.length,3);assert.equal(component.nodes.length,4)});
test('Graph scales beyond original fixed SVG height and terminates on cycles',()=>{const edges=Array.from({length:60},(_,i)=>({from_exercise_id:i,to_exercise_id:(i+1)%60}));const g=layoutGraph(edges,{},0);assert.equal(g.nodes.length,60);assert.ok(g.height>520)});
test('Full graph includes classified exercises with no edges',()=>assert.equal(layoutGraph([],{8:{name_en:'Isolated'}}).nodes.length,1));
test('Email link is verified directly without navigating to its redirect',()=>{
 const input=emailVerification('https://project.supabase.co/auth/v1/verify?token=TEST_HASH&type=magiclink&redirect_to=http://localhost','user@example.test','https://project.supabase.co');
 assert.deepEqual(input,{token_hash:'TEST_HASH',type:'email'});
});
test('Foreign projects, unsafe protocols, recovery links and missing tokens are rejected',()=>{
 for(const link of ['https://evil.test/auth/v1/verify?token=x&type=email','javascript:alert(1)','https://project.supabase.co/auth/v1/verify?token=x&type=recovery','https://project.supabase.co/auth/v1/verify?type=email'])assert.throws(()=>emailVerification(link,'user@example.test','https://project.supabase.co'));
});
test('Email OTP can be entered directly and needs an email',()=>{assert.deepEqual(emailVerification('123456','user@example.test','https://project.supabase.co'),{email:'user@example.test',token:'123456',type:'email'});assert.throws(()=>emailVerification('123456','','https://project.supabase.co'))});
test('List API fetches beyond 500 rows without silent truncation',async()=>{
 const rows=Array.from({length:601},(_,i)=>({id:i+1,from_exercise_id:1,to_exercise_id:2,review_status:'AUTO_SUGGESTED'}));
 const admin={auth:{getUser:async()=>({data:{user:{id:'admin',app_metadata:{role:'admin'}}},error:null})},from:table=>{
  const q={select(){return q},order(){return q},range(a,b){return Promise.resolve({data:rows.slice(a,b+1),error:null})},in(){return Promise.resolve({data:[{exercise_id:1},{exercise_id:2}],error:null})}};return q;
 }};
 const r=await createHandler(admin)(request({action:'list'}));assert.equal(r.status,200);assert.equal((await r.json()).edges.length,601);
});

