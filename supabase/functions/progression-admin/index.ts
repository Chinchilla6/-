import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.95.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const PAGES_URL = 'https://chinchilla6.github.io/-/admin/progression-review/'
const ALLOWED_ORIGINS = new Set(['https://chinchilla6.github.io'])

function secretKey() {
  const keys = Deno.env.get('SUPABASE_SECRET_KEYS')
  return keys ? JSON.parse(keys).default : Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
}

const admin = createClient(SUPABASE_URL, secretKey(), { auth: { persistSession: false } })

function corsHeaders(req: Request) {
  const origin = req.headers.get('origin') || ''
  const headers = new Headers({
    'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  })
  if (ALLOWED_ORIGINS.has(origin)) headers.set('Access-Control-Allow-Origin', origin)
  return headers
}

function withCors(req: Request, response: Response) {
  const headers = new Headers(response.headers)
  for (const [key, value] of corsHeaders(req)) headers.set(key, value)
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers })
}

async function requireAdmin(req: Request) {
  const auth = req.headers.get('authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return { error: Response.json({ error: 'Authentication required' }, { status: 401 }) }

  const { data, error } = await admin.auth.getUser(token)
  const user = data?.user
  if (error || !user) return { error: Response.json({ error: 'Invalid session' }, { status: 401 }) }

  const isAdmin = user.app_metadata?.role === 'admin' || user.app_metadata?.is_admin === true
  if (!isAdmin) {
    return { error: Response.json({
      error: 'Admin role required',
      hint: 'Reviewer account needs app_metadata.role=admin or app_metadata.is_admin=true.',
    }, { status: 403 }) }
  }
  return { user }
}

async function profilesFor(ids: number[]) {
  if (!ids.length) return {}
  const { data, error } = await admin.from('exercise_knowledge_view').select('*').in('exercise_id', ids)
  if (error) throw error
  return Object.fromEntries((data || []).map((row: any) => [row.exercise_id, row]))
}

async function api(req: Request) {
  const guard = await requireAdmin(req)
  if ('error' in guard) return guard.error

  const body = await req.json().catch(() => ({}))
  const action = body.action || 'list'

  if (action === 'list') {
    let query = admin.from('exercise_relationships').select('*').order('confidence', { ascending: false }).order('id')
    if (body.status && body.status !== 'ALL') query = query.eq('review_status', body.status)
    if (body.type && body.type !== 'ALL') query = query.eq('relationship_type', body.type)

    const { data, error } = await query.limit(300)
    if (error) throw error
    const edges = data || []
    const ids = [...new Set(edges.flatMap((edge: any) => [edge.from_exercise_id, edge.to_exercise_id]))]
    const profiles = await profilesFor(ids as number[])
    const filtered = edges.filter((edge: any) => {
      const from: any = profiles[edge.from_exercise_id]
      const to: any = profiles[edge.to_exercise_id]
      return !body.family || body.family === 'ALL' || from?.movement_family === body.family || to?.movement_family === body.family
    })
    return Response.json({ edges: filtered, profiles })
  }

  if (action === 'review') {
    const { data, error } = await admin.rpc('review_exercise_relationship', {
      p_relationship_id: body.relationship_id,
      p_action: String(body.review_action || '').toUpperCase(),
      p_reviewer: guard.user!.id,
      p_patch: body.patch || {},
      p_rejection_reason: body.rejection_reason || null,
    })
    if (error) throw error
    return Response.json({ ok: true, relationship: data })
  }

  if (action === 'graph') {
    const statuses = body.include_pending ? ['AUTO_SUGGESTED', 'REVIEWED'] : ['REVIEWED']
    const { data: edges, error } = await admin.from('exercise_relationships').select('*').in('review_status', statuses).limit(500)
    if (error) throw error
    const ids = [...new Set((edges || []).flatMap((edge: any) => [edge.from_exercise_id, edge.to_exercise_id]))]
    return Response.json({ edges: edges || [], profiles: await profilesFor(ids as number[]) })
  }

  if (action === 'validation') {
    const { data, error } = await admin.from('exercise_graph_validation').select('*').limit(500)
    if (error) throw error
    return Response.json({ issues: data || [] })
  }

  if (action === 'stats') {
    const { data: edges, error: edgeError } = await admin.from('exercise_relationships').select('review_status,relationship_type')
    if (edgeError) throw edgeError
    const { data: profiles, error: profileError } = await admin.from('rehab_exercise_metadata').select('movement_family').in('movement_family', ['GLUTE', 'HIP'])
    if (profileError) throw profileError

    const stats: any = { profiles: profiles?.length || 0, by_status: {}, by_type: {} }
    for (const edge of edges || []) {
      stats.by_status[edge.review_status] = (stats.by_status[edge.review_status] || 0) + 1
      stats.by_type[edge.relationship_type] = (stats.by_type[edge.relationship_type] || 0) + 1
    }
    return Response.json(stats)
  }

  return Response.json({ error: 'Unknown action' }, { status: 400 })
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method === 'GET') return Response.redirect(PAGES_URL, 302)
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(req) })
    if (req.method === 'POST') return withCors(req, await api(req))
    return withCors(req, new Response('Method not allowed', { status: 405 }))
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return withCors(req, Response.json({ error: message }, { status: 500 }))
  }
})
