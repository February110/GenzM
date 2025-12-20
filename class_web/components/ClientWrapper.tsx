// components/ClientWrapper.tsx
"use client";

import ClientProviders from "@/components/ClientProviders";
import { Toaster } from "react-hot-toast";

/**
 * Quy ước:
 * - Admin shell tự quản lý header/guard riêng
 */
export default function ClientWrapper({ children }: { children: React.ReactNode }) {
  return (
    <ClientProviders>
      {children}
      <Toaster position="top-right" toastOptions={{ duration: 3000 }} />
    </ClientProviders>
  );
}

