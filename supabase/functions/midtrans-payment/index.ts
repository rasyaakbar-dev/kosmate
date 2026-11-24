import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonResponse = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const paymentFields =
  "payment_id, user_id, room_id, amount, status, order_id, transaction_id, payment_type, qr_code_url, deeplink_url, paid_date";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const authorization = request.headers.get("Authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return jsonResponse(401, { error: "Authentication is required." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY");
  if (!supabaseUrl || !serviceRoleKey || !serverKey) {
    console.error("Payment function is missing required server configuration.");
    return jsonResponse(500, { error: "Payment service is not configured." });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const {
      data: { user },
      error: authError,
    } = await admin.auth.getUser(token);
    if (authError || !user) {
      return jsonResponse(401, { error: "Authentication is invalid or expired." });
    }

    const body = await request.json();
    const action = body?.action;
    const paymentId = Number(body?.paymentId);
    if (
      !["charge", "status", "cancel"].includes(action) ||
      !Number.isSafeInteger(paymentId) ||
      paymentId <= 0
    ) {
      return jsonResponse(400, { error: "A valid action and payment ID are required." });
    }

    const { data: profile, error: profileError } = await admin
      .from("users")
      .select("user_id, name, email, phone, role")
      .eq("auth_id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.role !== "tenant") {
      return jsonResponse(403, { error: "Only the invoice tenant can manage this payment." });
    }

    const { data: payment, error: paymentError } = await admin
      .from("payment")
      .select(paymentFields)
      .eq("payment_id", paymentId)
      .maybeSingle();
    if (paymentError) throw paymentError;
    if (!payment || payment.user_id !== profile.user_id) {
      return jsonResponse(404, { error: "Payment was not found." });
    }
    if (payment.status !== "pending") {
      return jsonResponse(409, { error: "Only pending payments can be managed." });
    }

    const baseUrl =
      Deno.env.get("MIDTRANS_BASE_URL") ??
      "https://api.sandbox.midtrans.com/v2";
    if (
      ![
        "https://api.sandbox.midtrans.com/v2",
        "https://api.midtrans.com/v2",
      ].includes(baseUrl)
    ) {
      console.error("Payment function has an invalid Midtrans base URL.");
      return jsonResponse(500, { error: "Payment service is not configured." });
    }
    const midtransRequest = async (
      path: string,
      method: "GET" | "POST",
      payload?: Record<string, unknown>,
    ) => {
      const response = await fetch(`${baseUrl}/${path}`, {
        method,
        headers: {
          Accept: "application/json",
          Authorization: `Basic ${btoa(`${serverKey}:`)}`,
          ...(payload ? { "Content-Type": "application/json" } : {}),
        },
        ...(payload ? { body: JSON.stringify(payload) } : {}),
      });
      const responseBody = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(
          responseBody.status_message ??
            `Payment provider returned status ${response.status}.`,
        );
      }
      return responseBody;
    };

    if (action === "charge") {
      if (payment.order_id && payment.qr_code_url) {
        return jsonResponse(200, { payment });
      }
      if (payment.order_id) {
        return jsonResponse(409, { error: "Payment setup is already in progress." });
      }

      const orderId = `KOSMATE-INV-${paymentId}-${crypto.randomUUID()}`;
      const { data: claimed, error: claimError } = await admin
        .from("payment")
        .update({ order_id: orderId })
        .eq("payment_id", paymentId)
        .eq("status", "pending")
        .is("order_id", null)
        .select(paymentFields)
        .maybeSingle();
      if (claimError) throw claimError;
      if (!claimed) {
        return jsonResponse(409, { error: "Payment setup is already in progress." });
      }

      let charge: Record<string, unknown>;
      try {
        charge = await midtransRequest("charge", "POST", {
          payment_type: "gopay",
          transaction_details: {
            order_id: orderId,
            gross_amount: Math.round(Number(payment.amount)),
          },
          customer_details: {
            first_name: profile.name,
            email: profile.email,
            phone: profile.phone,
          },
          gopay: {
            enable_callback: true,
            callback_url: "kosmate://payment-finish",
          },
        });
      } catch (error) {
        await admin
          .from("payment")
          .update({ order_id: null })
          .eq("payment_id", paymentId)
          .eq("status", "pending")
          .eq("order_id", orderId);
        throw error;
      }

      const actions = Array.isArray(charge.actions) ? charge.actions : [];
      const { data: updated, error: updateError } = await admin
        .from("payment")
        .update({
          transaction_id: charge.transaction_id ?? null,
          payment_type: charge.payment_type ?? "gopay",
          qr_code_url:
            actions.find((item: { name?: string; url?: string }) =>
              item.name === "generate-qr-code"
            )?.url ?? null,
          deeplink_url:
            actions.find((item: { name?: string; url?: string }) =>
              item.name === "deeplink-redirect"
            )?.url ?? null,
        })
        .eq("payment_id", paymentId)
        .eq("status", "pending")
        .eq("order_id", orderId)
        .select(paymentFields)
        .single();
      if (updateError) throw updateError;
      return jsonResponse(200, { payment: updated });
    }

    if (!payment.order_id) {
      return jsonResponse(409, { error: "This payment has no active transaction." });
    }

    if (action === "status") {
      const status = await midtransRequest(
        `${encodeURIComponent(payment.order_id)}/status`,
        "GET",
      );
      if (
        status.transaction_status === "settlement" ||
        status.transaction_status === "capture"
      ) {
        const { data: updated, error } = await admin
          .from("payment")
          .update({
            status: "paid",
            paid_date: new Date().toISOString().slice(0, 10),
          })
          .eq("payment_id", paymentId)
          .eq("status", "pending")
          .eq("order_id", payment.order_id)
          .select(paymentFields)
          .single();
        if (error) throw error;
        return jsonResponse(200, { payment: updated });
      }
      if (["expire", "cancel", "deny"].includes(status.transaction_status)) {
        const { data: updated, error } = await admin
          .from("payment")
          .update({
            order_id: null,
            transaction_id: null,
            payment_type: null,
            qr_code_url: null,
            deeplink_url: null,
          })
          .eq("payment_id", paymentId)
          .eq("status", "pending")
          .eq("order_id", payment.order_id)
          .select(paymentFields)
          .single();
        if (error) throw error;
        return jsonResponse(200, { payment: updated });
      }
      return jsonResponse(200, { payment });
    }

    await midtransRequest(
      `${encodeURIComponent(payment.order_id)}/cancel`,
      "POST",
    );
    const { data: updated, error } = await admin
      .from("payment")
      .update({
        order_id: null,
        transaction_id: null,
        payment_type: null,
        qr_code_url: null,
        deeplink_url: null,
      })
      .eq("payment_id", paymentId)
      .eq("status", "pending")
      .eq("order_id", payment.order_id)
      .select(paymentFields)
      .single();
    if (error) throw error;
    return jsonResponse(200, { payment: updated });
  } catch (error) {
    console.error("Payment operation failed:", error);
    return jsonResponse(502, {
      error: error instanceof Error ? error.message : "Payment operation failed.",
    });
  }
});
