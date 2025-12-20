"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "@/components/admin/Sidebar";
import AdminTopbar from "@/components/admin/Topbar";
import { useAuth } from "@/context/AuthContext";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, loading, logout } = useAuth();

  useEffect(() => {
    if (loading) return;
    if (!user) {
      router.replace("/auth/login");
      return;
    }
    if ((user.systemRole || "").toLowerCase() !== "admin") {
      logout();
      router.replace("/auth/login");
    }
  }, [user, loading, logout, router]);

  if (loading || !user || (user.systemRole || "").toLowerCase() !== "admin") {
    return <div className="min-h-screen flex items-center justify-center text-gray-500">Đang kiểm tra quyền truy cập...</div>;
  }

  return (
    <div className="min-h-screen flex bg-gray-50 dark:bg-black">
      <AdminSidebar />
      <div className="flex-1 flex flex-col">
        <AdminTopbar />
        <main className="p-4 md:p-6 lg:p-8">
          {children}
        </main>
      </div>
    </div>
  );
}
