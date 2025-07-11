"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { ArrowLeft, Database, RefreshCw, AlertTriangle, CheckCircle, Info, Search, User, DollarSign } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface DatabaseStats {
  userDailyProfit: {
    totalRecords: number
    totalProfit: number
    dateRange: string
    usersWithProfit: number
  }
  affiliateCycle: {
    totalUsers: number
    usersWithNFTs: number
    totalNFTs: number
  }
  purchases: {
    totalPurchases: number
    approvedPurchases: number
    totalNFTs: number
    totalAmount: number
  }
  dailyYield: {
    totalSettings: number
    latestDate: string
    latestYieldRate: number
    latestUserRate: number
  }
  yesterdayData: {
    usersWithProfit: number
    totalProfit: number
    date: string
  }
  sampleUsers: Array<{
    userId: string
    totalPurchases: number
    profitDays: number
    totalProfit: number
    expectedNFTs: number
    actualNFTs: number
  }>
}

interface UserInvestigation {
  basic_info?: any
  purchases?: any[]
  daily_profits?: any[]
  affiliate_cycle?: any
  monthly_withdrawals?: any[]
  referrals?: any[]
}

export default function DatabaseCheckPage() {
  const [stats, setStats] = useState<DatabaseStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [isAdmin, setIsAdmin] = useState(false)
  const [searchUserId, setSearchUserId] = useState("2BF53B")
  const [investigation, setInvestigation] = useState<UserInvestigation>({})
  const [investigationLoading, setInvestigationLoading] = useState(false)
  const [investigationError, setInvestigationError] = useState("")
  const router = useRouter()

  useEffect(() => {
    checkAdminAndFetchData()
  }, [])

  const checkAdminAndFetchData = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        router.push("/login")
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError || !adminCheck) {
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      await fetchDatabaseStats()
    } catch (err: any) {
      setError(`管理者確認エラー: ${err.message}`)
      setLoading(false)
    }
  }

  const fetchDatabaseStats = async () => {
    try {
      setLoading(true)
      setError("")

      // 1. user_daily_profitテーブルの確認
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('date, daily_profit, user_id')

      if (profitError) throw new Error(`user_daily_profit: ${profitError.message}`)

      const profitStats = {
        totalRecords: profitData?.length || 0,
        totalProfit: profitData?.reduce((sum, row) => sum + (row.daily_profit || 0), 0) || 0,
        dateRange: profitData?.length ? `${Math.min(...profitData.map(d => d.date))} ～ ${Math.max(...profitData.map(d => d.date))}` : "データなし",
        usersWithProfit: new Set(profitData?.map(d => d.user_id)).size || 0
      }

      // 2. affiliate_cycleテーブルの確認（管理者関数使用）
      const { data: { user } } = await supabase.auth.getUser()
      
      const { data: migrationStatsData, error: statsError } = await supabase
        .rpc('admin_get_migration_stats', {
          p_admin_email: user?.email
        })

      let cycleStats = { totalUsers: 0, usersWithNFTs: 0, totalNFTs: 0 }
      
      if (statsError) {
        console.error('管理者統計関数エラー:', statsError)
        // フォールバック: 直接クエリ
        const { data: cycleData, error: cycleError } = await supabase
          .from('affiliate_cycle')
          .select('user_id, total_nft_count')

        if (!cycleError && cycleData) {
          cycleStats = {
            totalUsers: cycleData.length,
            usersWithNFTs: cycleData.filter(u => u.total_nft_count > 0).length,
            totalNFTs: cycleData.reduce((sum, u) => sum + (u.total_nft_count || 0), 0)
          }
        }
      } else if (migrationStatsData) {
        const affiliateCycleStats = migrationStatsData.find(stat => stat.table_name === 'affiliate_cycle')
        if (affiliateCycleStats && affiliateCycleStats.sample_data) {
          cycleStats = {
            totalUsers: affiliateCycleStats.total_records || 0,
            usersWithNFTs: affiliateCycleStats.sample_data.filter((item: any) => item.nft_count > 0).length || 0,
            totalNFTs: affiliateCycleStats.sample_data.reduce((sum: number, item: any) => sum + (item.nft_count || 0), 0) || 0
          }
        }
      }

      // 3. purchasesテーブルの確認
      const { data: purchaseData, error: purchaseError } = await supabase
        .from('purchases')
        .select('nft_quantity, amount_usd, admin_approved')

      if (purchaseError) throw new Error(`purchases: ${purchaseError.message}`)

      const purchaseStats = {
        totalPurchases: purchaseData?.length || 0,
        approvedPurchases: purchaseData?.filter(p => p.admin_approved).length || 0,
        totalNFTs: purchaseData?.reduce((sum, p) => sum + (p.nft_quantity || 0), 0) || 0,
        totalAmount: purchaseData?.reduce((sum, p) => sum + parseFloat(p.amount_usd || '0'), 0) || 0
      }

      // 4. daily_yield_logテーブルの確認
      const { data: yieldData, error: yieldError } = await supabase
        .from('daily_yield_log')
        .select('date, yield_rate, user_rate')
        .order('date', { ascending: false })
        .limit(1)

      if (yieldError) throw new Error(`daily_yield_log: ${yieldError.message}`)

      const yieldStats = {
        totalSettings: yieldData?.length || 0,
        latestDate: yieldData?.[0]?.date || "未設定",
        latestYieldRate: yieldData?.[0]?.yield_rate ? yieldData[0].yield_rate * 100 : 0,
        latestUserRate: yieldData?.[0]?.user_rate ? yieldData[0].user_rate * 100 : 0
      }

      // 5. 昨日のデータ確認
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]

      const { data: yesterdayData, error: yesterdayError } = await supabase
        .from('user_daily_profit')
        .select('user_id, daily_profit')
        .eq('date', yesterdayStr)

      const yesterdayStats = {
        usersWithProfit: yesterdayData?.length || 0,
        totalProfit: yesterdayData?.reduce((sum, p) => sum + (p.daily_profit || 0), 0) || 0,
        date: yesterdayStr
      }

      // 6. サンプルユーザーデータ（投資額上位5名）
      const { data: sampleUsersData, error: usersError } = await supabase
        .from('users')
        .select('user_id, total_purchases')
        .gt('total_purchases', 0)
        .order('total_purchases', { ascending: false })
        .limit(5)

      const sampleUsers = []
      if (sampleUsersData) {
        for (const user of sampleUsersData) {
          const { data: userProfits } = await supabase
            .from('user_daily_profit')
            .select('daily_profit')
            .eq('user_id', user.user_id)

          const { data: cycleInfo } = await supabase
            .from('affiliate_cycle')
            .select('total_nft_count')
            .eq('user_id', user.user_id)
            .single()

          sampleUsers.push({
            userId: user.user_id,
            totalPurchases: user.total_purchases,
            profitDays: userProfits?.length || 0,
            totalProfit: userProfits?.reduce((sum, p) => sum + (p.daily_profit || 0), 0) || 0,
            expectedNFTs: Math.floor(user.total_purchases / 1100),
            actualNFTs: cycleInfo?.total_nft_count || 0
          })
        }
      }

      setStats({
        userDailyProfit: profitStats,
        affiliateCycle: cycleStats,
        purchases: purchaseStats,
        dailyYield: yieldStats,
        yesterdayData: yesterdayStats,
        sampleUsers
      })

    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const investigateUser = async () => {
    if (!searchUserId.trim()) return

    try {
      setInvestigationLoading(true)
      setInvestigationError("")
      setInvestigation({})

      const userId = searchUserId.trim()

      // 1. 基本情報
      const { data: basicInfo, error: basicError } = await supabase
        .from("users")
        .select("*")
        .or(`user_id.eq.${userId},email.ilike.%${userId}%`)
        .single()

      if (basicError && basicError.code !== "PGRST116") {
        throw basicError
      }

      const actualUserId = basicInfo?.user_id || userId

      // 2. 購入履歴
      const { data: purchases, error: purchasesError } = await supabase
        .from("purchases")
        .select("*")
        .eq("user_id", actualUserId)
        .order("created_at", { ascending: false })

      // 3. 日利履歴（全件）
      const { data: dailyProfits, error: dailyError } = await supabase
        .from("user_daily_profit")
        .select("*")
        .eq("user_id", actualUserId)
        .order("date", { ascending: false })

      // 4. アフィリエイトサイクル
      const { data: affiliateCycle, error: cycleError } = await supabase
        .from("affiliate_cycle")
        .select("*")
        .eq("user_id", actualUserId)
        .single()

      // 5. 月末出金記録
      const { data: monthlyWithdrawals, error: withdrawalError } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("user_id", actualUserId)
        .order("withdrawal_month", { ascending: false })

      // 6. 紹介関係
      const { data: referrals, error: referralError } = await supabase
        .from("users")
        .select("user_id, email, total_purchases, created_at")
        .eq("referrer_user_id", actualUserId)
        .order("created_at", { ascending: false })

      setInvestigation({
        basic_info: basicInfo,
        purchases: purchases || [],
        daily_profits: dailyProfits || [],
        affiliate_cycle: affiliateCycle,
        monthly_withdrawals: monthlyWithdrawals || [],
        referrals: referrals || []
      })

    } catch (err: any) {
      console.error("Investigation error:", err)
      setInvestigationError(`調査中にエラーが発生しました: ${err.message}`)
    } finally {
      setInvestigationLoading(false)
    }
  }

  const calculateUserTotals = () => {
    if (!investigation.basic_info) return { grandTotal: 0 }

    const totalPurchases = investigation.basic_info?.total_purchases || 0
    const totalDailyProfit = investigation.daily_profits?.reduce((sum, p) => sum + parseFloat(p.daily_profit || 0), 0) || 0
    const availableUsdt = investigation.affiliate_cycle?.available_usdt || 0
    const cumUsdt = investigation.affiliate_cycle?.cum_usdt || 0

    return {
      totalPurchases,
      totalDailyProfit,
      availableUsdt,
      cumUsdt,
      grandTotal: totalPurchases + totalDailyProfit + availableUsdt
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardContent className="p-6 text-center text-white">
            <AlertTriangle className="w-12 h-12 mx-auto mb-4 text-red-400" />
            <p>管理者権限が必要です</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-7xl mx-auto space-y-6">
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
              <Database className="w-8 h-8 mr-3 text-blue-400" />
              データベース状況確認
            </h1>
          </div>
          <Button
            onClick={fetchDatabaseStats}
            disabled={loading}
            className="bg-blue-600 hover:bg-blue-700"
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            更新
          </Button>
        </div>

        {error && (
          <Card className="bg-red-900/20 border-red-500/50">
            <CardContent className="p-4 text-red-400 text-center">
              <AlertTriangle className="w-5 h-5 inline mr-2" />
              {error}
            </CardContent>
          </Card>
        )}

        {loading ? (
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-8 text-center text-white">
              <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-4 text-blue-400" />
              データベースを確認中...
            </CardContent>
          </Card>
        ) : stats ? (
          <div className="space-y-6">
            {/* ユーザー調査セクション */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <User className="w-5 h-5 mr-2 text-blue-400" />
                  ユーザー詳細調査
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-center space-x-4 mb-4">
                  <div className="flex-1">
                    <Input
                      placeholder="ユーザーID またはメールアドレス"
                      value={searchUserId}
                      onChange={(e) => setSearchUserId(e.target.value)}
                      className="bg-gray-700 border-gray-600 text-white"
                    />
                  </div>
                  <Button
                    onClick={investigateUser}
                    disabled={investigationLoading}
                    className="bg-blue-600 hover:bg-blue-700"
                  >
                    {investigationLoading ? <RefreshCw className="h-4 w-4 animate-spin mr-2" /> : <Search className="h-4 w-4 mr-2" />}
                    調査開始
                  </Button>
                </div>

                {investigationError && (
                  <Card className="bg-red-900/20 border-red-500/50 mb-4">
                    <CardContent className="p-3">
                      <p className="text-red-200 text-sm">{investigationError}</p>
                    </CardContent>
                  </Card>
                )}

                {investigation.basic_info && (
                  <div className="space-y-4">
                    {/* 基本情報 */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div>
                        <p className="text-gray-400 text-sm">ユーザーID</p>
                        <p className="text-white font-mono">{investigation.basic_info.user_id}</p>
                      </div>
                      <div>
                        <p className="text-gray-400 text-sm">メール</p>
                        <p className="text-white text-sm">{investigation.basic_info.email}</p>
                      </div>
                      <div>
                        <p className="text-gray-400 text-sm">NFT購入額</p>
                        <p className="text-white font-bold">${investigation.basic_info.total_purchases?.toFixed(2)}</p>
                      </div>
                      <div>
                        <p className="text-gray-400 text-sm">登録日</p>
                        <p className="text-white text-sm">{new Date(investigation.basic_info.created_at).toLocaleDateString('ja-JP')}</p>
                      </div>
                    </div>

                    {/* 金額サマリー */}
                    <div className="mt-4 p-4 bg-blue-900/20 border border-blue-700/50 rounded-lg">
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <div className="text-center">
                          <p className="text-gray-400 text-sm">NFT購入額</p>
                          <p className="text-xl font-bold text-white">${calculateUserTotals().totalPurchases.toFixed(2)}</p>
                        </div>
                        <div className="text-center">
                          <p className="text-gray-400 text-sm">日利合計</p>
                          <p className="text-xl font-bold text-green-400">${calculateUserTotals().totalDailyProfit.toFixed(2)}</p>
                        </div>
                        <div className="text-center">
                          <p className="text-gray-400 text-sm">累積USDT</p>
                          <p className="text-xl font-bold text-blue-400">${calculateUserTotals().cumUsdt.toFixed(2)}</p>
                        </div>
                        <div className="text-center">
                          <p className="text-gray-400 text-sm">利用可能額</p>
                          <p className="text-xl font-bold text-purple-400">${calculateUserTotals().availableUsdt.toFixed(2)}</p>
                        </div>
                      </div>
                      <div className="mt-4 pt-4 border-t border-blue-600/30">
                        <div className="flex justify-between items-center">
                          <span className="text-yellow-200 font-medium">推定総資産額:</span>
                          <span className="text-2xl font-bold text-yellow-400">${calculateUserTotals().grandTotal.toFixed(2)}</span>
                        </div>
                        <p className="text-yellow-300 text-sm mt-2">
                          詳細: 購入${calculateUserTotals().totalPurchases.toFixed(2)} + 日利${calculateUserTotals().totalDailyProfit.toFixed(2)} + 利用可能${calculateUserTotals().availableUsdt.toFixed(2)}
                        </p>
                      </div>
                    </div>

                    {/* データ詳細 */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                      <div>
                        <p className="text-gray-400">購入履歴</p>
                        <p className="text-white">{investigation.purchases?.length || 0}件</p>
                      </div>
                      <div>
                        <p className="text-gray-400">日利記録</p>
                        <p className="text-white">{investigation.daily_profits?.length || 0}日</p>
                      </div>
                      <div>
                        <p className="text-gray-400">出金記録</p>
                        <p className="text-white">{investigation.monthly_withdrawals?.length || 0}件</p>
                      </div>
                      <div>
                        <p className="text-gray-400">紹介者</p>
                        <p className="text-white">{investigation.referrals?.length || 0}人</p>
                      </div>
                    </div>
                  </div>
                )}
              </CardContent>
            </Card>

            {/* 昨日のデータ状況 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <AlertTriangle className="w-5 h-5 mr-2 text-yellow-400" />
                  昨日の利益データ状況
                </CardTitle>
              </CardHeader>
              <CardContent className="text-white">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <p className="text-gray-400">日付</p>
                    <p className="text-xl font-bold">{stats.yesterdayData.date}</p>
                  </div>
                  <div>
                    <p className="text-gray-400">利益データのあるユーザー数</p>
                    <p className={`text-xl font-bold ${stats.yesterdayData.usersWithProfit > 0 ? 'text-green-400' : 'text-red-400'}`}>
                      {stats.yesterdayData.usersWithProfit}名
                    </p>
                  </div>
                  <div>
                    <p className="text-gray-400">昨日の総利益</p>
                    <p className={`text-xl font-bold ${stats.yesterdayData.totalProfit > 0 ? 'text-green-400' : 'text-red-400'}`}>
                      ${stats.yesterdayData.totalProfit.toFixed(3)}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* サンプルユーザー分析 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <Info className="w-5 h-5 mr-2 text-blue-400" />
                  投資額上位ユーザーの利益状況
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm text-white">
                    <thead>
                      <tr className="border-b border-gray-600">
                        <th className="text-left p-2">ユーザーID</th>
                        <th className="text-left p-2">投資額</th>
                        <th className="text-left p-2">期待NFT数</th>
                        <th className="text-left p-2">実際NFT数</th>
                        <th className="text-left p-2">利益日数</th>
                        <th className="text-left p-2">総利益</th>
                        <th className="text-left p-2">状況</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stats.sampleUsers.map((user, index) => (
                        <tr key={index} className="border-b border-gray-700">
                          <td className="p-2 font-mono">{user.userId}</td>
                          <td className="p-2">${user.totalPurchases.toLocaleString()}</td>
                          <td className="p-2">{user.expectedNFTs}</td>
                          <td className={`p-2 ${user.actualNFTs === user.expectedNFTs ? 'text-green-400' : 'text-red-400'}`}>
                            {user.actualNFTs}
                          </td>
                          <td className="p-2">{user.profitDays}日</td>
                          <td className={`p-2 ${user.totalProfit > 0 ? 'text-green-400' : 'text-red-400'}`}>
                            ${user.totalProfit.toFixed(3)}
                          </td>
                          <td className="p-2">
                            {user.profitDays > 0 ? (
                              <Badge className="bg-green-600 text-white">利益あり</Badge>
                            ) : (
                              <Badge className="bg-red-600 text-white">利益なし</Badge>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>

            {/* 詳細統計 */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* user_daily_profit */}
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white">user_daily_profit テーブル</CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <p>総レコード数: <span className="font-bold">{stats.userDailyProfit.totalRecords}</span></p>
                  <p>利益を持つユーザー数: <span className="font-bold">{stats.userDailyProfit.usersWithProfit}</span></p>
                  <p>総利益: <span className="font-bold">${stats.userDailyProfit.totalProfit.toFixed(3)}</span></p>
                  <p>期間: <span className="font-bold">{stats.userDailyProfit.dateRange}</span></p>
                </CardContent>
              </Card>

              {/* affiliate_cycle */}
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white">affiliate_cycle テーブル</CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <p>総ユーザー数: <span className="font-bold">{stats.affiliateCycle.totalUsers}</span></p>
                  <p>NFT保有ユーザー数: <span className="font-bold">{stats.affiliateCycle.usersWithNFTs}</span></p>
                  <p>総NFT数: <span className="font-bold">{stats.affiliateCycle.totalNFTs}</span></p>
                </CardContent>
              </Card>

              {/* purchases */}
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white">purchases テーブル</CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <p>総購入数: <span className="font-bold">{stats.purchases.totalPurchases}</span></p>
                  <p>承認済み購入数: <span className="font-bold">{stats.purchases.approvedPurchases}</span></p>
                  <p>購入NFT総数: <span className="font-bold">{stats.purchases.totalNFTs}</span></p>
                  <p>総投資額: <span className="font-bold">${stats.purchases.totalAmount.toLocaleString()}</span></p>
                </CardContent>
              </Card>

              {/* daily_yield_log */}
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white">daily_yield_log テーブル</CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <p>最新設定日: <span className="font-bold">{stats.dailyYield.latestDate}</span></p>
                  <p>最新日利率: <span className="font-bold">{stats.dailyYield.latestYieldRate.toFixed(3)}%</span></p>
                  <p>最新ユーザー利率: <span className="font-bold">{stats.dailyYield.latestUserRate.toFixed(3)}%</span></p>
                </CardContent>
              </Card>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  )
}