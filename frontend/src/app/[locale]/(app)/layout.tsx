import { TenantProfileProvider } from "@/lib/TenantProfileContext";
import AppShell from "@/components/AppShell";

export default function AuthenticatedLayout({ children }: { children: React.ReactNode }) {
  return (
    <TenantProfileProvider>
      <AppShell>{children}</AppShell>
    </TenantProfileProvider>
  );
}
