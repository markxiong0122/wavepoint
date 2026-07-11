type Dependencies = {
  authenticate: (request: Request) => Promise<string | null>;
  deleteUser: (userID: string) => Promise<Response>;
  requestID?: () => string;
  log?: (event: OperationalLogEvent) => void;
};

type OperationalLogEvent = {
  event: "edge_function_request";
  function: "delete-account";
  request_id: string;
  status: number;
};

export function createHandler(dependencies: Dependencies) {
  return async (request: Request): Promise<Response> => {
    const requestID = (dependencies.requestID ?? (() => crypto.randomUUID()))();
    const observed = (response: Response) =>
      observe(
        response,
        requestID,
        dependencies.log ?? defaultLog,
      );
    if (request.method === "OPTIONS") {
      return observed(
        new Response(null, {
          status: 204,
          headers: {
            "Access-Control-Allow-Headers":
              "authorization, content-type, apikey",
            "Access-Control-Allow-Methods": "DELETE, OPTIONS",
            "Access-Control-Allow-Origin": "*",
          },
        }),
      );
    }

    if (request.method !== "DELETE") {
      return observed(
        Response.json({ error: "method_not_allowed" }, { status: 405 }),
      );
    }

    const userID = await dependencies.authenticate(request);
    if (!userID) {
      return observed(
        Response.json({ error: "unauthorized" }, { status: 401 }),
      );
    }

    return observed(await dependencies.deleteUser(userID));
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

function observe(
  response: Response,
  requestID: string,
  log: (event: OperationalLogEvent) => void,
): Response {
  const headers = new Headers(response.headers);
  headers.set("X-Request-ID", requestID);
  log({
    event: "edge_function_request",
    function: "delete-account",
    request_id: requestID,
    status: response.status,
  });
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function defaultLog(event: OperationalLogEvent) {
  console.log(JSON.stringify(event));
}

if (import.meta.main) {
  Deno.serve(createHandler({ authenticate, deleteUser }));
}
