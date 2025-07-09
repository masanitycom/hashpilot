"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { Switch } from "@/components/ui/switch"
import {
  CalendarIcon,
  TrendingUpIcon,
  UsersIcon,
  DollarSignIcon,
  AlertCircle,
  CheckCircle,
  InfoIcon,
  TestTube,
  Trash2,
  Shield,
  ArrowLeft,
  RefreshCw,
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface YieldHistory {
  id: string
  date: string
  yield_rate: number
  margin_rate: number
  user_rate: number
  total_users: number
  created_at: string
}

interface YieldStats {
  total_users: number
  total_investment: number
  avg_yield_rate: number
  total_distributed: number
}

export default function AdminYieldPage() {
  const [date, setDate] = useState(new Date().toISOString().split("T")[0])
  const [yieldRate, setYieldRate] = useState("")
  const [marginRate, setMarginRate] = useState("30")
  const [isMonthEnd, setIsMonthEnd] = useState(false)
  const [isTestMode, setIsTestMode] = useState(true)
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error" | "warning"; text: string } | null>(null)
  const [history, setHistory] = useState<YieldHistory[]>([])
  const [stats, setStats] = useState<YieldStats | null>(null)
  const [userRate, setUserRate] = useState(0)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

  // ユーザー受取率を計算
  useEffect(() => {
    const yield_rate = Number.parseFloat(yieldRate) || 0
    const margin_rate = Number.parseFloat(marginRate) || 0
    const calculated_user_rate = yield_rate * (1 - margin_rate / 100)
    setUserRate(calculated_user_rate)
  }, [yieldRate, marginRate])

  useEffect(() => {
    checkAdminAccess()
  }, [])

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

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError) {
        console.error("Admin check error:", adminError)
        setError("管理者権限の確認でエラーが発生しました")
        return
      }

      if (!adminCheck) {
        alert("管理者権限がありません")
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      fetchHistory()
      fetchStats()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchHistory = async () => {
    try {
      const { data, error } = await supabase
        .from("daily_yield_log")
        .select("*")
        .order("date", { ascending: false })
        .limit(10)

      if (error) throw error
      setHistory(data || [])
    } catch (error) {
      console.error("履歴取得エラー:", error)
    }
  }

  const fetchStats = async () => {
    try {
      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select("id")
        .eq("is_active", true)
        .eq("has_approved_nft", true)

      if (usersError) throw usersError

      const { data: purchasesData, error: purchasesError } = await supabase
        .from("purchases")
        .select("amount_usd")
        .eq("admin_approved", true)

      if (purchasesError) throw purchasesError

      const { data: avgYieldData, error: avgYieldError } = await supabase.from("daily_yield_log").select("yield_rate")

      if (avgYieldError) throw avgYieldError

      const { data: totalProfitData, error: totalProfitError } = await supabase
        .from("user_daily_profit")
        .select("daily_profit")

      if (totalProfitError) {
        console.warn("user_daily_profit取得エラー:", totalProfitError)
      }

      const totalInvestment = purchasesData?.reduce((sum, p) => sum + Number.parseFloat(p.amount_usd || "0"), 0) || 0
      const avgYieldRate =
        avgYieldData?.reduce((sum, y) => sum + Number.parseFloat(y.yield_rate || "0"), 0) /
          (avgYieldData?.length || 1) || 0
      const totalDistributed =
        totalProfitData?.reduce((sum, p) => sum + Number.parseFloat(p.daily_profit || "0"), 0) || 0

      setStats({
        total_users: usersData?.length || 0,
        total_investment: totalInvestment,
        avg_yield_rate: avgYieldRate * 100,
        total_distributed: totalDistributed,
      })
    } catch (error) {
      console.error("統計取得エラー:", error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    setMessage(null)

    try {
      const functionName = isTestMode ? "admin_post_yield_test_mode" : "admin_post_yield"

      const { data, error } = await supabase.rpc(functionName, {
        p_date: date,
        p_yield_rate: Number.parseFloat(yieldRate) / 100,
        p_margin_rate: Number.parseFloat(marginRate) / 100,
        p_is_month_end: isMonthEnd,
      })

      if (error) throw error

      if (isTestMode) {
        setMessage({
          type: "warning",
          text: `テストモード: ${data.total_users}名のユーザーに総額$${Number.parseFloat(data.total_user_profit).toFixed(2)}の利益が配布される予定です。（実際には保存されていません）`,
        })
      } else {
        setMessage({
          type: "success",
          text: `日利投稿が完了しました。${data.total_users}名のユーザーに総額$${Number.parseFloat(data.total_user_profit).toFixed(2)}の利益を配布しました。`,
        })

        setYieldRate("")
        setDate(new Date().toISOString().split("T")[0])
        fetchHistory()
        fetchStats()
      }
    } catch (error: any) {
      setMessage({
        type: "error",
        text: error.message || "日利投稿に失敗しました",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const handleCancel = async (cancelDate: string) => {
    if (!confirm(`${cancelDate}の日利投稿をキャンセルしますか？この操作は取り消せません。`)) {
      return
    }

    try {
      const { data, error } = await supabase.rpc("cancel_yield_posting", {
        p_date: cancelDate,
      })

      if (error) throw error

      setMessage({
        type: "success",
        text: data.message,
      })

      fetchHistory()
      fetchStats()
    } catch (error: any) {
      setMessage({
        type: "error",
        text: error.message || "キャンセルに失敗しました",
      })
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400 flex items-center">
              <Shield className="w-5 h-5 mr-2" />
              アクセス拒否
            </CardTitle>
          </CardHeader>
          <CardContent className="text-white">
            <p>管理者権限が必要です。</p>
            <Button
              onClick={() => router.push("/dashboard")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <div className="max-w-7xl mx-auto p-4 space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              管理者ダッシュボード
            </Button>
            <h1 className="text-3xl font-bold text-white flex items-center">
              <Shield className="w-8 h-8 mr-3 text-blue-400" />
              日利管理
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Badge variant={isTestMode ? "secondary" : "destructive"} className="text-sm">
              {isTestMode ? "テストモード" : "本番モード"}
            </Badge>
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
          </div>
        </div>

        {/* テストモード切り替え */}
        <Card className={`border-2 bg-gray-800 ${isTestMode ? "border-blue-500" : "border-red-500"}`}>
          <CardHeader>
            <CardTitle className={`flex items-center gap-2 ${isTestMode ? "text-blue-400" : "text-red-400"}`}>
              {isTestMode ? <TestTube className="h-5 w-5" /> : <Shield className="h-5 w-5" />}
              {isTestMode ? "テストモード" : "本番モード"}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-between">
              <div className={`space-y-2 ${isTestMode ? "text-blue-300" : "text-red-300"}`}>
                <p className="font-medium">
                  {isTestMode
                    ? "安全なテストモード: データベースに保存されません"
                    : "⚠️ 本番モード: ユーザーの実際の残高に影響します"}
                </p>
                <p className="text-sm">
                  {isTestMode
                    ? "計算結果のみ表示され、実際のユーザー残高は変更されません"
                    : "投稿すると即座にユーザーの紹介報酬に反映されます"}
                </p>
              </div>
              <div className="flex items-center space-x-2">
                <Label htmlFor="test-mode" className="text-white">
                  テストモード
                </Label>
                <Switch id="test-mode" checked={isTestMode} onCheckedChange={setIsTestMode} />
              </div>
            </div>
          </CardContent>
        </Card>

        {/* 統計情報 */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card className="bg-gradient-to-br from-green-900 to-green-800 border-green-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-green-100">
                  <UsersIcon className="h-4 w-4" />
                  アクティブユーザー
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">{stats.total_users}</div>
                <p className="text-xs text-green-200">NFT承認済み</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-blue-900 to-blue-800 border-blue-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-blue-100">
                  <DollarSignIcon className="h-4 w-4" />
                  総投資額
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">${stats.total_investment.toLocaleString()}</div>
                <p className="text-xs text-blue-200">承認済み購入</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-purple-900 to-purple-800 border-purple-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-purple-100">
                  <TrendingUpIcon className="h-4 w-4" />
                  平均日利率
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">{stats.avg_yield_rate.toFixed(2)}%</div>
                <p className="text-xs text-purple-200">過去の平均</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-yellow-900 to-yellow-800 border-yellow-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-yellow-100">
                  <DollarSignIcon className="h-4 w-4" />
                  総配布利益
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">${stats.total_distributed.toLocaleString()}</div>
                <p className="text-xs text-yellow-200">累積配布額</p>
              </CardContent>
            </Card>
          </div>
        )}

        {/* 日利投稿フォーム */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-white">
              <CalendarIcon className="h-5 w-5" />
              日利投稿
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="date" className="text-white">
                    日付
                  </Label>
                  <Input
                    id="date"
                    type="date"
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    required
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="yieldRate" className="text-white">
                    日利率 (%)
                  </Label>
                  <Input
                    id="yieldRate"
                    type="number"
                    step="0.01"
                    min="-10"
                    max="100"
                    value={yieldRate}
                    onChange={(e) => setYieldRate(e.target.value)}
                    placeholder="例: 1.5 (マイナス可)"
                    required
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="marginRate" className="text-white">
                    マージン率 (%)
                  </Label>
                  <Input
                    id="marginRate"
                    type="number"
                    step="1"
                    min="0"
                    max="100"
                    value={marginRate}
                    onChange={(e) => setMarginRate(e.target.value)}
                    placeholder="例: 30"
                    required
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-white">ユーザー受取率</Label>
                <div className={`text-2xl font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                  {userRate.toFixed(2)}%
                </div>
                <p className="text-sm text-gray-400">
                  日利率 {yieldRate}% - マージン {marginRate}% = ユーザー受取 {userRate.toFixed(2)}%
                </p>
                {stats && yieldRate && (
                  <div className="mt-2 p-3 bg-gray-700 rounded-lg">
                    <p className="text-sm font-medium text-white">予想配布額:</p>
                    <p className={`text-lg font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                      ${((stats.total_investment * userRate) / 100).toLocaleString()}
                    </p>
                    <p className="text-xs text-gray-400">{stats.total_users}名のユーザーに配布予定</p>
                  </div>
                )}
              </div>

              <div className="flex items-center space-x-2">
                <Checkbox
                  id="monthEnd"
                  checked={isMonthEnd}
                  onCheckedChange={(checked) => setIsMonthEnd(checked as boolean)}
                />
                <Label htmlFor="monthEnd" className="text-white">
                  月末処理
                </Label>
              </div>

              <Button
                type="submit"
                disabled={isLoading}
                className={`w-full md:w-auto ${isTestMode ? "bg-blue-600 hover:bg-blue-700" : "bg-red-600 hover:bg-red-700"}`}
              >
                {isLoading ? "処理中..." : isTestMode ? "テスト実行" : "日利を投稿"}
              </Button>
            </form>

            {message && (
              <Alert
                className={`mt-4 ${
                  message.type === "error"
                    ? "border-red-500 bg-red-900/20"
                    : message.type === "warning"
                      ? "border-yellow-500 bg-yellow-900/20"
                      : "border-green-500 bg-green-900/20"
                }`}
              >
                {message.type === "error" ? (
                  <AlertCircle className="h-4 w-4" />
                ) : message.type === "warning" ? (
                  <InfoIcon className="h-4 w-4" />
                ) : (
                  <CheckCircle className="h-4 w-4" />
                )}
                <AlertDescription
                  className={
                    message.type === "error"
                      ? "text-red-300"
                      : message.type === "warning"
                        ? "text-yellow-300"
                        : "text-green-300"
                  }
                >
                  {message.text}
                </AlertDescription>
              </Alert>
            )}
          </CardContent>
        </Card>

        {/* 履歴 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white">投稿履歴</CardTitle>
              <Button onClick={fetchHistory} size="sm" className="bg-blue-600 hover:bg-blue-700">
                <RefreshCw className="w-4 h-4 mr-2" />
                更新
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            {history.length === 0 ? (
              <p className="text-gray-400">履歴がありません</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm text-white">
                  <thead>
                    <tr className="border-b border-gray-600">
                      <th className="text-left p-2">日付</th>
                      <th className="text-left p-2">日利率</th>
                      <th className="text-left p-2">マージン率</th>
                      <th className="text-left p-2">ユーザー利率</th>
                      <th className="text-left p-2">投稿日時</th>
                      <th className="text-left p-2">操作</th>
                    </tr>
                  </thead>
                  <tbody>
                    {history.map((item) => (
                      <tr key={item.id} className="border-b border-gray-700">
                        <td className="p-2">{new Date(item.date).toLocaleDateString("ja-JP")}</td>
                        <td
                          className={`p-2 font-medium ${Number.parseFloat(item.yield_rate) >= 0 ? "text-green-400" : "text-red-400"}`}
                        >
                          {(Number.parseFloat(item.yield_rate) * 100).toFixed(2)}%
                        </td>
                        <td className="p-2">{(Number.parseFloat(item.margin_rate) * 100).toFixed(0)}%</td>
                        <td
                          className={`p-2 font-medium ${Number.parseFloat(item.user_rate) >= 0 ? "text-green-400" : "text-red-400"}`}
                        >
                          {(Number.parseFloat(item.user_rate) * 100).toFixed(2)}%
                        </td>
                        <td className="p-2">{new Date(item.created_at).toLocaleString("ja-JP")}</td>
                        <td className="p-2">
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() => handleCancel(item.date)}
                            className="h-8 px-2 bg-red-600 hover:bg-red-700"
                          >
                            <Trash2 className="h-3 w-3 mr-1" />
                            キャンセル
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
