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

interface WithdrawalRecord {
  id: string
  withdrawal_month: string
  total_amount: number
  personal_amount: number
  referral_amount: number
  status: string
  task_completed: boolean
  created_at: string
}

interface CycleData {
  phase: string
  cum_usdt: number
  withdrawn_referral_usdt: number
  auto_nft_count: number
}

interface WithdrawalData {
  pending_withdrawals: WithdrawalRecord[]
  completed_withdrawals: WithdrawalRecord[]
  cycle_data: CycleData | null
  has_data: boolean
}

// 現在月または前月かどうかをチェックするヘルパー関数
const isRecentMonth = (withdrawalMonth: string): boolean => {
  const now = new Date()
  const currentYear = now.getFullYear()
  const currentMonth = now.getMonth() + 1 // 0-indexed to 1-indexed
  const prevMonth = currentMonth === 1 ? 12 : currentMonth - 1
  const prevYear = currentMonth === 1 ? currentYear - 1 : currentYear

  // withdrawal_monthからYYYY-MMを抽出
  const monthStr = withdrawalMonth.substring(0, 7) // "YYYY-MM"
  const [yearStr, monthNumStr] = monthStr.split('-')
  const wYear = parseInt(yearStr, 10)
  const wMonth = parseInt(monthNumStr, 10)

  // 現在月または前月のみtrue
  const isCurrentMonth = wYear === currentYear && wMonth === currentMonth
  const isPrevMonth = wYear === prevYear && wMonth === prevMonth

  return isCurrentMonth || isPrevMonth
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
  // ただし、現在月または前月の出金のみ対象（古い月のループ防止）
  useEffect(() => {
    if (withdrawalData?.pending_withdrawals) {
      const hasUncompletedTask = withdrawalData.pending_withdrawals.some(w =>
        w.status === 'on_hold' &&
        !w.task_completed &&
        isRecentMonth(w.withdrawal_month)
      )

      if (hasUncompletedTask) {
        setShowTaskPopup(true)
      }
    }
  }, [withdrawalData])

  const fetchWithdrawalData = async () => {
    try {
      setLoading(true)
      setError("")

      // 保留中の出金を取得（on_hold, pending）
      const { data: pendingWithdrawals, error: pendingError } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("user_id", userId)
        .in("status", ["pending", "on_hold"])
        .order("withdrawal_month", { ascending: false })

      if (pendingError && pendingError.code !== "PGRST116") {
        throw pendingError
      }

      // 完了済みの出金を取得（completed）
      const { data: completedWithdrawals, error: completedError } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("user_id", userId)
        .eq("status", "completed")
        .order("withdrawal_month", { ascending: false })
        .limit(10) // 最新10件のみ

      if (completedError && completedError.code !== "PGRST116") {
        throw completedError
      }

      // affiliate_cycleからフェーズ情報を取得
      const { data: cycleData, error: cycleError } = await supabase
        .from("affiliate_cycle")
        .select("phase, cum_usdt, withdrawn_referral_usdt, auto_nft_count")
        .eq("user_id", userId)
        .single()

      if (cycleError && cycleError.code !== "PGRST116") {
        console.error("Error fetching cycle data:", cycleError)
      }

      const hasData = (pendingWithdrawals && pendingWithdrawals.length > 0) ||
                      (completedWithdrawals && completedWithdrawals.length > 0)

      setWithdrawalData({
        pending_withdrawals: pendingWithdrawals || [],
        completed_withdrawals: completedWithdrawals || [],
        cycle_data: cycleData || null,
        has_data: hasData
      })

    } catch (err: any) {
      console.error("Error fetching withdrawal data:", err)
      setError("出金情報の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const formatMonth = (dateString: string) => {
    // YYYY-MM形式の場合はそのまま解析
    if (dateString.length === 7) {
      const [year, month] = dateString.split('-')
      return `${year}年${parseInt(month)}月`
    }
    // YYYY-MM-DD形式の場合はUTCとして解析
    const date = new Date(dateString + 'T00:00:00Z')
    return `${date.getUTCFullYear()}年${date.getUTCMonth() + 1}月`
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

  const handleTaskComplete = async () => {
    await fetchWithdrawalData() // Refresh data after task completion
    setShowTaskPopup(false) // タスク完了後にポップアップを閉じる
  }

  const getStatusBadge = (status: string, taskCompleted: boolean) => {
    if (status === 'on_hold' && !taskCompleted) {
      return <Badge className="bg-yellow-600 text-white text-xs">タスク待ち</Badge>
    }
    if (status === 'on_hold' && taskCompleted) {
      return <Badge className="bg-blue-600 text-white text-xs">処理待ち</Badge>
    }
    if (status === 'pending') {
      return <Badge className="bg-orange-600 text-white text-xs">送金処理中</Badge>
    }
    if (status === 'completed') {
      return <Badge className="bg-green-600 text-white text-xs">完了</Badge>
    }
    return null
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
        <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">出金履歴</CardTitle>
      </CardHeader>
      <CardContent className="p-3 pt-0">
        {!withdrawalData?.has_data ? (
          <div className="text-center py-4">
            <p className="text-gray-400 text-sm">出金履歴はありません</p>
          </div>
        ) : (
          <div className="space-y-3">
            {/* HOLDフェーズの場合の情報表示 */}
            {withdrawalData.cycle_data?.phase === 'HOLD' && withdrawalData.cycle_data.cum_usdt >= 1100 && (() => {
              const cd = withdrawalData.cycle_data!
              const autoNftCount = cd.auto_nft_count || 0
              const totalPayoutEver = autoNftCount * 1100 + Math.min(Math.max(cd.cum_usdt, 0), 1100)
              const withdrawableReferral = Math.max(0, totalPayoutEver - (cd.withdrawn_referral_usdt || 0))
              return (
                <div className="border border-orange-500/50 bg-orange-900/30 rounded-lg p-3 mb-3">
                  <div className="text-sm font-medium text-orange-400 mb-2">🔒 HOLDフェーズ</div>
                  <div className="text-xs text-gray-300 space-y-1">
                    <div className="flex justify-between">
                      <span>ロック中:</span>
                      <span className="text-orange-400">${(cd.cum_usdt - 1100).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>既払い出し:</span>
                      <span className="text-gray-400">${(cd.withdrawn_referral_usdt || 0).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between border-t border-gray-700 pt-1 mt-1">
                      <span className="font-medium">払い出し可能:</span>
                      <span className="text-green-400 font-bold">${withdrawableReferral.toFixed(2)}</span>
                    </div>
                  </div>
                  <p className="text-xs text-gray-500 mt-2">※次のNFT購入のため一部がロックされています</p>
                </div>
              )
            })()}

            {/* 保留中の出金 */}
            {withdrawalData.pending_withdrawals.map((withdrawal) => (
              <div key={withdrawal.id} className="border border-orange-500/30 bg-orange-900/20 rounded-lg p-3">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <DollarSign className="h-4 w-4 text-orange-400" />
                    <span className="text-lg font-bold text-orange-400">
                      ${Number(withdrawal.total_amount).toFixed(2)}
                    </span>
                  </div>
                  {getStatusBadge(withdrawal.status, withdrawal.task_completed)}
                </div>
                <div className="text-xs text-gray-400 space-y-1">
                  <div>{formatMonth(withdrawal.withdrawal_month)}分</div>
                  <div className="flex justify-between">
                    <span>個人利益:</span>
                    <span className="text-green-400">${Number(withdrawal.personal_amount || 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>紹介報酬:</span>
                    <span className="text-blue-400">${Number(withdrawal.referral_amount || 0).toFixed(2)}</span>
                  </div>
                  {withdrawal.status === 'on_hold' && !withdrawal.task_completed && isRecentMonth(withdrawal.withdrawal_month) && (
                    <Button
                      onClick={() => setShowTaskPopup(true)}
                      size="sm"
                      className="mt-2 text-xs bg-yellow-600 hover:bg-yellow-700 px-2 py-1 h-auto"
                    >
                      タスクを開始
                    </Button>
                  )}
                  {withdrawal.status === 'on_hold' && !withdrawal.task_completed && !isRecentMonth(withdrawal.withdrawal_month) && (
                    <div className="mt-2 text-xs text-gray-500">
                      ※ 古い月のタスクは自動完了処理待ちです
                    </div>
                  )}
                </div>
              </div>
            ))}

            {/* 完了済みの出金 */}
            {withdrawalData.completed_withdrawals.length > 0 && (
              <>
                <div className="border-t border-gray-700 pt-3">
                  <p className="text-xs text-gray-400 mb-2">完了済み</p>
                </div>
                {withdrawalData.completed_withdrawals.map((withdrawal) => (
                  <div key={withdrawal.id} className="border border-green-500/30 bg-green-900/10 rounded-lg p-3">
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-2">
                        <CheckCircle className="h-4 w-4 text-green-400" />
                        <span className="text-base font-bold text-green-400">
                          ${Number(withdrawal.total_amount).toFixed(2)}
                        </span>
                      </div>
                      {getStatusBadge(withdrawal.status, withdrawal.task_completed)}
                    </div>
                    <div className="text-xs text-gray-400 space-y-1">
                      <div>{formatMonth(withdrawal.withdrawal_month)}分</div>
                      <div className="flex justify-between">
                        <span>個人利益:</span>
                        <span className="text-green-400">${Number(withdrawal.personal_amount || 0).toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span>紹介報酬:</span>
                        <span className="text-blue-400">${Number(withdrawal.referral_amount || 0).toFixed(2)}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </>
            )}
          </div>
        )}
      </CardContent>
    </Card>
    </>
  )
}

