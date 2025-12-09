"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Checkbox } from "@/components/ui/checkbox"
import { 
  Loader2, 
  ArrowLeft, 
  DollarSign, 
  Clock, 
  CheckCircle,
  AlertCircle,
  Search,
  Download
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface WithdrawalRecord {
  id: string
  user_id: string
  email: string
  withdrawal_month: string
  total_amount: number
  withdrawal_address: string | null
  withdrawal_method: string | null
  status: string
  created_at: string
  completed_at: string | null
  notes: string | null
  task_completed: boolean
  task_completed_at: string | null
  is_pegasus_exchange?: boolean
  pegasus_exchange_date?: string | null
  pegasus_withdrawal_unlock_date?: string | null
}

interface MonthlyStats {
  total_amount: number
  personal_profit_total: number
  referral_profit_total: number
  pending_count: number
  completed_count: number
  on_hold_count: number
}

// デフォルトで前月を表示（月末出金は前月分のため）
const getDefaultMonth = () => {
  // 日本時間で現在の日付を取得
  const now = new Date()
  const jstDate = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Tokyo' }))

  // 前月を計算
  const year = jstDate.getFullYear()
  const month = jstDate.getMonth() // 0-indexed (0=1月, 11=12月)

  // 前月の年と月を計算
  let lastYear = year
  let lastMonth = month - 1
  if (lastMonth < 0) {
    lastMonth = 11
    lastYear = year - 1
  }

  // YYYY-MM形式で返す
  const monthStr = String(lastMonth + 1).padStart(2, '0')
  return `${lastYear}-${monthStr}`
}

export default function AdminWithdrawalsPage() {
  const [user, setUser] = useState<any>(null)
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([])
  const [stats, setStats] = useState<MonthlyStats | null>(null)
  const [selectedMonth, setSelectedMonth] = useState<string>("")
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [searchTerm, setSearchTerm] = useState("")
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

  // 強制的に前月を設定
  useEffect(() => {
    const defaultMonth = getDefaultMonth()
    console.log('Force setting month to:', defaultMonth)
    setSelectedMonth(defaultMonth)
  }, [])

  useEffect(() => {
    checkAuth()
  }, [])

  useEffect(() => {
    if (user) {
      fetchWithdrawals()
    }
  }, [user, selectedMonth])

  const checkAuth = async () => {
    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession()
      
      if (sessionError || !session?.user) {
        router.push("/login")
        return
      }

      setUser(session.user)
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/login")
    }
  }

  const fetchWithdrawals = async () => {
    try {
      setLoading(true)
      setError("")

      const targetDate = `${selectedMonth}-01`

      console.log('=== Fetching withdrawals for:', targetDate)

      // STEP 1: 月間出金記録を取得（この月のレコードのみ）
      const { data: withdrawalData, error: withdrawalError } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("withdrawal_month", targetDate)
        .order("total_amount", { ascending: false })

      if (withdrawalError) throw withdrawalError

      if (!withdrawalData || withdrawalData.length === 0) {
        console.log('=== No withdrawal records for this month')
        setWithdrawals([])
        setStats({
          total_amount: 0,
          personal_profit_total: 0,
          referral_profit_total: 0,
          pending_count: 0,
          completed_count: 0,
          on_hold_count: 0
        })
        setLoading(false)
        return
      }

      // STEP 2: ユーザー情報を取得
      const userIds = withdrawalData.map(w => w.user_id)
      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select("user_id, email, coinw_uid, nft_receive_address, is_pegasus_exchange, pegasus_withdrawal_unlock_date")
        .in("user_id", userIds)

      if (usersError) throw usersError

      // STEP 3: 現在の残高を取得（参考情報）
      const { data: currentCycle, error: cycleError } = await supabase
        .from("affiliate_cycle")
        .select("user_id, available_usdt, cum_usdt, phase, total_nft_count")
        .in("user_id", userIds)

      if (cycleError) throw cycleError

      // STEP 4: データを結合
      const formattedData = withdrawalData.map((withdrawal: any) => {
        const user = usersData?.find(u => u.user_id === withdrawal.user_id)
        const cycle = currentCycle?.find(c => c.user_id === withdrawal.user_id)

        return {
          ...withdrawal,
          email: user?.email || '',
          withdrawal_address: withdrawal.withdrawal_address || user?.coinw_uid || user?.nft_receive_address || null,
          withdrawal_method: withdrawal.withdrawal_method || (user?.coinw_uid ? 'coinw' : user?.nft_receive_address ? 'bep20' : null),
          is_pegasus_exchange: user?.is_pegasus_exchange || false,
          pegasus_withdrawal_unlock_date: user?.pegasus_withdrawal_unlock_date || null,
          // 参考情報: 現在の残高
          current_available_usdt: cycle?.available_usdt || 0,
          cum_usdt: cycle?.cum_usdt || 0,
          phase: cycle?.phase || '',
          total_nft_count: cycle?.total_nft_count || 0,
        }
      })

      console.log('=== Formatted data count:', formattedData.length)
      setWithdrawals(formattedData)

      // 統計情報を計算
      const personalProfitTotal = formattedData.reduce((sum, w) => sum + Number(w.total_amount), 0)
      const referralProfitTotal = formattedData.reduce((sum, w) => sum + Number(w.cum_usdt || 0), 0)

      const stats: MonthlyStats = {
        total_amount: personalProfitTotal + referralProfitTotal,
        personal_profit_total: personalProfitTotal,
        referral_profit_total: referralProfitTotal,
        pending_count: formattedData.filter(w => w.status === 'pending').length,
        completed_count: formattedData.filter(w => w.status === 'completed').length,
        on_hold_count: formattedData.filter(w => w.status === 'on_hold').length,
      }
      setStats(stats)

    } catch (err: any) {
      console.error("Error fetching withdrawals:", err)
      setError("出金データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const markAsCompleted = async (ids: string[]) => {
    try {
      setProcessing(true)

      // 新しいRPC関数を使用して出金完了処理（available_usdtも減算）
      // p_withdrawal_idsはUUID[]型なので文字列配列をそのまま渡す
      const { data, error } = await supabase.rpc("complete_withdrawals_batch", {
        p_withdrawal_ids: ids
      })

      if (error) {
        throw error
      }

      // 結果を確認
      const results = data || []
      const successCount = results.filter((r: any) => r.success).length
      const failCount = results.filter((r: any) => !r.success).length

      if (failCount > 0) {
        const errors = results.filter((r: any) => !r.success).map((r: any) =>
          `ID ${r.withdrawal_id}: ${r.error_message}`
        ).join('\n')
        alert(`出金完了処理結果:\n成功: ${successCount}件\n失敗: ${failCount}件\n\nエラー詳細:\n${errors}`)
      } else {
        alert(`${successCount}件の出金を完了済みにしました（available_usdtから減算済み）`)
      }

      setSelectedIds(new Set())
      fetchWithdrawals()
    } catch (err: any) {
      console.error("Error marking as completed:", err)
      alert("ステータス更新に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const exportCSV = async () => {
    const headers = [
      "ユーザーID", "メールアドレス", "個人利益", "紹介報酬", "合計額", "送金方法", "CoinW UID/送金先",
      "ステータス", "タスク状況", "作成日", "完了日", "備考"
    ]

    // 月の範囲を計算
    const monthStart = `${selectedMonth}-01`
    const monthEnd = new Date(selectedMonth + '-01')
    monthEnd.setMonth(monthEnd.getMonth() + 1)
    const monthEndStr = monthEnd.toISOString().split('T')[0]

    const csvData = await Promise.all(
      filteredWithdrawals.map(async (w) => {
        // 個人利益を取得
        const { data: dailyProfitData } = await supabase
          .from('user_daily_profit')
          .select('daily_profit')
          .eq('user_id', w.user_id)
          .gte('date', monthStart)
          .lt('date', monthEndStr)

        const personalProfit = dailyProfitData
          ? dailyProfitData.reduce((sum, r) => sum + r.daily_profit, 0)
          : 0

        // 紹介報酬を取得
        const { data: referralData } = await supabase
          .from('monthly_referral_profit')
          .select('profit_amount')
          .eq('user_id', w.user_id)
          .eq('year_month', selectedMonth)

        const referralProfit = referralData
          ? referralData.reduce((sum, r) => sum + parseFloat(r.profit_amount), 0)
          : 0

        return [
          w.user_id,
          w.email,
          personalProfit.toFixed(3),
          referralProfit.toFixed(3),
          w.total_amount,
          w.withdrawal_method === 'coinw' ? 'CoinW' : w.withdrawal_method === 'bep20' ? 'BEP20' : "未設定",
          w.withdrawal_address || "未設定",
          w.status,
          w.task_completed ? "完了" : "未完了",
          new Date(w.created_at).toLocaleDateString('ja-JP'),
          w.completed_at ? new Date(w.completed_at).toLocaleDateString('ja-JP') : "",
          w.notes || ""
        ]
      })
    )

    const csvContent = [headers, ...csvData]
      .map(row => row.map(field => `"${field}"`).join(","))
      .join("\n")

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = `withdrawals_${selectedMonth}.csv`
    link.click()
  }

  const filteredWithdrawals = withdrawals
    .filter(w =>
      w.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      w.email.toLowerCase().includes(searchTerm.toLowerCase())
    )
    .sort((a, b) => Number(b.total_amount) - Number(a.total_amount))

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge className="bg-yellow-600 text-white">送金待ち</Badge>
      case 'completed':
        return <Badge className="bg-green-600 text-white">送金完了</Badge>
      case 'on_hold':
        return <Badge className="bg-red-600 text-white">保留中</Badge>
      case 'not_created':
        return <Badge className="bg-gray-600 text-white">未作成</Badge>
      default:
        return <Badge className="bg-gray-600 text-white">{status}</Badge>
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/admin">
                <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  管理画面
                </Button>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-white">
                  月末出金管理
                  {selectedMonth && (
                    <span className="text-blue-400 ml-2">
                      ({new Date(selectedMonth + '-01').toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })})
                    </span>
                  )}
                </h1>
                <p className="text-sm text-gray-400">月末自動出金の処理と管理</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* 統計セクション */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-6 gap-4 mb-8">
            {/* 個人利益合計 */}
            <Card className="bg-green-900/20 border-green-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-6 w-6 text-green-400" />
                  <div>
                    <p className="text-xs text-green-300">個人利益合計</p>
                    <p className="text-xl font-bold text-green-400">
                      ${stats.personal_profit_total.toFixed(2)}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 紹介報酬合計 */}
            <Card className="bg-orange-900/20 border-orange-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-6 w-6 text-orange-400" />
                  <div>
                    <p className="text-xs text-orange-300">紹介報酬合計</p>
                    <p className="text-xl font-bold text-orange-400">
                      ${stats.referral_profit_total.toFixed(2)}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 総出金額 */}
            <Card className="bg-blue-900/20 border-blue-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-6 w-6 text-blue-400" />
                  <div>
                    <p className="text-xs text-blue-300">総出金額（$10以上）</p>
                    <p className="text-xl font-bold text-blue-400">
                      ${stats.total_amount.toFixed(2)}
                    </p>
                    <p className="text-xs text-blue-300 mt-1">
                      {withdrawals.length}人
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 送金待ち */}
            <Card className="bg-yellow-900/20 border-yellow-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <Clock className="h-6 w-6 text-yellow-400" />
                  <div>
                    <p className="text-xs text-yellow-300">送金待ち</p>
                    <p className="text-xl font-bold text-yellow-400">{stats.pending_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 送金完了 */}
            <Card className="bg-emerald-900/20 border-emerald-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <CheckCircle className="h-6 w-6 text-emerald-400" />
                  <div>
                    <p className="text-xs text-emerald-300">送金完了</p>
                    <p className="text-xl font-bold text-emerald-400">{stats.completed_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 保留中 */}
            <Card className="bg-red-900/20 border-red-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <AlertCircle className="h-6 w-6 text-red-400" />
                  <div>
                    <p className="text-xs text-red-300">保留中</p>
                    <p className="text-xl font-bold text-red-400">{stats.on_hold_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* 操作パネル */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardHeader>
            <CardTitle className="text-white">操作パネル</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex items-center space-x-2">
                <label className="text-sm text-gray-300">対象月:</label>
                <Input
                  type="month"
                  value={selectedMonth}
                  onChange={(e) => setSelectedMonth(e.target.value)}
                  className="bg-gray-700 border-gray-600 text-white"
                />
              </div>

              <Button
                onClick={() => markAsCompleted(Array.from(selectedIds))}
                disabled={selectedIds.size === 0 || processing}
                className="bg-green-600 hover:bg-green-700"
              >
                選択した項目を完了済みに
              </Button>

              <Button
                onClick={exportCSV}
                variant="outline"
                className="border-gray-600 text-black bg-white hover:bg-gray-100"
              >
                <Download className="h-4 w-4 mr-2" />
                CSV出力
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* 検索・フィルター */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardContent className="p-4">
            <div className="flex items-center space-x-4">
              <div className="flex-1">
                <div className="relative">
                  <Search className="h-4 w-4 absolute left-3 top-3 text-gray-400" />
                  <Input
                    placeholder="ユーザーID・メールアドレスで検索..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 bg-gray-700 border-gray-600 text-white"
                  />
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* 出金一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">出金一覧 ({filteredWithdrawals.length}件)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left py-3 px-2">
                      <Checkbox
                        checked={selectedIds.size === filteredWithdrawals.length && filteredWithdrawals.length > 0}
                        onCheckedChange={(checked) => {
                          if (checked) {
                            setSelectedIds(new Set(filteredWithdrawals.map(w => w.id)))
                          } else {
                            setSelectedIds(new Set())
                          }
                        }}
                        className="border-2 border-white/70 data-[state=checked]:bg-blue-500 data-[state=checked]:border-blue-500 h-5 w-5"
                      />
                    </th>
                    <th className="text-left py-3 px-2 text-gray-300">ユーザー</th>
                    <th className="text-right py-3 px-2 text-gray-300">出金可能額</th>
                    <th className="text-right py-3 px-2 text-gray-300">紹介報酬累積</th>
                    <th className="text-center py-3 px-2 text-gray-300">NFT数</th>
                    <th className="text-left py-3 px-2 text-gray-300">CoinW UID/送金先</th>
                    <th className="text-left py-3 px-2 text-gray-300">ステータス</th>
                    <th className="text-left py-3 px-2 text-gray-300">タスク状況</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredWithdrawals.map((withdrawal: any) => (
                    <tr key={withdrawal.id} className="border-b border-gray-700/50 hover:bg-gray-700/20">
                      <td className="py-3 px-2">
                        <Checkbox
                          checked={selectedIds.has(withdrawal.id)}
                          onCheckedChange={(checked) => {
                            const newSet = new Set(selectedIds)
                            if (checked) {
                              newSet.add(withdrawal.id)
                            } else {
                              newSet.delete(withdrawal.id)
                            }
                            setSelectedIds(newSet)
                          }}
                          disabled={withdrawal.status === 'not_created'}
                          className="border-2 border-white/70 data-[state=checked]:bg-blue-500 data-[state=checked]:border-blue-500 h-5 w-5 disabled:border-gray-600"
                        />
                      </td>
                      <td className="py-3 px-2">
                        <div>
                          <div className="font-medium text-white">{withdrawal.user_id}</div>
                          <div className="text-xs text-gray-400">{withdrawal.email}</div>
                          {withdrawal.is_pegasus_exchange && (
                            <div className="mt-1">
                              <Badge className="bg-yellow-600 text-white text-xs">🐴 ペガサス交換</Badge>
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-2 text-right">
                        <span className={`font-bold ${
                          withdrawal.total_amount >= 10 ? 'text-green-400' : 'text-gray-400'
                        }`}>
                          ${withdrawal.total_amount.toFixed(2)}
                        </span>
                      </td>
                      <td className="py-3 px-2 text-right">
                        <span className="text-orange-400">
                          ${withdrawal.cum_usdt?.toFixed(2) || '0.00'}
                        </span>
                      </td>
                      <td className="py-3 px-2 text-center">
                        <span className="text-blue-400">
                          {withdrawal.total_nft_count || 0}
                        </span>
                      </td>
                      <td className="py-3 px-2">
                        <div className="text-white">
                          {withdrawal.withdrawal_method === 'coinw' ? (
                            <div>
                              <span className="text-xs text-blue-400">CoinW:</span>
                              <div>{withdrawal.withdrawal_address}</div>
                            </div>
                          ) : withdrawal.withdrawal_method === 'bep20' ? (
                            <div>
                              <span className="text-xs text-green-400">BEP20:</span>
                              <div className="truncate max-w-32">{withdrawal.withdrawal_address}</div>
                            </div>
                          ) : (
                            <span className="text-red-400">❌ 未設定</span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-2">
                        {getStatusBadge(withdrawal.status)}
                        {withdrawal.status === 'not_created' && withdrawal.total_amount < 10 && (
                          <div className="text-xs text-gray-500 mt-1">$10未満のため未作成</div>
                        )}
                        {withdrawal.status === 'not_created' && withdrawal.total_amount >= 10 && !withdrawal.withdrawal_method && (
                          <div className="text-xs text-red-400 mt-1">送金先未設定</div>
                        )}
                      </td>
                      <td className="py-3 px-2">
                        {withdrawal.task_completed ? (
                          <Badge className="bg-green-600 text-white">完了済み</Badge>
                        ) : withdrawal.status === 'not_created' ? (
                          <Badge className="bg-gray-600 text-white">-</Badge>
                        ) : (
                          <Badge className="bg-yellow-600 text-white">未完了</Badge>
                        )}
                        {withdrawal.task_completed_at && (
                          <div className="text-xs text-gray-400 mt-1">
                            {new Date(withdrawal.task_completed_at).toLocaleDateString('ja-JP')}
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              
              {filteredWithdrawals.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  出金記録がありません
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {error && (
          <div className="mt-4 p-4 bg-red-900/20 border border-red-500/50 rounded-lg">
            <p className="text-red-200">{error}</p>
          </div>
        )}
      </div>
    </div>
  )
}