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
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">出金状況</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center space-x-2">
            <DollarSign className="h-5 w-5 text-green-400" />
            <span className="text-2xl font-bold text-green-400">$0.00</span>
          </div>
          <p className="text-xs text-gray-500 mt-1">保留中の出金なし</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-gray-300 text-sm font-medium">出金状況</CardTitle>
          <Link href="/profile">
            <Button variant="outline" size="sm" className="border-gray-600 text-gray-300 hover:bg-gray-700">
              <ExternalLink className="h-3 w-3" />
            </Button>
          </Link>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* 送金待ち */}
        {summary && summary.pending_amount > 0 && (
          <div className="flex items-center justify-between p-3 bg-green-900/20 rounded-lg">
            <div className="flex items-center space-x-2">
              <Clock className="h-4 w-4 text-green-400" />
              <div>
                <p className="text-sm font-medium text-green-300">送金待ち</p>
                <p className="text-xs text-gray-400">{summary.pending_count}件</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-lg font-bold text-green-400">
                ${summary.pending_amount.toFixed(2)}
              </p>
            </div>
          </div>
        )}

        {/* 保留中 */}
        {summary && summary.on_hold_amount > 0 && (
          <div className="flex items-center justify-between p-3 bg-yellow-900/20 rounded-lg">
            <div className="flex items-center space-x-2">
              <AlertTriangle className="h-4 w-4 text-yellow-400" />
              <div>
                <p className="text-sm font-medium text-yellow-300">保留中</p>
                <p className="text-xs text-gray-400">送金先設定が必要</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-lg font-bold text-yellow-400">
                ${summary.on_hold_amount.toFixed(2)}
              </p>
            </div>
          </div>
        )}

        {/* 合計 */}
        <div className="border-t border-gray-600/30 pt-3">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-white">合計出金予定額</p>
              {summary?.latest_month && (
                <p className="text-xs text-gray-400">
                  最新: {formatMonth(summary.latest_month)}
                </p>
              )}
            </div>
            <div className="text-right">
              <p className="text-xl font-bold text-blue-400">
                ${totalAmount.toFixed(2)}
              </p>
            </div>
          </div>
        </div>

        {/* 保留中の場合の案内 */}
        {summary && summary.on_hold_amount > 0 && (
          <div className="text-xs text-gray-400 bg-gray-700/50 p-2 rounded">
            プロフィール画面で報酬受取アドレスを設定すると送金されます
          </div>
        )}
      </CardContent>
    </Card>
  )
}

