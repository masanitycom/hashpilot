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
  pending_count: number
  completed_count: number
  on_hold_count: number
}

export default function AdminWithdrawalsPage() {
  const [user, setUser] = useState<any>(null)
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([])
  const [stats, setStats] = useState<MonthlyStats | null>(null)
  const [selectedMonth, setSelectedMonth] = useState<string>(
    new Date().toISOString().slice(0, 7) // YYYY-MM format
  )
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [searchTerm, setSearchTerm] = useState("")
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

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
      
      // 月間出金記録を取得（usersテーブルからペガサス情報も取得）
      const { data: withdrawalData, error: withdrawalError } = await supabase
        .from("monthly_withdrawals")
        .select(`
          *,
          users!inner(
            is_pegasus_exchange,
            pegasus_exchange_date,
            pegasus_withdrawal_unlock_date
          )
        `)
        .eq("withdrawal_month", targetDate)
        .order("created_at", { ascending: false })

      if (withdrawalError) {
        throw withdrawalError
      }

      // データを整形（JOINで取得したusers情報を展開）
      const formattedData = (withdrawalData || []).map((item: any) => {
        const userData = item.users || {}
        return {
          ...item,
          is_pegasus_exchange: userData.is_pegasus_exchange || false,
          pegasus_exchange_date: userData.pegasus_exchange_date || null,
          pegasus_withdrawal_unlock_date: userData.pegasus_withdrawal_unlock_date || null,
        }
      })

      setWithdrawals(formattedData)

      // 統計情報を計算
      const stats: MonthlyStats = {
        total_amount: withdrawalData?.reduce((sum, w) => sum + Number(w.total_amount), 0) || 0,
        pending_count: withdrawalData?.filter(w => w.status === 'pending').length || 0,
        completed_count: withdrawalData?.filter(w => w.status === 'completed').length || 0,
        on_hold_count: withdrawalData?.filter(w => w.status === 'on_hold').length || 0,
      }
      setStats(stats)

    } catch (err: any) {
      console.error("Error fetching withdrawals:", err)
      setError("出金データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const processMonthlyWithdrawals = async () => {
    try {
      setProcessing(true)
      
      const targetDate = `${selectedMonth}-01`
      
      const { data, error } = await supabase.rpc("process_monthly_withdrawals", {
        p_target_month: targetDate
      })

      if (error) {
        throw error
      }

      alert(`月末出金処理が完了しました。処理件数: ${data[0].processed_count}件`)
      fetchWithdrawals()
    } catch (err: any) {
      console.error("Error processing monthly withdrawals:", err)
      alert("月末出金処理に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const markAsCompleted = async (ids: string[]) => {
    try {
      setProcessing(true)

      const { error } = await supabase
        .from("monthly_withdrawals")
        .update({ 
          status: 'completed',
          completed_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .in("id", ids)

      if (error) {
        throw error
      }

      alert(`${ids.length}件の出金を完了済みにしました`)
      setSelectedIds(new Set())
      fetchWithdrawals()
    } catch (err: any) {
      console.error("Error marking as completed:", err)
      alert("ステータス更新に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const exportCSV = () => {
    const headers = [
      "ユーザーID", "メールアドレス", "報酬額", "送金方法", "CoinW UID/送金先", 
      "ステータス", "タスク状況", "作成日", "完了日", "備考"
    ]
    
    const csvData = filteredWithdrawals.map(w => [
      w.user_id,
      w.email,
      w.total_amount,
      w.withdrawal_method === 'coinw' ? 'CoinW' : w.withdrawal_method === 'bep20' ? 'BEP20' : "未設定",
      w.withdrawal_address || "未設定",
      w.status,
      w.task_completed ? "完了" : "未完了",
      new Date(w.created_at).toLocaleDateString('ja-JP'),
      w.completed_at ? new Date(w.completed_at).toLocaleDateString('ja-JP') : "",
      w.notes || ""
    ])

    const csvContent = [headers, ...csvData]
      .map(row => row.map(field => `"${field}"`).join(","))
      .join("\\n")

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = `withdrawals_${selectedMonth}.csv`
    link.click()
  }

  const filteredWithdrawals = withdrawals.filter(w => 
    w.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    w.email.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge className="bg-yellow-600 text-white">送金待ち</Badge>
      case 'completed':
        return <Badge className="bg-green-600 text-white">送金完了</Badge>
      case 'on_hold':
        return <Badge className="bg-red-600 text-white">保留中</Badge>
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
                <h1 className="text-xl font-bold text-white">月末出金管理</h1>
                <p className="text-sm text-gray-400">月末自動出金の処理と管理</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* 統計セクション */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <Card className="bg-blue-900/20 border-blue-700/50">
              <CardContent className="p-6">
                <div className="flex items-center space-x-3">
                  <DollarSign className="h-8 w-8 text-blue-400" />
                  <div>
                    <p className="text-sm text-blue-300">総出金額</p>
                    <p className="text-2xl font-bold text-blue-400">
                      ${stats.total_amount.toFixed(2)}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-yellow-900/20 border-yellow-700/50">
              <CardContent className="p-6">
                <div className="flex items-center space-x-3">
                  <Clock className="h-8 w-8 text-yellow-400" />
                  <div>
                    <p className="text-sm text-yellow-300">送金待ち</p>
                    <p className="text-2xl font-bold text-yellow-400">{stats.pending_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-green-900/20 border-green-700/50">
              <CardContent className="p-6">
                <div className="flex items-center space-x-3">
                  <CheckCircle className="h-8 w-8 text-green-400" />
                  <div>
                    <p className="text-sm text-green-300">送金完了</p>
                    <p className="text-2xl font-bold text-green-400">{stats.completed_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-red-900/20 border-red-700/50">
              <CardContent className="p-6">
                <div className="flex items-center space-x-3">
                  <AlertCircle className="h-8 w-8 text-red-400" />
                  <div>
                    <p className="text-sm text-red-300">保留中</p>
                    <p className="text-2xl font-bold text-red-400">{stats.on_hold_count}</p>
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
                onClick={processMonthlyWithdrawals}
                disabled={processing}
                className="bg-blue-600 hover:bg-blue-700"
              >
                {processing ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
                月末出金処理実行
              </Button>

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
                className="border-gray-600 text-gray-300"
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
                      />
                    </th>
                    <th className="text-left py-3 px-2 text-gray-300">ユーザー</th>
                    <th className="text-left py-3 px-2 text-gray-300">報酬額</th>
                    <th className="text-left py-3 px-2 text-gray-300">CoinW UID/送金先</th>
                    <th className="text-left py-3 px-2 text-gray-300">ステータス</th>
                    <th className="text-left py-3 px-2 text-gray-300">タスク状況</th>
                    <th className="text-left py-3 px-2 text-gray-300">作成日</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredWithdrawals.map((withdrawal) => (
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
                      <td className="py-3 px-2">
                        <span className="font-bold text-green-400">
                          ${withdrawal.total_amount.toFixed(2)}
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
                            <span className="text-red-400">未設定</span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-2">
                        {getStatusBadge(withdrawal.status)}
                      </td>
                      <td className="py-3 px-2">
                        {withdrawal.task_completed ? (
                          <Badge className="bg-green-600 text-white">完了済み</Badge>
                        ) : (
                          <Badge className="bg-yellow-600 text-white">未完了</Badge>
                        )}
                        {withdrawal.task_completed_at && (
                          <div className="text-xs text-gray-400 mt-1">
                            {new Date(withdrawal.task_completed_at).toLocaleDateString('ja-JP')}
                          </div>
                        )}
                      </td>
                      <td className="py-3 px-2 text-gray-300">
                        {new Date(withdrawal.created_at).toLocaleDateString('ja-JP')}
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