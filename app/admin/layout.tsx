import type { ReactNode } from "react"
import { AdminUnsettledWithdrawalAlert } from "@/components/admin-unsettled-withdrawal-alert"

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <div className="px-4 pt-4">
        <AdminUnsettledWithdrawalAlert />
      </div>
      {children}
    </>
  )
}
