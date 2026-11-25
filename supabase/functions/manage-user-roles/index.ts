import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

type Role = "Staff" | "Production Head" | "Owner";
type AccountSummary = {
  id: string;
  email: string;
  name: string;
  role: Role;
  isCurrentUser: boolean;
};
type AuthUserRecord = {
  id: string;
  email?: string;
  app_metadata?: Record<string, unknown>;
  user_metadata?: Record<string, unknown>;
};
type AdminClient = ReturnType<typeof createClient>;

const roleOf = (user: AuthUserRecord): Role => {
  const role = user.app_metadata?.role;
  return role === "Owner" || role === "Production Head" || role === "Staff"
    ? role
    : "Staff";
};

const accountSummary = (user: AuthUserRecord, currentUserId: string): AccountSummary => {
  const metadata = user.user_metadata || {};
  const name = [
    metadata.first_name,
    metadata.middle_name,
    metadata.surname,
  ].filter((part): part is string => typeof part === "string" && part.trim().length > 0).join(" ");

  return {
    id: user.id,
    email: user.email || "",
    name: name || user.email || "Unnamed account",
    role: roleOf(user),
    isCurrentUser: user.id === currentUserId,
  };
};

async function listAccounts(
  adminClient: AdminClient,
  currentUserId: string,
): Promise<{ accounts?: AccountSummary[]; error?: string }> {
  const accounts: AccountSummary[] = [];
  for (let page = 1; ; page += 1) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 100,
    });
    if (error) {
      console.error("Could not list Auth users:", error.message);
      return { error: "Could not load accounts." };
    }

    accounts.push(...data.users.map((user) => accountSummary(user, currentUserId)));
    if (data.users.length < 100) break;
  }
  accounts.sort((a, b) => a.name.localeCompare(b.name));
  return { accounts };
}

