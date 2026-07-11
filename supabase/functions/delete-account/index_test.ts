import { createHandler } from "./index.ts";

Deno.test("rejects a request without an authenticated Supabase user", async () => {
  const handler = createHandler({
    authenticate: async () => null,
    deleteUser: async () => new Response(null, { status: 500 }),
  });

  const response = await handler(
    new Request("https://example.test", { method: "DELETE" }),
  );

  assertEquals(response.status, 401);
});

Deno.test("accepts only DELETE and OPTIONS", async () => {
  const handler = createHandler({
    authenticate: async () => "authenticated-user",
    deleteUser: async () => new Response(null, { status: 204 }),
  });

  const response = await handler(
    new Request("https://example.test", { method: "POST" }),
  );

  assertEquals(response.status, 405);
});

Deno.test("deletes the user returned by authentication", async () => {
  let deletedUserID: string | undefined;
  const logs: unknown[] = [];
  const handler = createHandler({
    authenticate: async () => "authenticated-user",
    deleteUser: async (userID) => {
      deletedUserID = userID;
      return new Response(null, { status: 204 });
    },
    requestID: () => "request-2",
    log: (event) => logs.push(event),
  });

  const response = await handler(
    new Request("https://example.test", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user_id: "attacker-selected-user" }),
    }),
  );

  assertEquals(response.status, 204);
  assertEquals(deletedUserID, "authenticated-user");
  assertEquals(response.headers.get("X-Request-ID"), "request-2");
  assertEquals(logs, [{
    event: "edge_function_request",
    function: "delete-account",
    request_id: "request-2",
    status: 204,
  }]);
  if (JSON.stringify(logs).includes("authenticated-user")) {
    throw new Error("User IDs must never enter operational logs");
  }
});

Deno.test("surfaces an upstream deletion failure", async () => {
  const handler = createHandler({
    authenticate: async () => "authenticated-user",
    deleteUser: async () =>
      Response.json(
        { error: "account_deletion_failed" },
        { status: 503 },
      ),
  });

  const response = await handler(
    new Request("https://example.test", { method: "DELETE" }),
  );

  assertEquals(response.status, 503);
  assertEquals(await response.json(), { error: "account_deletion_failed" });
});

function assertEquals(actual: unknown, expected: unknown) {
  const actualJSON = JSON.stringify(actual);
  const expectedJSON = JSON.stringify(expected);
  if (actualJSON !== expectedJSON) {
    throw new Error(`Expected ${expectedJSON}, received ${actualJSON}`);
  }
}
