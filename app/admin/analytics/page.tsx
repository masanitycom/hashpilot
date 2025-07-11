"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { 
  ArrowLeft, 
  BarChart3, 
  TrendingUp, 
  Users, 
  DollarSign, 
  ShoppingCart,
  RefreshCw,
  Calendar,
  Target,
  Activity,
  PieChart,
  Shield
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface AnalyticsData {
  overview: {
    totalUsers: number
    totalRevenue: number
    totalPurchases: number
    activeUsers: number
    conversionRate: number
  }
  monthly: {
    newUsers: number
    newPurchases: number
    revenue: number
    growthRate: number
  }
  referrals: {
    totalReferrers: number
    totalReferrals: number
    averageReferrals: number
    topReferrer: { email: string; count: number } | null
  }
  nft: {
    totalNFTs: number
    manualNFTs: number
    autoNFTs: number
    averagePerUser: number
  }
}

export default function AdminAnalyticsPage() {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [isAdmin, setIsAdmin] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push("/login")
        return
      }

      // 緊急対応: basarasystems@gmail.com のアクセス許可
      if (user.email === "basarasystems@gmail.com") {
        setIsAdmin(true)
        await fetchAnalytics()
        return
      }

      // RPC関数で管理者権限をチェック
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError) {
        console.error("Admin RPC error:", adminError)
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userData, error } = await supabase
          .from("users")
          .select("is_admin")
          .eq("id", user.id)
          .single()

        if (error || !userData?.is_admin) {
          router.push("/dashboard")
          return
        }
      } else if (!adminCheck) {
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userData, error } = await supabase
          .from("users")
          .select("is_admin")
          .eq("id", user.id)
          .single()

        if (error || !userData?.is_admin) {
          router.push("/dashboard")
          return
        }
      }

      setIsAdmin(true)
      await fetchAnalytics()
    } catch (error) {
      console.error("Error checking admin access:", error)
      router.push("/dashboard")
    }
  }

  const fetchAnalytics = async () => {
    try {
      setLoading(true)
      setError("")

      // Fetch users data (basarasystems@gmail.comを除外)
      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select("id, email, created_at, is_active, total_purchases, referrer_user_id")
        .neq("email", "basarasystems@gmail.com")

      if (usersError) throw usersError

      // Fetch purchases data
      const { data: purchasesData, error: purchasesError } = await supabase
        .from("purchases")
        .select("id, user_id, amount_usd, admin_approved, created_at, nft_quantity")

      if (purchasesError) throw purchasesError

      // Calculate overview metrics
      const totalUsers = usersData?.length || 0
      const activeUsers = usersData?.filter(u => u.is_active).length || 0
      const approvedPurchases = purchasesData?.filter(p => p.admin_approved) || []
      const totalRevenue = approvedPurchases.reduce((sum, p) => sum + (p.amount_usd || 0), 0)
      const totalPurchases = approvedPurchases.length
      const conversionRate = totalUsers > 0 ? (totalPurchases / totalUsers) * 100 : 0

      // Calculate monthly data (current month)
      const currentMonth = new Date().getMonth()
      const currentYear = new Date().getFullYear()
      
      const monthlyUsers = usersData?.filter(u => {
        const userDate = new Date(u.created_at)
        return userDate.getMonth() === currentMonth && userDate.getFullYear() === currentYear
      }) || []

      const monthlyPurchases = approvedPurchases.filter(p => {
        const purchaseDate = new Date(p.created_at)
        return purchaseDate.getMonth() === currentMonth && purchaseDate.getFullYear() === currentYear
      })

      const monthlyRevenue = monthlyPurchases.reduce((sum, p) => sum + (p.amount_usd || 0), 0)
      
      // Calculate growth rate (simplified)
      const previousMonthPurchases = approvedPurchases.filter(p => {
        const purchaseDate = new Date(p.created_at)
        const prevMonth = currentMonth === 0 ? 11 : currentMonth - 1
        const prevYear = currentMonth === 0 ? currentYear - 1 : currentYear
        return purchaseDate.getMonth() === prevMonth && purchaseDate.getFullYear() === prevYear
      })
      
      const growthRate = previousMonthPurchases.length > 0 
        ? ((monthlyPurchases.length - previousMonthPurchases.length) / previousMonthPurchases.length) * 100 
        : 0

      // Calculate referral metrics
      const usersWithReferrals = usersData?.filter(u => u.referrer_user_id) || []
      const referrerCounts = new Map()
      
      usersWithReferrals.forEach(user => {
        const referrerId = user.referrer_user_id
        referrerCounts.set(referrerId, (referrerCounts.get(referrerId) || 0) + 1)
      })

      const topReferrerEntry = Array.from(referrerCounts.entries())
        .sort(([,a], [,b]) => b - a)[0]
      
      let topReferrer = null
      if (topReferrerEntry) {
        const [referrerId, count] = topReferrerEntry
        const referrerUser = usersData?.find(u => u.id === referrerId)
        if (referrerUser) {
          topReferrer = { email: referrerUser.email, count }
        }
      }

      // Calculate NFT metrics
      const totalNFTs = approvedPurchases.reduce((sum, p) => sum + (p.nft_quantity || 0), 0)
      const averageNFTsPerUser = totalUsers > 0 ? totalNFTs / totalUsers : 0

      const analyticsData: AnalyticsData = {
        overview: {
          totalUsers,
          totalRevenue,
          totalPurchases,
          activeUsers,
          conversionRate
        },
        monthly: {
          newUsers: monthlyUsers.length,
          newPurchases: monthlyPurchases.length,
          revenue: monthlyRevenue,
          growthRate
        },
        referrals: {
          totalReferrers: referrerCounts.size,
          totalReferrals: usersWithReferrals.length,
          averageReferrals: referrerCounts.size > 0 ? usersWithReferrals.length / referrerCounts.size : 0,
          topReferrer
        },
        nft: {
          totalNFTs,
          manualNFTs: 0, // Would need additional data to calculate
          autoNFTs: 0,   // Would need additional data to calculate
          averagePerUser: averageNFTsPerUser
        }
      }

      setAnalytics(analyticsData)
    } catch (err: any) {
      setError(`分析データの取得に失敗しました: ${err.message}`)
    } finally {
      setLoading(false)
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardContent className="p-6 text-center text-white">
            <Shield className="w-12 h-12 mx-auto mb-4 text-red-400" />
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
              <BarChart3 className="w-8 h-8 mr-3 text-indigo-400" />
              分析ダッシュボード
            </h1>
          </div>
          <Button
            onClick={fetchAnalytics}
            disabled={loading}
            className="bg-indigo-600 hover:bg-indigo-700"
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            更新
          </Button>
        </div>

        {error && (
          <Alert className="bg-red-900/20 border-red-500/50">
            <AlertDescription className="text-red-400">{error}</AlertDescription>
          </Alert>
        )}

        {loading ? (
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-8 text-center text-white">
              <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-4 text-indigo-400" />
              分析データを取得中...
            </CardContent>
          </Card>
        ) : analytics ? (
          <div className="space-y-6">
            {/* 概要メトリクス */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              <Card className="bg-gradient-to-br from-blue-500 to-blue-600 border-0 text-white">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-3">
                    <Users className="w-8 h-8 text-white opacity-80" />
                    <div>
                      <p className="text-blue-100 text-xs font-medium">総ユーザー数</p>
                      <p className="text-xl font-bold">{analytics.overview.totalUsers}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-green-500 to-green-600 border-0 text-white">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-3">
                    <DollarSign className="w-8 h-8 text-white opacity-80" />
                    <div>
                      <p className="text-green-100 text-xs font-medium">総売上</p>
                      <p className="text-xl font-bold">${analytics.overview.totalRevenue.toLocaleString()}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-purple-500 to-purple-600 border-0 text-white">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-3">
                    <ShoppingCart className="w-8 h-8 text-white opacity-80" />
                    <div>
                      <p className="text-purple-100 text-xs font-medium">総購入数</p>
                      <p className="text-xl font-bold">{analytics.overview.totalPurchases}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-yellow-500 to-yellow-600 border-0 text-white">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-3">
                    <Activity className="w-8 h-8 text-white opacity-80" />
                    <div>
                      <p className="text-yellow-100 text-xs font-medium">アクティブユーザー</p>
                      <p className="text-xl font-bold">{analytics.overview.activeUsers}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-indigo-500 to-indigo-600 border-0 text-white">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-3">
                    <Target className="w-8 h-8 text-white opacity-80" />
                    <div>
                      <p className="text-indigo-100 text-xs font-medium">コンバージョン率</p>
                      <p className="text-xl font-bold">{analytics.overview.conversionRate.toFixed(1)}%</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* 月別データ */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <Calendar className="w-5 h-5 mr-2 text-blue-400" />
                  今月の実績
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                  <div className="text-center p-4 bg-blue-900/20 rounded-lg">
                    <p className="text-2xl font-bold text-blue-400">{analytics.monthly.newUsers}</p>
                    <p className="text-sm text-gray-400">新規ユーザー</p>
                  </div>
                  <div className="text-center p-4 bg-green-900/20 rounded-lg">
                    <p className="text-2xl font-bold text-green-400">{analytics.monthly.newPurchases}</p>
                    <p className="text-sm text-gray-400">新規購入</p>
                  </div>
                  <div className="text-center p-4 bg-yellow-900/20 rounded-lg">
                    <p className="text-2xl font-bold text-yellow-400">${analytics.monthly.revenue.toLocaleString()}</p>
                    <p className="text-sm text-gray-400">今月の売上</p>
                  </div>
                  <div className="text-center p-4 bg-purple-900/20 rounded-lg">
                    <div className="flex items-center justify-center space-x-1">
                      <TrendingUp className="w-4 h-4 text-purple-400" />
                      <p className="text-2xl font-bold text-purple-400">
                        {analytics.monthly.growthRate > 0 ? '+' : ''}{analytics.monthly.growthRate.toFixed(1)}%
                      </p>
                    </div>
                    <p className="text-sm text-gray-400">成長率</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 紹介統計とNFT統計 */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center">
                    <Users className="w-5 h-5 mr-2 text-green-400" />
                    紹介ネットワーク
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-gray-300">紹介者数:</span>
                    <Badge className="bg-green-600">{analytics.referrals.totalReferrers}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-300">被紹介者数:</span>
                    <Badge className="bg-blue-600">{analytics.referrals.totalReferrals}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-300">平均紹介数:</span>
                    <Badge className="bg-purple-600">{analytics.referrals.averageReferrals.toFixed(1)}</Badge>
                  </div>
                  {analytics.referrals.topReferrer && (
                    <div className="mt-4 p-3 bg-yellow-900/20 rounded-lg">
                      <p className="text-sm text-gray-400">トップ紹介者</p>
                      <p className="text-yellow-400 font-medium">{analytics.referrals.topReferrer.email}</p>
                      <p className="text-xs text-gray-500">{analytics.referrals.topReferrer.count}人紹介</p>
                    </div>
                  )}
                </CardContent>
              </Card>

              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center">
                    <PieChart className="w-5 h-5 mr-2 text-orange-400" />
                    NFT統計
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-gray-300">総NFT数:</span>
                    <Badge className="bg-orange-600">{analytics.nft.totalNFTs}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-300">ユーザー平均:</span>
                    <Badge className="bg-purple-600">{analytics.nft.averagePerUser.toFixed(1)}</Badge>
                  </div>
                  <div className="mt-4 p-3 bg-orange-900/20 rounded-lg">
                    <p className="text-sm text-gray-400">NFT分散度</p>
                    <p className="text-orange-400 font-medium">
                      {analytics.overview.totalUsers > 0 ? 
                        `${((analytics.nft.totalNFTs / analytics.overview.totalUsers) * 100).toFixed(1)}%` 
                        : '0%'
                      }
                    </p>
                    <p className="text-xs text-gray-500">平均保有率</p>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  )
}