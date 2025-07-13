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

interface WithdrawalData {
  amount: number
  type: 'monthly_profit' | 'pending_withdrawal'
  status?: string
  latest_month?: string | null
}

export function PendingWithdrawalCard({ userId }: PendingWithdrawalCardProps) {
  const [withdrawalData, setWithdrawalData] = useState<WithdrawalData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchWithdrawalData()
    }
  }, [userId])

  const fetchWithdrawalData = async () => {
    try {
      setLoading(true)
      setError("")

      // 1. まず月次出金システムの保留中データを確認
      const { data: pendingWithdrawals, error: withdrawalError } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("user_id", userId)
        .in("status", ["pending", "on_hold"])
        .order("withdrawal_month", { ascending: false })

      if (withdrawalError && withdrawalError.code !== "PGRST116") {
        throw withdrawalError
      }

      // 保留中の出金がある場合はその金額を表示
      if (pendingWithdrawals && pendingWithdrawals.length > 0) {
        const totalPendingAmount = pendingWithdrawals.reduce((sum, w) => sum + Number(w.total_amount), 0)
        const latestWithdrawal = pendingWithdrawals[0]
        
        setWithdrawalData({
          amount: totalPendingAmount,
          type: 'pending_withdrawal',
          status: latestWithdrawal.status,
          latest_month: latestWithdrawal.withdrawal_month
        })
        return
      }

      // 2. 保留中の出金がない場合は今月の累積利益を表示
      const now = new Date()
      const year = now.getFullYear()
      const month = now.getMonth()
      const monthStart = new Date(Date.UTC(year, month, 1)).toISOString().split('T')[0]
      const monthEnd = new Date(Date.UTC(year, month + 1, 0)).toISOString().split('T')[0]

      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (profitError) {
        throw profitError
      }

      // 今月の累積利益を計算
      const monthlyProfit = profitData?.reduce((sum, record) => {
        const dailyValue = parseFloat(record.daily_profit) || 0
        return sum + dailyValue
      }, 0) || 0

      setWithdrawalData({
        amount: monthlyProfit,
        type: 'monthly_profit'
      })

    } catch (err: any) {
      console.error("Error fetching withdrawal data:", err)
      setError("出金情報の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const formatMonth = (dateString: string) => {
    const date = new Date(dateString)
    return `${date.getFullYear()}年${date.getMonth() + 1}月`
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="p-3 pb-2">
          <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金状況</CardTitle>
        </CardHeader>
        <CardContent className="p-3 pt-0">
          <div className="text-center text-gray-400 text-sm">読み込み中...</div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="p-3 pb-2">
          <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金状況</CardTitle>
        </CardHeader>
        <CardContent className="p-3 pt-0">
          <div className="text-center text-red-400 text-sm">{error}</div>
        </CardContent>
      </Card>
    )
  }

  const displayAmount = withdrawalData?.amount || 0
  const isPendingWithdrawal = withdrawalData?.type === 'pending_withdrawal'
  const isMonthlyProfit = withdrawalData?.type === 'monthly_profit'

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="p-3 pb-2">
        <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金状況</CardTitle>
      </CardHeader>
      <CardContent className="p-3 pt-0">
        <div className="flex items-center space-x-1">
          <DollarSign className={`h-4 w-4 flex-shrink-0 ${
            isPendingWithdrawal ? 'text-orange-400' : 'text-purple-400'
          }`} />
          <span className={`text-base md:text-xl lg:text-2xl font-bold truncate ${
            isPendingWithdrawal ? 'text-orange-400' : 'text-purple-400'
          }`}>
            ${displayAmount.toFixed(3)}
          </span>
        </div>
        <div className="text-xs text-gray-500 mt-1">
          {isPendingWithdrawal && (
            <div>
              {withdrawalData?.status === 'pending' && '送金処理中'}
              {withdrawalData?.status === 'on_hold' && '保留中'}
              {withdrawalData?.latest_month && ` (${formatMonth(withdrawalData.latest_month)})`}
            </div>
          )}
          {isMonthlyProfit && (
            <div>今月の累積利益（月末に出金処理）</div>
          )}
          {displayAmount === 0 && (
            <div>出金なし</div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

