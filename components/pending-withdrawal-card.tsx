"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Clock, DollarSign, AlertTriangle, ExternalLink, CheckCircle } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"
import { RewardTaskPopup } from "./reward-task-popup"

interface PendingWithdrawalCardProps {
  userId: string
}

interface WithdrawalData {
  amount: number
  type: 'no_withdrawal' | 'pending_withdrawal'
  status?: string
  latest_month?: string | null
  task_required?: boolean
  task_completed?: boolean
}

export function PendingWithdrawalCard({ userId }: PendingWithdrawalCardProps) {
  const [withdrawalData, setWithdrawalData] = useState<WithdrawalData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [showTaskPopup, setShowTaskPopup] = useState(false)

  useEffect(() => {
    if (userId) {
      fetchWithdrawalData()
    }
  }, [userId])

  // タスク未完了の出金申請がある場合は自動的にポップアップ表示
  useEffect(() => {
    if (withdrawalData?.type === 'pending_withdrawal' &&
        withdrawalData?.task_required &&
        !withdrawalData?.task_completed) {
      setShowTaskPopup(true)
    }
  }, [withdrawalData])

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
          latest_month: latestWithdrawal.withdrawal_month,
          task_required: latestWithdrawal.status === 'on_hold',
          task_completed: latestWithdrawal.task_completed || false
        })
        return
      }

      // 2. 保留中の出金がない場合は「出金なし」を表示
      setWithdrawalData({
        amount: 0,
        type: 'no_withdrawal',
        task_required: false,
        task_completed: false
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
  const isNoWithdrawal = withdrawalData?.type === 'no_withdrawal'
  const needsTask = withdrawalData?.task_required && !withdrawalData?.task_completed

  const handleTaskComplete = async () => {
    await fetchWithdrawalData() // Refresh data after task completion
    setShowTaskPopup(false) // タスク完了後にポップアップを閉じる
  }

  return (
    <>
      <RewardTaskPopup
        userId={userId}
        isOpen={showTaskPopup}
        onComplete={handleTaskComplete}
      />
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="p-3 pb-2">
        <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金状況</CardTitle>
      </CardHeader>
      <CardContent className="p-3 pt-0">
        {isPendingWithdrawal ? (
          <>
            <div className="flex items-center space-x-1">
              <DollarSign className="h-4 w-4 flex-shrink-0 text-orange-400" />
              <span className="text-base md:text-xl lg:text-2xl font-bold truncate text-orange-400">
                ${displayAmount.toFixed(3)}
              </span>
            </div>
            <div className="text-xs text-gray-500 mt-1">
              <div>
                {withdrawalData?.status === 'pending' && '送金処理中'}
                {withdrawalData?.status === 'on_hold' && !withdrawalData?.task_completed && (
                  <div className="flex items-center gap-1">
                    <span>アンケートタスク待ち</span>
                    <Button
                      onClick={() => setShowTaskPopup(true)}
                      size="sm"
                      className="text-xs bg-yellow-600 hover:bg-yellow-700 px-2 py-1 h-auto"
                    >
                      開始
                    </Button>
                  </div>
                )}
                {withdrawalData?.status === 'on_hold' && withdrawalData?.task_completed && (
                  <div className="flex items-center gap-1 text-green-400">
                    <CheckCircle className="h-3 w-3" />
                    タスク完了済み・処理待ち
                  </div>
                )}
                {withdrawalData?.latest_month && ` (${formatMonth(withdrawalData.latest_month)})`}
              </div>
            </div>
          </>
        ) : (
          <div className="text-center py-4">
            <p className="text-gray-400 text-sm">現在、処理中の出金申請はありません</p>
          </div>
        )}
      </CardContent>
    </Card>
    </>
  )
}