async function setAppRole(
  adminClient: AdminClient,
  user: AuthUserRecord,
  role: Role,
) {
  return await adminClient.auth.admin.updateUserById(user.id, {
    app_metadata: {
      ...user.app_metadata,
      role,
    },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return json({ error: "Sign in to manage accounts." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !publicKey || !serviceRoleKey) {
    console.error("Required Supabase function environment variables are missing.");
    return json({ error: "Account management is not configured." }, 500);
  }

  const authClient = createClient(supabaseUrl, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user: caller }, error: authError } = await authClient.auth.getUser(token);
  if (authError || !caller) {
    return json({ error: "Your session is invalid or expired. Sign in again." }, 401);
  }

  let body: { action?: unknown; userId?: unknown; transferId?: unknown; role?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Request body must be valid JSON." }, 400);
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "Request body must be a JSON object." }, 400);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const isOwner = caller.app_metadata?.role === "Owner";

  if (body.action === "transfer-state") {
    const { data: active, error: activeError } = await adminClient
      .from("owner_transfers")
      .select("*")
      .in("status", ["pending", "processing"])
      .maybeSingle();
    if (activeError) {
      console.error("Could not load active ownership transfer:", activeError.message);
      return json({ error: "Could not load ownership transfer status. Apply the transfer database migration first." }, 500);
    }

    if (active) {
      const isInitiator = active.from_user_id === caller.id;
      const isRecipient = active.to_user_id === caller.id;
      if (!isInitiator && !isRecipient) {
        return json({
          isOwner,
          currentRole: roleOf(caller),
          activeTransfer: true,
          transfer: null,
          candidates: [],
        });
      }

      const otherUserId = isInitiator ? active.to_user_id : active.from_user_id;
      const { data: { user: otherUser }, error: otherUserError } =
        await adminClient.auth.admin.getUserById(otherUserId);
      if (otherUserError || !otherUser) {
        console.error("Could not load ownership transfer account:", otherUserError?.message);
        return json({ error: "Could not load the account involved in the transfer." }, 500);
      }

      return json({
        isOwner,
        currentRole: roleOf(caller),
        activeTransfer: true,
        transfer: {
          id: active.id,
          status: active.status,
          createdAt: active.created_at,
          acceptedAt: active.accepted_at,
          isInitiator,
          isRecipient,
          otherUser: accountSummary(otherUser, caller.id),
        },
        candidates: [],
      });
    }

    const { data: recent, error: recentError } = await adminClient
      .from("owner_transfers")
      .select("status, created_at")
      .or(`from_user_id.eq.${caller.id},to_user_id.eq.${caller.id}`)
      .in("status", ["completed", "rejected", "cancelled"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (recentError) {
      console.error("Could not load recent ownership transfer:", recentError.message);
      return json({ error: "Could not load ownership transfer history." }, 500);
    }

    let candidates: AccountSummary[] = [];
    if (isOwner) {
      const result = await listAccounts(adminClient, caller.id);
      if (result.error) return json({ error: result.error }, 500);
      candidates = (result.accounts || []).filter(
        (account) => !account.isCurrentUser && account.role !== "Owner",
      );
    }
    return json({
      isOwner,
      currentRole: roleOf(caller),
      activeTransfer: false,
      transfer: null,
      recentTransfer: recent || null,
      candidates,
    });
  }

  if (body.action === "list") {
    if (!isOwner) return json({ error: "Only an Owner can manage account roles." }, 403);
    const result = await listAccounts(adminClient, caller.id);
    if (result.error) return json({ error: result.error }, 500);
    return json({ users: result.accounts || [] });
  }

  if (body.action === "set-role") {
    if (!isOwner) return json({ error: "Only an Owner can manage account roles." }, 403);
    if (typeof body.userId !== "string" || !body.userId || body.userId.length > 100) {
      return json({ error: "A valid account ID is required." }, 400);
    }
    if (body.role !== "Staff" && body.role !== "Production Head") {
      return json({ error: "Owners can assign Staff or Production Head roles only." }, 400);
    }
    if (body.userId === caller.id) {
      return json({ error: "You cannot change your own role here." }, 403);
    }

    const { data: { user: target }, error: targetError } =
      await adminClient.auth.admin.getUserById(body.userId);
    if (targetError || !target) {
      return json({ error: "The selected account could not be found." }, 404);
    }
    if (target.app_metadata?.role === "Owner") {
      return json({ error: "Owner roles can only be changed through ownership transfer." }, 403);
    }

    const { data: { user: updated }, error: updateError } =
      await setAppRole(adminClient, target, body.role);
    if (updateError || !updated) {
      console.error("Could not update Auth user role:", updateError?.message);
      return json({ error: "Could not update this account's role." }, 500);
    }
    return json({ userId: updated.id, role: roleOf(updated) });
  }

  if (body.action === "start-transfer") {
    if (!isOwner) return json({ error: "Only an Owner can start an ownership transfer." }, 403);
    if (typeof body.userId !== "string" || !body.userId || body.userId.length > 100) {
      return json({ error: "Select an existing account to receive ownership." }, 400);
    }
    if (body.userId === caller.id) {
      return json({ error: "You cannot transfer ownership to yourself." }, 400);
    }

    const { data: { user: target }, error: targetError } =
      await adminClient.auth.admin.getUserById(body.userId);
    if (targetError || !target) {
      return json({ error: "The selected account could not be found." }, 404);
    }
    if (target.app_metadata?.role !== "Staff" && target.app_metadata?.role !== "Production Head") {
      return json({ error: "Choose an existing Staff or Production Head account." }, 400);
    }

    const { data: transfer, error: insertError } = await adminClient
      .from("owner_transfers")
      .insert({
        from_user_id: caller.id,
        to_user_id: target.id,
      })
      .select("id, status, created_at")
      .single();
    if (insertError) {
      if (insertError.code === "23505") {
        return json({ error: "Another ownership transfer is already pending or processing." }, 409);
      }
      console.error("Could not start ownership transfer:", insertError.message);
      return json({ error: "Could not start ownership transfer." }, 500);
    }
    return json({ transfer });
  }

  if (body.action === "cancel-transfer" || body.action === "reject-transfer") {
    if (typeof body.transferId !== "string" || !body.transferId || body.transferId.length > 100) {
      return json({ error: "A valid transfer ID is required." }, 400);
    }
    if (body.action === "cancel-transfer" && !isOwner) {
      return json({ error: "Only the initiating Owner can cancel a transfer." }, 403);
    }

    const isCancel = body.action === "cancel-transfer";
    const filterColumn = isCancel ? "from_user_id" : "to_user_id";
    const expectedUserId = caller.id;
    const { data: resolved, error: resolveError } = await adminClient
      .from("owner_transfers")
      .update({
        status: isCancel ? "cancelled" : "rejected",
        resolved_at: new Date().toISOString(),
      })
      .eq("id", body.transferId)
      .eq(filterColumn, expectedUserId)
      .eq("status", "pending")
      .select("id, status")
      .maybeSingle();
    if (resolveError) {
      console.error("Could not resolve ownership transfer:", resolveError.message);
      return json({ error: "Could not update the ownership transfer." }, 500);
    }
    if (!resolved) {
      return json({ error: "This transfer is no longer pending or you cannot resolve it." }, 409);
    }
    return json({ transfer: resolved });
  }

  if (body.action === "accept-transfer") {
    if (typeof body.transferId !== "string" || !body.transferId || body.transferId.length > 100) {
      return json({ error: "A valid transfer ID is required." }, 400);
    }

    let { data: transfer, error: transferError } = await adminClient
      .from("owner_transfers")
      .select("*")
      .eq("id", body.transferId)
      .maybeSingle();
    if (transferError) {
      console.error("Could not load ownership transfer:", transferError.message);
      return json({ error: "Could not load the ownership transfer." }, 500);
    }
    if (!transfer || transfer.to_user_id !== caller.id) {
      return json({ error: "This ownership request is not addressed to your account." }, 403);
    }
    if (transfer.status === "pending") {
      const { data: claimed, error: claimError } = await adminClient
        .from("owner_transfers")
        .update({
          status: "processing",
          accepted_at: new Date().toISOString(),
        })
        .eq("id", transfer.id)
        .eq("status", "pending")
        .select("*")
        .maybeSingle();
      if (claimError) {
        console.error("Could not accept ownership transfer:", claimError.message);
        return json({ error: "Could not accept the ownership transfer." }, 500);
      }
      if (!claimed) {
        return json({ error: "This request was already resolved. Refresh the page." }, 409);
      }
      transfer = claimed;
    } else if (transfer.status !== "processing") {
      return json({ error: "This ownership request is no longer active." }, 409);
    }

    const { data: { user: previousOwner }, error: previousOwnerError } =
      await adminClient.auth.admin.getUserById(transfer.from_user_id);
    const { data: { user: successor }, error: successorError } =
      await adminClient.auth.admin.getUserById(transfer.to_user_id);
    if (previousOwnerError || !previousOwner || successorError || !successor) {
      console.error("Could not load ownership transfer participants.", {
        previousOwnerError: previousOwnerError?.message,
        successorError: successorError?.message,
      });
      return json({ error: "Could not load the accounts involved. The transfer remains recoverable." }, 500);
    }

    const previousRole = previousOwner.app_metadata?.role;
    if (previousRole !== "Owner" && previousRole !== "Production Head") {
      return json({ error: "The current Owner's role changed unexpectedly. Contact the project administrator." }, 409);
    }

    if (successor.app_metadata?.role !== "Owner") {
      const { error: promoteError } = await setAppRole(adminClient, successor, "Owner");
      if (promoteError) {
        console.error("Could not promote ownership successor:", promoteError.message);
        return json({ error: "Could not promote the successor. The transfer remains processing; retry it from this account." }, 500);
      }
    }

    if (previousRole === "Owner") {
      const { error: demoteError } =
        await setAppRole(adminClient, previousOwner, "Production Head");
      if (demoteError) {
        console.error("Successor promoted, but previous Owner could not be demoted:", demoteError.message);
        return json({ error: "The successor is now an Owner, but the previous Owner could not be changed to Production Head. The transfer remains processing; retry it from the successor account." }, 500);
      }
    }

    const { data: completed, error: completeError } = await adminClient
      .from("owner_transfers")
      .update({
        status: "completed",
        resolved_at: new Date().toISOString(),
      })
      .eq("id", transfer.id)
      .eq("status", "processing")
      .select("id, status")
      .maybeSingle();
    if (completeError) {
      console.error("Roles updated but transfer status could not be completed:", completeError.message);
      return json({ error: "Roles were updated, but transfer completion could not be recorded. Retry to finalize it." }, 500);
    }
    if (!completed) {
      const { data: current, error: currentError } = await adminClient
        .from("owner_transfers")
        .select("status")
        .eq("id", transfer.id)
        .maybeSingle();
      if (currentError || current?.status !== "completed") {
        return json({ error: "Could not confirm transfer completion. Refresh and retry if it is still processing." }, 500);
      }
    }

    return json({
      transferId: transfer.id,
      status: "completed",
      newOwnerRole: "Owner",
      formerOwnerRole: "Production Head",
    });
  }

  return json({ error: "Unsupported account management action." }, 400);
});
