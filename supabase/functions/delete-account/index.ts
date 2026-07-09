type Dependencies = {
  authenticate: (request: Request) => Promise<string | null>;
  deleteUser: (userID: string) => Promise<Response>;
};

export function createHandler(dependencies: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Headers": "authorization, content-type, apikey",
          "Access-Control-Allow-Methods": "DELETE, OPTIONS",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    if (request.method !== "DELETE") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }

    const userID = await dependencies.authenticate(request);
    if (!userID) {
      return Response.json({ error: "unauthorized" }, { status: 401 });
    }

    return dependencies.deleteUser(userID);
  };
}

async function authenticate(request: Request): Promise<string | null> {
  const authorization = request.headers.get("Authorization");
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization || !supabaseURL || !anonKey) return null;

  const response = await fetch(`${supabaseURL}/auth/v1/user`, {
    headers: {
      apikey: anonKey,
      Authorization: authorization,
    },
  });
  if (!response.ok) return null;

  try {
    const user = await response.json() as { id?: unknown };
    return typeof user.id === "string" && user.id.length > 0 ? user.id : null;
  } catch {
    return null;
  }
}

async function deleteUser(userID: string): Promise<Response> {
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) {
    return Response.json({ error: "server_not_configured" }, { status: 503 });
  }

  const response = await fetch(
    `${supabaseURL}/auth/v1/admin/users/${encodeURIComponent(userID)}`,
    {
      method: "DELETE",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (response.ok) {
    return new Response(null, { status: 204 });
  }

  return Response.json(
    { error: "account_deletion_failed" },
    { status: response.status },
  );
}

if (import.meta.main) {
  Deno.serve(createHandler({ authenticate, deleteUser }));
}
