"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Clock, DollarSign, AlertTriangle, ExternalLink } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface PendingWithdrawalCardProps {
  userId: string
}

interface WithdrawalSummary {
  pending_amount: number
  on_hold_amount: number
  pending_count: number
  on_hold_count: number
  latest_month: string | null
}

export function PendingWithdrawalCard({ userId }: PendingWithdrawalCardProps) {
  const [summary, setSummary] = useState<WithdrawalSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchWithdrawalSummary()
    }
  }, [userId])

  const fetchWithdrawalSummary = async () => {
    try {
      setLoading(true)
      setError("")

      // 過去6ヶ月の出金記録を取得
      const sixMonthsAgo = new Date()
      sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6)

      const { data, error } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("user_id", userId)
        .gte("withdrawal_month", sixMonthsAgo.toISOString().split('T')[0])
        .in("status", ["pending", "on_hold"])

      if (error && error.code !== "PGRST116") {
        throw error
      }

      const withdrawals = data || []
      
      const summary: WithdrawalSummary = {
        pending_amount: withdrawals
          .filter(w => w.status === "pending")
          .reduce((sum, w) => sum + Number(w.total_amount), 0),
        on_hold_amount: withdrawals
          .filter(w => w.status === "on_hold")
          .reduce((sum, w) => sum + Number(w.total_amount), 0),
        pending_count: withdrawals.filter(w => w.status === "pending").length,
        on_hold_count: withdrawals.filter(w => w.status === "on_hold").length,
        latest_month: withdrawals.length > 0 
          ? withdrawals.sort((a, b) => new Date(b.withdrawal_month).getTime() - new Date(a.withdrawal_month).getTime())[0].withdrawal_month
          : null
      }

      setSummary(summary)
    } catch (err: any) {
      console.error("Error fetching withdrawal summary:", err)
      setError("出金情報の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const formatMonth = (dateString: string) => {
    const date = new Date(dateString)
    return `${date.getFullYear()}年${date.getMonth() + 1}月`
  }

  const totalAmount = (summary?.pending_amount || 0) + (summary?.on_hold_amount || 0)
  const hasWithdrawals = totalAmount > 0

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="text-center text-gray-400">読み込み中...</div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="text-center text-red-400 text-sm">{error}</div>
        </CardContent>
      </Card>
    )
  }

  if (!hasWithdrawals) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="p-3 pb-2">
          <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金状況</CardTitle>
        </CardHeader>
        <CardContent className="p-3 pt-0">
          <div className="flex items-center space-x-1">
            <DollarSign className="h-4 w-4 text-green-400 flex-shrink-0" />
            <span className="text-base md:text-xl lg:text-2xl font-bold text-green-400">$0.00</span>
          </div>
          <p className="text-xs text-gray-500 mt-1">保留中の出金なし</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="p-3 pb-2">
        <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金状況</CardTitle>
      </CardHeader>
      <CardContent className="p-3 pt-0">
        <div className="flex items-center space-x-1">
          <DollarSign className="h-4 w-4 text-blue-400 flex-shrink-0" />
          <span className="text-base md:text-xl lg:text-2xl font-bold text-blue-400 truncate">
            ${totalAmount.toFixed(2)}
          </span>
        </div>
        <div className="text-xs text-gray-500 mt-1 space-y-1">
          {summary && summary.pending_amount > 0 && (
            <div>送金待ち: ${summary.pending_amount.toFixed(2)}</div>
          )}
          {summary && summary.on_hold_amount > 0 && (
            <div>保留中: ${summary.on_hold_amount.toFixed(2)}</div>
          )}
          {!summary?.pending_amount && !summary?.on_hold_amount && (
            <div>保留中の出金なし</div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

