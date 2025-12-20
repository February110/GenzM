"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import api from "@/api/client";
import { useAuth } from "@/context/AuthContext";

export default function AdminLoginPage() {
  const router = useRouter();
  const { user, setUser } = useAuth();
  const [form, setForm] = useState({ email: "", password: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const role = (user?.systemRole || "").toLowerCase();
    if (role === "admin") {
      router.replace("/admin");
      return;
    }
    if (user && role !== "admin") {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      setUser(null);
    }
  }, [router, user]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (loading) return;
    setLoading(true);
    setError("");
    try {
      const res = await api.post("/auth/login", form);
      const token =
        res.data.accessToken ||
        res.data.token ||
        res.data.AccessToken ||
        res.data.Access_Token;

      if (!token) throw new Error("Không nhận được token từ server");

      const rawRole = (res.data.systemRole || res.data.SystemRole || "Admin")
        .toString()
        .trim();
      const normalizedRole =
        rawRole.toLowerCase() === "admin" ? "Admin" : rawRole;

      if (normalizedRole.toLowerCase() !== "admin") {
        localStorage.removeItem("token");
        localStorage.removeItem("user");
        setUser(null);
        setError("Tài khoản không có quyền admin.");
        return;
      }

      const normalizedUser = {
        id: res.data.id || res.data.Id || "",
        fullName: res.data.fullName || res.data.FullName || "Admin",
        email: res.data.email || form.email,
        avatar: res.data.avatar,
        systemRole: normalizedRole,
      };

      localStorage.setItem("token", token);
      localStorage.setItem("user", JSON.stringify(normalizedUser));
      document.cookie = `token=${token}; path=/; max-age=604800; SameSite=Lax;`;
      setUser(normalizedUser);
      router.replace("/admin");
    } catch (err: any) {
      setError(err?.response?.data?.message || "Đăng nhập thất bại");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="font-space relative min-h-screen overflow-hidden bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <div className="absolute inset-0">
        <div className="absolute inset-0 bg-gradient-to-br from-white via-slate-50 to-indigo-100/70 dark:from-slate-950 dark:via-slate-950 dark:to-indigo-950/60" />
        <div className="absolute -top-24 left-1/2 h-72 w-72 -translate-x-1/2 rounded-full bg-indigo-500/20 blur-3xl dark:bg-indigo-500/30" />
        <div className="absolute -bottom-32 right-8 h-80 w-80 rounded-full bg-cyan-400/20 blur-3xl dark:bg-cyan-400/20" />
        <div className="absolute inset-0 opacity-40 [background-image:linear-gradient(transparent_95%,rgba(15,23,42,0.08)),linear-gradient(90deg,transparent_95%,rgba(15,23,42,0.08))] [background-size:24px_24px] dark:[background-image:linear-gradient(transparent_95%,rgba(148,163,184,0.12)),linear-gradient(90deg,transparent_95%,rgba(148,163,184,0.12))]" />
      </div>

      <div className="relative z-10 mx-auto flex min-h-screen max-w-6xl items-center px-6 py-12">
        <div className="grid w-full items-center gap-10 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="space-y-6 animate-fadeIn" style={{ animationDelay: "80ms" }}>
            <div className="inline-flex items-center gap-2 rounded-full border border-indigo-100 bg-white/70 px-4 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-indigo-600 shadow-sm dark:border-indigo-500/30 dark:bg-indigo-500/10 dark:text-indigo-300">
              <span className="h-2 w-2 rounded-full bg-indigo-500" />
              Admin Control
            </div>

            <h1 className="text-4xl font-semibold leading-tight md:text-5xl">
              Trung tâm quản trị
              <span className="block text-indigo-600 dark:text-indigo-400">
                GenzLearning
              </span>
            </h1>

            <p className="max-w-xl text-base text-slate-600 dark:text-slate-400">
              Quản lý hệ thống học tập, theo dõi hoạt động, và kiểm soát truy
              cập trong một giao diện tập trung dành cho admin.
            </p>

            <div className="grid gap-3 sm:grid-cols-2">
              <div className="rounded-2xl border border-slate-200/70 bg-white/70 p-4 shadow-sm backdrop-blur dark:border-slate-800 dark:bg-zinc-950/60">
                <div className="text-xs uppercase tracking-[0.15em] text-slate-400">
                  Bảo mật
                </div>
                <div className="mt-1 text-lg font-semibold">
                  Kiểm soát truy cập
                </div>
                <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                  Chỉ tài khoản admin được phép truy cập.
                </p>
              </div>
              <div className="rounded-2xl border border-slate-200/70 bg-white/70 p-4 shadow-sm backdrop-blur dark:border-slate-800 dark:bg-zinc-950/60">
                <div className="text-xs uppercase tracking-[0.15em] text-slate-400">
                  Vận hành
                </div>
                <div className="mt-1 text-lg font-semibold">
                  Báo cáo tổng quan
                </div>
                <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                  Cập nhật hoạt động trong thời gian thực.
                </p>
              </div>
            </div>
          </div>

          <div className="relative animate-fadeIn" style={{ animationDelay: "160ms" }}>
            <div className="absolute -inset-2 rounded-[28px] bg-gradient-to-r from-indigo-500/20 via-sky-400/20 to-emerald-300/10 blur-xl" />
            <div className="relative rounded-[28px] border border-slate-200/70 bg-white/80 p-8 shadow-xl backdrop-blur dark:border-slate-800 dark:bg-zinc-950/70">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-xs uppercase tracking-[0.35em] text-slate-400">
                    Admin Login
                  </p>
                  <h2 className="mt-2 text-2xl font-semibold">
                    Đăng nhập hệ thống
                  </h2>
                </div>
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-900 text-lg font-semibold text-white shadow-sm dark:bg-white dark:text-slate-900">
                  A
                </div>
              </div>

              <form onSubmit={handleSubmit} className="mt-6 space-y-4">
                <div>
                  <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">
                    Email
                  </label>
                  <input
                    type="email"
                    required
                    autoComplete="email"
                    value={form.email}
                    onChange={(e) =>
                      setForm((p) => ({ ...p, email: e.target.value }))
                    }
                    className="mt-1 w-full rounded-xl border border-slate-200/70 bg-white/70 px-3 py-2 text-sm text-slate-900 focus:border-indigo-400 focus:outline-none focus:ring-2 focus:ring-indigo-200 dark:border-slate-700 dark:bg-zinc-900/70 dark:text-slate-100 dark:focus:ring-indigo-500/30"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">
                    Mật khẩu
                  </label>
                  <input
                    type="password"
                    required
                    autoComplete="current-password"
                    value={form.password}
                    onChange={(e) =>
                      setForm((p) => ({ ...p, password: e.target.value }))
                    }
                    className="mt-1 w-full rounded-xl border border-slate-200/70 bg-white/70 px-3 py-2 text-sm text-slate-900 focus:border-indigo-400 focus:outline-none focus:ring-2 focus:ring-indigo-200 dark:border-slate-700 dark:bg-zinc-900/70 dark:text-slate-100 dark:focus:ring-indigo-500/30"
                  />
                </div>

                {error && (
                  <div
                    role="alert"
                    className="rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-600 dark:border-rose-500/30 dark:bg-rose-500/10 dark:text-rose-300"
                  >
                    {error}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full rounded-full bg-gradient-to-r from-indigo-600 via-blue-600 to-sky-500 py-2.5 text-sm font-semibold text-white shadow-lg shadow-indigo-500/20 transition hover:from-indigo-500 hover:via-blue-500 hover:to-sky-400 disabled:cursor-not-allowed disabled:opacity-60 disabled:shadow-none"
                >
                  {loading ? "Đang đăng nhập..." : "Đăng nhập"}
                </button>
              </form>

              <div className="mt-6 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
                <span>Chỉ admin được phép truy cập.</span>
                <span className="rounded-full bg-slate-900 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-white dark:bg-white dark:text-slate-900">
                  Secure
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
