// Parse locally; never navigate to a pasted URL or send it to the review API.
export function emailVerification(input,email,projectUrl){
 const value=String(input||'').trim();
 if(/^\d{6}$/.test(value)){
  if(!email||!email.includes('@'))throw Error('请先填写登录邮箱');
  return {email:email.trim(),token:value,type:'email'};
 }
 let url;try{url=new URL(value)}catch{throw Error('请复制新邮件中的完整登录链接，或输入邮件验证码')}
 if(url.origin!==new URL(projectUrl).origin||url.pathname!=='/auth/v1/verify')throw Error('请复制该项目发出的原始 Supabase 登录链接');
 if(!['email','magiclink','signup'].includes(url.searchParams.get('type')))throw Error('这不是邮箱登录验证链接');
 const hash=url.searchParams.get('token_hash')||url.searchParams.get('token');
 if(!hash)throw Error('登录链接缺少验证信息，请重新发送');
 return {token_hash:hash,type:'email'};
}

