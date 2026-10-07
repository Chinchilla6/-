export function layoutGraph(edges,profiles,root=null){
 let visible=edges;
 if(root!==null){const ids=new Set([root]);let changed=true;while(changed){changed=false;for(const e of edges)if(ids.has(e.from_exercise_id)||ids.has(e.to_exercise_id))for(const id of [e.from_exercise_id,e.to_exercise_id])if(!ids.has(id)){ids.add(id);changed=true;}}visible=edges.filter(e=>ids.has(e.from_exercise_id)&&ids.has(e.to_exercise_id));}
 const ids=[...new Set([...visible.flatMap(e=>[e.from_exercise_id,e.to_exercise_id]),...(root===null?Object.keys(profiles).map(Number):[])])].sort((a,b)=>String(profiles[a]?.movement_pattern).localeCompare(String(profiles[b]?.movement_pattern))||a-b);
 return {nodes:ids.map((id,i)=>({id,label:profiles[id]?.name_en||'#'+id,x:60+i%4*270,y:70+Math.floor(i/4)*120})),edges:visible,width:1140,height:Math.max(600,Math.ceil(ids.length/4)*120+100)};
}

