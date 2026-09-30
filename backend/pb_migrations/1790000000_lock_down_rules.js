/// <reference path="../pb_data/types.d.ts" />
// Server-side access rules. Before this, every collection was fully public.
// null = superuser only (dashboard), "" would be public.
const AUTH = '@request.auth.id != ""'
const ADMIN = '@request.auth.role = "admin"'

const RULES = {
  _pb_users_auth_: {
    listRule: `id = @request.auth.id || ${ADMIN}`,
    viewRule: AUTH,
    createRule: null, // accounts are created from the dashboard, no public sign-up
    // members can't promote themselves
    updateRule: `id = @request.auth.id && @request.body.role:isset = false`,
    deleteRule: null,
  },
  inventory: {
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADMIN,
    updateRule: ADMIN, // members change stock only via inventory_logs (see pb_hooks)
    deleteRule: ADMIN,
  },
  inventory_logs: {
    listRule: ADMIN,
    viewRule: ADMIN,
    createRule: `${AUTH} && @request.body.user = @request.auth.id`,
    updateRule: null, // ledger is append-only
    deleteRule: null,
  },
  procurement_requests: {
    listRule: `requested_by = @request.auth.id || ${ADMIN}`,
    viewRule: `requested_by = @request.auth.id || ${ADMIN}`,
    createRule: `${AUTH} && @request.body.requested_by = @request.auth.id && (@request.body.status:isset = false || @request.body.status = "Pending")`,
    updateRule: ADMIN,
    deleteRule: ADMIN,
  },
  progress_reports: {
    listRule: `user_id = @request.auth.id || ${ADMIN}`,
    viewRule: `user_id = @request.auth.id || ${ADMIN}`,
    createRule: `${AUTH} && @request.body.user_id = @request.auth.id`,
    updateRule: null,
    deleteRule: ADMIN,
  },
}

migrate((app) => {
  for (const [name, rules] of Object.entries(RULES)) {
    const c = app.findCollectionByNameOrId(name)
    unmarshal(rules, c)
    app.save(c)
  }
}, (app) => {
  // users keep the locked rules on rollback; the old ones allowed self-promotion
  for (const name of Object.keys(RULES).filter((n) => n !== "_pb_users_auth_")) {
    const c = app.findCollectionByNameOrId(name)
    unmarshal({ listRule: "", viewRule: "", createRule: "", updateRule: "", deleteRule: "" }, c)
    app.save(c)
  }
})
