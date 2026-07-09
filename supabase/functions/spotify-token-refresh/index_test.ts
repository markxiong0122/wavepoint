import { createHandler } from "./index.ts";

Deno.test("rejects a request without a valid Supabase user", async () => {
  const handler = createHandler({
    authenticate: async () => false,
    refreshSpotifyToken: async () => new Response(null, { status: 500 }),
  });

  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({ refresh_token: "refresh" }),
    }),
  );

  assertEquals(response.status, 401);
});

Deno.test("requires a provider refresh token", async () => {
  const handler = createHandler({
    authenticate: async () => true,
    refreshSpotifyToken: async () => new Response(null, { status: 500 }),
  });

  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({}),
    }),
  );

  assertEquals(response.status, 400);
});

Deno.test("returns the refreshed Spotify token", async () => {
  let receivedRefreshToken: string | undefined;
  const handler = createHandler({
    authenticate: async () => true,
    refreshSpotifyToken: async (refreshToken) => {
      receivedRefreshToken = refreshToken;
      return Response.json({ access_token: "new-access", expires_in: 3600 });
    },
  });

  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({ refresh_token: "provider-refresh" }),
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(receivedRefreshToken, "provider-refresh");
  assertEquals(await response.json(), {
    access_token: "new-access",
    expires_in: 3600,
  });
});

function assertEquals(actual: unknown, expected: unknown) {
  const actualJSON = JSON.stringify(actual);
  const expectedJSON = JSON.stringify(expected);
  if (actualJSON !== expectedJSON) {
    throw new Error(`Expected ${expectedJSON}, received ${actualJSON}`);
  }
}
