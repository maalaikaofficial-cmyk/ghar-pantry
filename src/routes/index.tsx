import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Ghar Pantry — Household Grocery Manager" },
      { name: "description", content: "Private household pantry, shopping and expense manager." },
      { property: "og:title", content: "Ghar Pantry" },
      { property: "og:description", content: "Private household pantry, shopping and expense manager." },
    ],
  }),
  component: Index,
});

function Index() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [household, setHousehold] = useState<string | null>(null);

  async function refresh() {
    const { data } = await supabase.auth.getUser();
    setUserId(data.user?.id ?? null);
    if (data.user) {
      const { data: hh } = await supabase.rpc("my_household");
      setHousehold((hh as string | null) ?? null);
    }
  }
  useEffect(() => {
    refresh();
  }, []);

  async function signIn(mode: "in" | "up") {
    if (busy) return;
    setMsg(null);
    if (!email.trim() || !password) {
      setMsg("Enter your admin email and password first.");
      return;
    }
    setBusy(true);
    try {
      const res = mode === "in"
        ? await supabase.auth.signInWithPassword({ email: email.trim(), password })
        : await supabase.auth.signUp({
            email: email.trim(),
            password,
            options: { emailRedirectTo: window.location.origin },
          });
      if (res.error) {
        setMsg("Authentication failed: " + res.error.message);
        return;
      }
      if (mode === "up" && !res.data.session) {
        setMsg("Check your email to confirm your account before signing in.");
        return;
      }
      const { data: userData, error: userError } = await supabase.auth.getUser();
      if (userError) throw userError;
      setUserId(userData.user?.id ?? null);
      if (!userData.user) {
        setMsg("No active session was returned. Check Supabase authentication settings.");
        return;
      }
      const { data: hh, error: hhError } = await supabase.rpc("my_household");
      if (hhError) {
        setMsg("Signed in, but household lookup failed: " + hhError.message);
      } else {
        setHousehold((hh as string | null) ?? null);
        if (hh) setMsg("Signed in successfully. The dashboard is still under development.");
      }
    } catch (error) {
      setMsg("Connection or configuration error: " + (error instanceof Error ? error.message : String(error)));
    } finally {
      setBusy(false);
    }
  }

  async function createHousehold() {
    const { error } = await supabase.rpc("create_household", { p_name: "Ghar", p_display_name: "Admin" });
    setMsg(error ? error.message : "Household created with the full catalog. All stock is UNKNOWN until you record opening balances.");
    refresh();
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center gap-4 bg-background p-6 text-foreground">
      <h1 className="text-3xl font-bold">Ghar Pantry</h1>
      <p lang="ur" dir="rtl" className="text-xl">گھر پینٹری</p>
      {!userId ? (
        <>
          <input className="rounded border border-input p-3" placeholder="Admin email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <input className="rounded border border-input p-3" type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
          <button className="rounded bg-primary p-3 text-primary-foreground" disabled={busy} onClick={() => signIn("in")}>{busy ? "Please wait…" : "Admin sign in"}</button>
          <button className="rounded border border-input p-3" disabled={busy} onClick={() => signIn("up")}>Create admin account</button>
        </>
      ) : !household ? (
        <button className="rounded bg-primary p-3 text-primary-foreground" onClick={createHousehold}>Set up my household</button>
      ) : (
        <p className="text-muted-foreground">Signed in. The admin dashboard and housekeeper screens are still being built.</p>
      )}
      {userId && (
        <button className="text-sm underline" onClick={async () => { await supabase.auth.signOut(); refresh(); }}>Sign out</button>
      )}
      {msg && <p role="alert" aria-live="polite" className="rounded border border-input bg-muted p-3 text-sm">{msg}</p>}
    </main>
  );
}