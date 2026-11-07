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
    setMsg(null);
    const res =
      mode === "in"
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({ email, password, options: { emailRedirectTo: window.location.origin } });
    if (res.error) return setMsg(res.error.message);
    if (mode === "up" && !res.data.session) return setMsg("Check your email to confirm your account.");
    refresh();
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
          <button className="rounded bg-primary p-3 text-primary-foreground" onClick={() => signIn("in")}>Admin sign in</button>
          <button className="rounded border border-input p-3" onClick={() => signIn("up")}>Create admin account</button>
        </>
      ) : !household ? (
        <button className="rounded bg-primary p-3 text-primary-foreground" onClick={createHousehold}>Set up my household</button>
      ) : (
        <p className="text-muted-foreground">Signed in. The admin dashboard and housekeeper screens are still being built.</p>
      )}
      {userId && (
        <button className="text-sm underline" onClick={async () => { await supabase.auth.signOut(); refresh(); }}>Sign out</button>
      )}
      {msg && <p className="text-sm">{msg}</p>}
    </main>
  );
}