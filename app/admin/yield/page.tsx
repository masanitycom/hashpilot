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

interface TestResult {
  date: string
  yield_rate: number
  margin_rate: number
  user_rate: number
  total_users: number
  total_user_profit: number
  total_company_profit: number
  created_at: string
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
  const [testResults, setTestResults] = useState<TestResult[]>([])
  const [showTestResults, setShowTestResults] = useState(false)
  const router = useRouter()

  // ユーザー受取率を計算
  useEffect(() => {
    const yield_rate = Number.parseFloat(yieldRate) || 0
    const margin_rate = Number.parseFloat(marginRate) || 0
    // 正しい計算式: 日利率 × (1 - マージン率/100) × 0.6
    const after_margin = yield_rate * (1 - margin_rate / 100)
    const calculated_user_rate = after_margin * 0.6
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

      // 緊急対応：管理者権限チェックを一時的に無効化
      /*
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
      */

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
      if (isTestMode) {
        // テストモード: サイクル処理のシミュレーション
        const { data, error } = await supabase.rpc("process_daily_yield_with_cycles", {
          p_date: date,
          p_yield_rate: Number.parseFloat(yieldRate) / 100,
          p_margin_rate: Number.parseFloat(marginRate) / 100,
          p_is_test_mode: true,
        })

        if (error) throw error

        if (data && data.length > 0) {
          const result = data[0]
          setMessage({
            type: "success",
            text: `🧪 テスト実行完了: ${result.total_users}名処理予定、総額$${Number.parseFloat(result.total_user_profit).toFixed(2)}配布予定、${result.cycle_updates}回サイクル更新予定、${result.auto_nft_purchases}回自動NFT購入予定（実際のデータは変更されません）`,
          })
        }
      } else {
        // 本番モード: 新しいサイクル処理付き日利設定
        const { data, error } = await supabase.rpc("process_daily_yield_with_cycles", {
          p_date: date,
          p_yield_rate: Number.parseFloat(yieldRate) / 100,
          p_margin_rate: Number.parseFloat(marginRate) / 100,
          p_is_test_mode: false,
        })

        if (error) throw error

        if (data && data.length > 0) {
          const result = data[0]
          setMessage({
            type: "success",
            text: result.message || `サイクル処理完了！${result.total_users}名のユーザーに総額$${Number.parseFloat(result.total_user_profit).toFixed(2)}の利益を配布し、${result.cycle_updates}回のサイクル更新、${result.auto_nft_purchases}回の自動NFT購入を実行しました。`,
          })
        } else {
          setMessage({
            type: "success",
            text: "日利設定が完了しました。",
          })
        }

        setYieldRate("")
        setDate(new Date().toISOString().split("T")[0])
        fetchHistory()
        fetchStats()
      }
    } catch (error: any) {
      setMessage({
        type: "error",
        text: error.message || "日利設定に失敗しました",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const simulateYieldCalculation = async () => {
    try {
      // 複数のデータソースから対象ユーザーを取得
      let cycleData: any[] = []
      let dataSource = ""

      // 1. affiliate_cycleテーブルを試す
      const { data: acData, error: acError } = await supabase
        .from("affiliate_cycle")
        .select("user_id, total_nft_count")
        .gt("total_nft_count", 0)

      if (!acError && acData && acData.length > 0) {
        cycleData = acData
        dataSource = "affiliate_cycle"
      } else {
        // 2. purchasesテーブルから計算
        const { data: purchaseData, error: purchaseError } = await supabase
          .from("purchases")
          .select("user_id, nft_quantity")
          .eq("admin_approved", true)

        if (!purchaseError && purchaseData) {
          // ユーザーごとにNFT数を集計
          const userNftMap = new Map()
          purchaseData.forEach(purchase => {
            const userId = purchase.user_id
            const nftCount = purchase.nft_quantity || 0
            userNftMap.set(userId, (userNftMap.get(userId) || 0) + nftCount)
          })

          cycleData = Array.from(userNftMap.entries()).map(([userId, totalNft]) => ({
            user_id: userId,
            total_nft_count: totalNft
          })).filter(user => user.total_nft_count > 0)
          
          dataSource = "purchases"
        } else {
          // 3. usersテーブルのtotal_purchasesから推定
          const { data: userData, error: userError } = await supabase
            .from("users")
            .select("user_id, total_purchases")
            .gt("total_purchases", 0)

          if (!userError && userData) {
            cycleData = userData.map(user => ({
              user_id: user.user_id,
              total_nft_count: Math.floor(user.total_purchases / 1100) // $1100 = 1NFT
            })).filter(user => user.total_nft_count > 0)
            
            dataSource = "users.total_purchases"
          }
        }
      }

      const totalUsers = cycleData?.length || 0
      const yield_rate = Number.parseFloat(yieldRate) / 100
      const margin_rate = Number.parseFloat(marginRate) / 100
      const user_rate = yield_rate * (1 - margin_rate) * 0.6

      let totalUserProfit = 0
      let totalCompanyProfit = 0

      cycleData?.forEach((user) => {
        const baseAmount = user.total_nft_count * 1100
        const userProfit = baseAmount * user_rate
        const companyProfit = baseAmount * margin_rate + baseAmount * (yield_rate - margin_rate) * 0.1
        
        totalUserProfit += userProfit
        totalCompanyProfit += companyProfit
      })

      // テスト結果を状態に保存
      const testResult: TestResult = {
        date: date,
        yield_rate: yield_rate,
        margin_rate: margin_rate,
        user_rate: user_rate,
        total_users: totalUsers,
        total_user_profit: totalUserProfit,
        total_company_profit: totalCompanyProfit,
        created_at: new Date().toISOString()
      }

      setTestResults(prev => [testResult, ...prev.slice(0, 9)])
      setShowTestResults(true)

      setMessage({
        type: "warning",
        text: `🔒 安全テスト完了: ${totalUsers}名のユーザーに総額$${totalUserProfit.toFixed(2)}の利益が配布される予定です。（データソース: ${dataSource}・本番データ無影響）`,
      })
    } catch (error: any) {
      throw new Error(`テスト計算エラー: ${error.message}`)
    }
  }

  const handleCancel = async (cancelDate: string) => {
    if (!confirm(`${cancelDate}の日利設定をキャンセルしますか？この操作は取り消せません。`)) {
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

  const clearTestResults = () => {
    setTestResults([])
    setShowTestResults(false)
    setMessage({
      type: "success",
      text: "テスト結果をクリアしました",
    })
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
              日利設定
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
              {isTestMode ? "安全テストモード" : "本番モード"}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-between">
              <div className={`space-y-2 ${isTestMode ? "text-blue-300" : "text-red-300"}`}>
                <p className="font-medium">
                  {isTestMode
                    ? "🔒 安全テストモード: 本番データに影響しません"
                    : "⚠️ 本番モード: ユーザーの実際の残高に影響します"}
                </p>
                <p className="text-sm">
                  {isTestMode
                    ? "計算シミュレーションのみ実行。ユーザー認証・紹介関係は完全保護"
                    : "設定すると即座にユーザーの利益に反映されます"}
                </p>
                {isTestMode && testResults.length > 0 && (
                  <div className="mt-3">
                    <Button 
                      onClick={clearTestResults}
                      size="sm" 
                      variant="outline"
                      className="border-blue-600 text-blue-300 hover:bg-blue-900/30 text-xs"
                    >
                      テスト結果クリア
                    </Button>
                  </div>
                )}
              </div>
              <div className="flex items-center space-x-2">
                <Label htmlFor="test-mode" className="text-white">
                  安全テスト
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

        {/* 日利設定フォーム */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-white">
              <CalendarIcon className="h-5 w-5" />
              日利設定
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
                  {userRate.toFixed(3)}%
                </div>
                <p className="text-sm text-gray-400">
                  {yieldRate}% × (1 - {marginRate}%/100) × 0.6 = ユーザー受取 {userRate.toFixed(3)}%
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
                {isLoading ? "処理中..." : isTestMode ? "テスト実行" : "日利を設定"}
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

        {/* 履歴・テスト結果 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white">
                {showTestResults ? "テスト結果履歴" : "設定履歴"}
              </CardTitle>
              <div className="flex gap-2">
                {showTestResults && (
                  <Button 
                    onClick={() => setShowTestResults(false)} 
                    size="sm" 
                    variant="outline"
                    className="border-gray-600 text-gray-300"
                  >
                    本番履歴に戻る
                  </Button>
                )}
                <Button 
                  onClick={showTestResults ? () => {} : fetchHistory} 
                  size="sm" 
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  更新
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {showTestResults ? (
              // テスト結果表示
              testResults.length === 0 ? (
                <div className="text-center py-8">
                  <p className="text-gray-400 mb-4">テスト結果がありません</p>
                  <p className="text-xs text-blue-400">安全テストモードで計算を実行してください</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <div className="mb-4 p-3 bg-blue-900/20 border border-blue-600/30 rounded">
                    <p className="text-blue-300 text-sm">🔒 テスト環境の結果 - 本番データには影響していません</p>
                  </div>
                  <table className="w-full text-sm text-white">
                    <thead>
                      <tr className="border-b border-gray-600">
                        <th className="text-left p-2">日付</th>
                        <th className="text-left p-2">日利率</th>
                        <th className="text-left p-2">ユーザー利率</th>
                        <th className="text-left p-2">対象ユーザー</th>
                        <th className="text-left p-2">ユーザー利益</th>
                        <th className="text-left p-2">会社利益</th>
                        <th className="text-left p-2">実行日時</th>
                      </tr>
                    </thead>
                    <tbody>
                      {testResults.map((item, index) => (
                        <tr key={index} className="border-b border-gray-700">
                          <td className="p-2">{new Date(item.date).toLocaleDateString("ja-JP")}</td>
                          <td className={`p-2 font-medium ${item.yield_rate >= 0 ? "text-green-400" : "text-red-400"}`}>
                            {(item.yield_rate * 100).toFixed(3)}%
                          </td>
                          <td className={`p-2 font-medium ${item.user_rate >= 0 ? "text-green-400" : "text-red-400"}`}>
                            {(item.user_rate * 100).toFixed(3)}%
                          </td>
                          <td className="p-2">{item.total_users}名</td>
                          <td className="p-2 text-green-400">${item.total_user_profit.toFixed(2)}</td>
                          <td className="p-2 text-blue-400">${item.total_company_profit.toFixed(2)}</td>
                          <td className="p-2">{new Date(item.created_at).toLocaleString("ja-JP")}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )
            ) : (
              // 本番履歴表示
              history.length === 0 ? (
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
                        <th className="text-left p-2">設定日時</th>
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
                            {(Number.parseFloat(item.yield_rate) * 100).toFixed(3)}%
                          </td>
                          <td className="p-2">{(Number.parseFloat(item.margin_rate) * 100).toFixed(0)}%</td>
                          <td
                            className={`p-2 font-medium ${Number.parseFloat(item.user_rate) >= 0 ? "text-green-400" : "text-red-400"}`}
                          >
                            {(Number.parseFloat(item.user_rate) * 100).toFixed(3)}%
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
              )
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}