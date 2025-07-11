"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { RefreshCw, DollarSign, Users, CheckCircle, Clock, Calculator, Send, ArrowLeft } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface MonthlyReward {
  user_id: string
  email: string
  full_name: string | null
  year: number
  month: number
  total_daily_profit: number
  total_referral_rewards: number
  total_rewards: number
  is_paid: boolean
  paid_at: string | null
  paid_by: string | null
  payment_transaction_id: string | null
  days_count: number
  avg_yield_rate: number
  min_daily_profit: number
  max_daily_profit: number
}

export default function AdminRewardsPage() {
  const [rewards, setRewards] = useState<MonthlyReward[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear())
  const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth() + 1)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [error, setError] = useState("")
  const [actionLoading, setActionLoading] = useState(false)
  const [selectedReward, setSelectedReward] = useState<MonthlyReward | null>(null)
  const [transactionId, setTransactionId] = useState("")
  const [paymentDialogOpen, setPaymentDialogOpen] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  useEffect(() => {
    if (isAdmin) {
      fetchRewards()
    }
  }, [selectedYear, selectedMonth, isAdmin])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      setCurrentUser(user)

      const { data: userData, error } = await supabase
        .from("users")
        .select("is_admin")
        .eq("id", user.id)
        .single()

      if (error || !userData?.is_admin) {
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchRewards = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error } = await supabase
        .from("admin_monthly_rewards_view")
        .select("*")
        .eq("year", selectedYear)
        .eq("month", selectedMonth)
        .order("total_rewards", { ascending: false })

      if (error) throw error

      setRewards(data || [])
    } catch (error: any) {
      console.error("Error fetching rewards:", error)
      setError(`報酬データの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const calculateMonthlyRewards = async () => {
    if (!confirm(`${selectedYear}年${selectedMonth}月の報酬を集計しますか？`)) {
      return
    }

    setActionLoading(true)
    try {
      const { data, error } = await supabase.rpc("calculate_monthly_rewards", {
        p_year: selectedYear,
        p_month: selectedMonth,
      })

      if (error) throw error

      alert(
        `報酬集計が完了しました。${data.total_users}名のユーザーに総額$${data.total_rewards.toFixed(2)}の報酬を計算しました`,
      )

      await fetchRewards()
    } catch (error: any) {
      console.error("Error calculating rewards:", error)
      setError(`報酬集計に失敗しました: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const markAsPaid = async () => {
    if (!selectedReward || !transactionId.trim()) {
      alert("取引IDを入力してください")
      return
    }

    setActionLoading(true)
    try {
      const { data, error } = await supabase.rpc("mark_reward_as_paid", {
        p_user_id: selectedReward.user_id,
        p_year: selectedReward.year,
        p_month: selectedReward.month,
        p_transaction_id: transactionId.trim(),
      })

      if (error) throw error

      alert("支払い完了として記録しました")
      setPaymentDialogOpen(false)
      setSelectedReward(null)
      setTransactionId("")
      await fetchRewards()
    } catch (error: any) {
      console.error("Error marking as paid:", error)
      alert(`支払い記録に失敗しました: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const formatCurrency = (value: number) => {
    return `$${value.toFixed(2)}`
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString("ja-JP")
  }

  const totalRewards = rewards.reduce((sum, reward) => sum + reward.total_rewards, 0)
  const paidRewards = rewards.filter((r) => r.is_paid).reduce((sum, reward) => sum + reward.total_rewards, 0)
  const unpaidRewards = totalRewards - paidRewards

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-4 text-blue-500" />
          <p className="text-white">管理者権限を確認中...</p>
        </div>
      </div>
    )
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardContent className="text-center p-6">
            <p className="text-red-400 mb-4">管理者権限が必要です</p>
            <Link href="/dashboard">
              <Button className="bg-blue-600 hover:bg-blue-700">ダッシュボードに戻る</Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <header className="bg-gray-800 shadow-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/admin">
                <Button variant="ghost" size="sm" className="text-white hover:bg-gray-700">
                  <ArrowLeft className="w-4 h-4 mr-2" />
                  管理画面に戻る
                </Button>
              </Link>
              <h1 className="text-2xl font-bold text-white">報酬管理</h1>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        {error && (
          <Card className="mb-6 bg-red-900 border-red-700">
            <CardContent className="p-4">
              <p className="text-red-200">{error}</p>
            </CardContent>
          </Card>
        )}

        {/* 期間選択 */}
        <Card className="mb-6 bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">報酬期間選択</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col sm:flex-row space-y-4 sm:space-y-0 sm:space-x-4 items-end">
              <div className="flex-1">
                <Label htmlFor="year" className="text-white">
                  年
                </Label>
                <Select
                  value={selectedYear.toString()}
                  onValueChange={(value) => setSelectedYear(Number.parseInt(value))}
                >
                  <SelectTrigger className="bg-gray-700 border-gray-600 text-white">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {[2024, 2025, 2026].map((year) => (
                      <SelectItem key={year} value={year.toString()}>
                        {year}年
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="flex-1">
                <Label htmlFor="month" className="text-white">
                  月
                </Label>
                <Select
                  value={selectedMonth.toString()}
                  onValueChange={(value) => setSelectedMonth(Number.parseInt(value))}
                >
                  <SelectTrigger className="bg-gray-700 border-gray-600 text-white">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => (
                      <SelectItem key={month} value={month.toString()}>
                        {month}月
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <Button
                onClick={calculateMonthlyRewards}
                disabled={actionLoading}
                className="bg-green-600 hover:bg-green-700 text-white"
              >
                <Calculator className="w-4 h-4 mr-2" />
                {actionLoading ? "集計中..." : "報酬集計"}
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* 統計サマリー */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <Users className="w-5 h-5 text-blue-400" />
                <div>
                  <p className="text-sm text-gray-400">対象ユーザー</p>
                  <p className="text-xl font-bold text-white">{rewards.length}名</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <DollarSign className="w-5 h-5 text-green-400" />
                <div>
                  <p className="text-sm text-gray-400">総報酬額</p>
                  <p className="text-xl font-bold text-white">{formatCurrency(totalRewards)}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <CheckCircle className="w-5 h-5 text-green-400" />
                <div>
                  <p className="text-sm text-gray-400">支払い済み</p>
                  <p className="text-xl font-bold text-white">{formatCurrency(paidRewards)}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <Clock className="w-5 h-5 text-yellow-400" />
                <div>
                  <p className="text-sm text-gray-400">未払い</p>
                  <p className="text-xl font-bold text-white">{formatCurrency(unpaidRewards)}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 報酬一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">
              {selectedYear}年{selectedMonth}月の報酬一覧
            </CardTitle>
            <CardDescription className="text-gray-400">ユーザー別の報酬詳細と支払い状況</CardDescription>
          </CardHeader>
          <CardContent>
            {rewards.length === 0 ? (
              <div className="text-center py-12 text-gray-400">
                <DollarSign className="w-16 h-16 mx-auto mb-4 opacity-50" />
                <p className="text-xl mb-2">報酬データがありません</p>
                <p>まず報酬集計を実行してください</p>
              </div>
            ) : (
              <div className="space-y-4">
                {rewards.map((reward) => (
                  <div key={reward.user_id} className="bg-gray-700 rounded-lg p-6 border border-gray-600">
                    <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between mb-4">
                      <div className="flex items-center space-x-3 mb-4 lg:mb-0">
                        <div className="bg-gradient-to-r from-blue-500 to-purple-600 text-white px-3 py-2 rounded-full font-bold">
                          {reward.user_id}
                        </div>
                        <div>
                          <p className="text-white font-semibold">{reward.email}</p>
                          {reward.full_name && <p className="text-gray-400 text-sm">{reward.full_name}</p>}
                        </div>
                      </div>
                      <div className="flex items-center space-x-2">
                        {reward.is_paid ? (
                          <Badge className="bg-green-600 text-white">
                            <CheckCircle className="w-3 h-3 mr-1" />
                            支払い済み
                          </Badge>
                        ) : (
                          <>
                            <Badge variant="secondary" className="bg-yellow-600 text-white">
                              <Clock className="w-3 h-3 mr-1" />
                              支払い待ち
                            </Badge>
                            <Button
                              size="sm"
                              onClick={() => {
                                setSelectedReward(reward)
                                setPaymentDialogOpen(true)
                              }}
                              className="bg-blue-600 hover:bg-blue-700 text-white"
                            >
                              <Send className="w-3 h-3 mr-1" />
                              支払い完了
                            </Button>
                          </>
                        )}
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
                      <div className="bg-green-900/30 rounded-lg p-3 border border-green-700">
                        <div className="text-xs text-green-300 font-semibold mb-1">日利合計</div>
                        <div className="text-lg font-bold text-green-400">
                          {formatCurrency(reward.total_daily_profit)}
                        </div>
                      </div>
                      <div className="bg-blue-900/30 rounded-lg p-3 border border-blue-700">
                        <div className="text-xs text-blue-300 font-semibold mb-1">紹介報酬</div>
                        <div className="text-lg font-bold text-blue-400">
                          {formatCurrency(reward.total_referral_rewards)}
                        </div>
                      </div>
                      <div className="bg-yellow-900/30 rounded-lg p-3 border border-yellow-700">
                        <div className="text-xs text-yellow-300 font-semibold mb-1">総報酬</div>
                        <div className="text-lg font-bold text-yellow-400">{formatCurrency(reward.total_rewards)}</div>
                      </div>
                      <div className="bg-purple-900/30 rounded-lg p-3 border border-purple-700">
                        <div className="text-xs text-purple-300 font-semibold mb-1">平均日利率</div>
                        <div className="text-lg font-bold text-purple-400">{reward.avg_yield_rate.toFixed(2)}%</div>
                      </div>
                    </div>

                    {reward.is_paid && reward.paid_at && (
                      <div className="bg-gray-600 rounded-lg p-3 text-sm">
                        <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center space-y-2 sm:space-y-0">
                          <span className="text-gray-300">支払い日: {formatDate(reward.paid_at)}</span>
                          {reward.payment_transaction_id && (
                            <span className="text-gray-300 font-mono text-xs">
                              取引ID: {reward.payment_transaction_id}
                            </span>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* 支払い完了ダイアログ */}
        <Dialog open={paymentDialogOpen} onOpenChange={setPaymentDialogOpen}>
          <DialogContent className="bg-gray-800 border-gray-700 text-white">
            <DialogHeader>
              <DialogTitle>支払い完了の記録</DialogTitle>
              <DialogDescription className="text-gray-400">
                {selectedReward && (
                  <>
                    {selectedReward.user_id} ({selectedReward.email}) への
                    {formatCurrency(selectedReward.total_rewards)}の支払いを完了として記録します。
                  </>
                )}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <Label htmlFor="transaction-id" className="text-white">
                  取引ID / 送金記録
                </Label>
                <Input
                  id="transaction-id"
                  value={transactionId}
                  onChange={(e) => setTransactionId(e.target.value)}
                  placeholder="取引ID、送金記録、メモなど"
                  className="bg-gray-700 border-gray-600 text-white"
                />
              </div>
            </div>
            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => setPaymentDialogOpen(false)}
                className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
              >
                キャンセル
              </Button>
              <Button
                onClick={markAsPaid}
                disabled={actionLoading || !transactionId.trim()}
                className="bg-green-600 hover:bg-green-700 text-white"
              >
                {actionLoading ? "記録中..." : "支払い完了として記録"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </main>
    </div>
  )
}
