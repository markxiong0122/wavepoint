type Dependencies = {
  authenticate: (request: Request) => Promise<boolean>;
  refreshSpotifyToken: (refreshToken: string) => Promise<Response>;
};

export function createHandler(dependencies: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Headers": "authorization, content-type, apikey",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }

    if (!(await dependencies.authenticate(request))) {
      return json({ error: "unauthorized" }, 401);
    }

    let body: { refresh_token?: unknown };
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    if (
      typeof body.refresh_token !== "string" || body.refresh_token.length === 0
    ) {
      return json({ error: "missing_refresh_token" }, 400);
    }

    return dependencies.refreshSpotifyToken(body.refresh_token);
  };
}

async function authenticate(request: Request): Promise<boolean> {
  const authorization = request.headers.get("Authorization");
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization || !supabaseURL || !anonKey) return false;

  const response = await fetch(`${supabaseURL}/auth/v1/user`, {
    headers: {
      apikey: anonKey,
      Authorization: authorization,
    },
  });
  return response.ok;
}

async function refreshSpotifyToken(refreshToken: string): Promise<Response> {
  const clientID = Deno.env.get("SPOTIFY_CLIENT_ID");
  const clientSecret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
  if (!clientID || !clientSecret) {
    return json({ error: "server_not_configured" }, 503);
  }

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${clientID}:${clientSecret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  return new Response(await response.text(), {
    status: response.status,
    headers: { "Content-Type": "application/json" },
  });
}

function json(value: unknown, status: number): Response {
  return Response.json(value, { status });
}

if (import.meta.main) {
  Deno.serve(createHandler({ authenticate, refreshSpotifyToken }));
}
