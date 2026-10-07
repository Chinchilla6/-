import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.95.0'
import { createHandler } from './handler.mjs'
const keys = Deno.env.get('SUPABASE_SECRET_KEYS')
const key = keys ? JSON.parse(keys).default : Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const admin = createClient(Deno.env.get('SUPABASE_URL')!,key,{auth:{persistSession:false}})
// Public GET redirects to the login shell; every data action validates user and admin role.
Deno.serve(createHandler(admin))

