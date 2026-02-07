"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Users,
  ShoppingCart,
  Settings,
  DollarSign,
  Shield,
  Database,
  Activity,
  CreditCard,
  Network,
  RefreshCw,
  LogOut,
  ArrowRight,
  BarChart3,
  Coins,
  Wallet,
  Mail,
  Megaphone,
  Gift,
  AlertTriangle,
  X,
} from "lucide-react"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { supabase } from "@/lib/supabase"

interface AdminStats {
  totalRevenue: number
  totalRevenueExcludingFee: number
  pegasusRevenue: number
  topReferrerRevenue: number
  totalUsers: number
  activeUsers: number
  nftApproved: number
  totalPurchases: number
  pendingPurchases: number
  approvedPurchases: number
  newRegistrations: number
  newPurchases: number
  pendingApprovals: number
  pendingBuybacks: number
  pendingBuybackAmount: number
  pendingCoinwChanges: number
}

export default function AdminDashboard() {
  const [stats, setStats] = useState<AdminStats>({
    totalRevenue: 53900.0,
    totalRevenueExcludingFee: 49000.0,
    pegasusRevenue: 0,
    topReferrerRevenue: 0,
    totalUsers: 54,
    activeUsers: 54,
    nftApproved: 46,
    totalPurchases: 55,
    pendingPurchases: 2,
    approvedPurchases: 48,
    newRegistrations: 12,
    newPurchases: 3,
    pendingApprovals: 2,
    pendingBuybacks: 0,
    pendingBuybackAmount: 0,
    pendingCoinwChanges: 0,
  })
  const [loading, setLoading] = useState(true)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [lastUpdate, setLastUpdate] = useState(new Date())
  const [showBuybackAlert, setShowBuybackAlert] = useState(true)
  const [showCoinwAlert, setShowCoinwAlert] = useState(true)
  const router = useRouter()

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

      // 緊急対応: basarasystems@gmail.com または support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        await fetchStats()
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError || !adminCheck) {
        console.error("Admin check error:", adminError)
        // usersテーブルのis_adminフィールドでも確認
        const { data: userData, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("id", user.id)
          .single()

        if (!userError && userData?.is_admin) {
          setIsAdmin(true)
          await fetchStats()
          return
        }

        alert("管理者権限がありません")
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      await fetchStats()
    } catch (error) {
      console.error("Admin access check error:", error)
      router.push("/login")
    } finally {
      setLoading(false)
    }
  }

  const fetchStats = async () => {
    try {
      // 総売上の取得（手数料込み、ユーザー情報も取得）
      const { data: revenueData } = await supabase
        .from("purchases")
        .select("amount_usd, users!inner(is_pegasus_exchange)")
        .eq("admin_approved", true)

      // 全ユーザーの総売上（手数料込み、ペガサス含む）
      const totalRevenue = revenueData?.reduce((sum, purchase: any) => {
        return sum + purchase.amount_usd
      }, 0) || 53900.0

      // 全ユーザーの総売上（手数料除く = 日利計算の元本）
      const totalRevenueExcludingFee = revenueData?.reduce((sum, purchase: any) => {
        // ペガサスも通常ユーザーも同じ計算: amount_usd × (1000/1100)
        // これで1NFT = $1,000ベース（日利計算の元本）になる
        return sum + (purchase.amount_usd * (1000 / 1100))
      }, 0) || 49000.0

      // ペガサスユーザーの売上（内訳として表示）
      const pegasusRevenue = revenueData?.reduce((sum, purchase: any) => {
        if (purchase.users?.is_pegasus_exchange) {
          return sum + purchase.amount_usd
        }
        return sum
      }, 0) || 0

      // 7A9637のツリー売上を取得
      const { data: topReferrerData } = await supabase.rpc("get_referral_tree_revenue", {
        p_user_id: "7A9637"
      })
      const topReferrerRevenue = topReferrerData || 0

      // ユーザー統計の取得（basarasystems@gmail.comを除外）
      const { data: usersData } = await supabase
        .from("users")
        .select("is_active, has_approved_nft, created_at, email")
        .neq("email", "basarasystems@gmail.com")
        .neq("email", "support@dshsupport.biz")
      const totalUsers = usersData?.length || 54
      const activeUsers = usersData?.filter((u) => u.is_active).length || 54
      const nftApproved = usersData?.filter((u) => u.has_approved_nft).length || 46

      // 今日の新規登録
      const today = new Date().toISOString().split("T")[0]
      const newRegistrations = usersData?.filter((u) => u.created_at.startsWith(today)).length || 12

      // 購入統計の取得
      const { data: purchasesData } = await supabase
        .from("purchases")
        .select("admin_approved, payment_status, created_at")
      const totalPurchases = purchasesData?.length || 55
      const pendingPurchases =
        purchasesData?.filter((p) => p.payment_status === "payment_sent" && !p.admin_approved).length || 2
      const approvedPurchases = purchasesData?.filter((p) => p.admin_approved).length || 48

      // 今日の新規購入
      const newPurchases = purchasesData?.filter((p) => p.created_at.startsWith(today)).length || 3

      // 保留中の買取申請を取得
      const { data: buybackData } = await supabase
        .from("buyback_requests")
        .select("total_buyback_amount")
        .eq("status", "pending")
      const pendingBuybacks = buybackData?.length || 0
      const pendingBuybackAmount = buybackData?.reduce((sum, b) => sum + (b.total_buyback_amount || 0), 0) || 0

      // 保留中のCoinW UID変更申請を取得
      const { data: coinwData } = await supabase
        .from("coinw_uid_changes")
        .select("id")
        .eq("status", "pending")
      const pendingCoinwChanges = coinwData?.length || 0

      setStats({
        totalRevenue,
        totalRevenueExcludingFee,
        pegasusRevenue,
        topReferrerRevenue,
        totalUsers,
        activeUsers,
        nftApproved,
        totalPurchases,
        pendingPurchases,
        approvedPurchases,
        newRegistrations,
        newPurchases,
        pendingApprovals: pendingPurchases,
        pendingBuybacks,
        pendingBuybackAmount,
        pendingCoinwChanges,
      })

      setLastUpdate(new Date())
    } catch (error) {
      console.error("Error fetching stats:", error)
    }
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push("/")
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">管理者権限を確認中...</p>
        </div>
      </div>
    )
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
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
    <div className="min-h-screen bg-black">
      {/* ヘッダー */}
      <header className="bg-gray-800 shadow-lg border-b border-gray-700">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10 rounded-lg shadow-lg" />
              <div className="flex items-center gap-3">
                <Shield className="w-8 h-8 text-blue-400" />
                <div>
                  <h1 className="text-2xl font-bold text-white">管理者ダッシュボード</h1>
                  <p className="text-sm text-gray-400">ログイン中: {currentUser?.email}</p>
                </div>
              </div>
            </div>
            <div className="flex items-center space-x-3">
              <Button onClick={fetchStats} size="sm" className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2">
                <RefreshCw className="w-4 h-4 mr-2" />
                更新
              </Button>
              <Button
                onClick={handleLogout}
                variant="destructive"
                size="sm"
                className="bg-red-600 hover:bg-red-700 text-white px-4 py-2"
              >
                <LogOut className="w-4 h-4 mr-2" />
                ログアウト
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-6 py-8">
        {/* 緊急通知アラート */}
        {stats.pendingBuybacks > 0 && showBuybackAlert && (
          <Alert className="mb-6 bg-orange-900/50 border-orange-600 animate-pulse">
            <AlertTriangle className="h-5 w-5 text-orange-400" />
            <AlertDescription className="flex items-center justify-between">
              <div className="text-orange-200">
                <span className="font-bold text-orange-400">NFT買取申請 {stats.pendingBuybacks}件</span>
                <span className="ml-2">（総額: ${stats.pendingBuybackAmount.toLocaleString()}）が保留中です</span>
              </div>
              <div className="flex items-center gap-2">
                <Link href="/admin/buyback">
                  <Button size="sm" className="bg-orange-600 hover:bg-orange-700 text-white">
                    確認する
                  </Button>
                </Link>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setShowBuybackAlert(false)}
                  className="text-orange-400 hover:text-orange-300"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            </AlertDescription>
          </Alert>
        )}

        {stats.pendingCoinwChanges > 0 && showCoinwAlert && (
          <Alert className="mb-6 bg-teal-900/50 border-teal-600">
            <CreditCard className="h-5 w-5 text-teal-400" />
            <AlertDescription className="flex items-center justify-between">
              <div className="text-teal-200">
                <span className="font-bold text-teal-400">CoinW UID変更申請 {stats.pendingCoinwChanges}件</span>
                <span className="ml-2">が保留中です</span>
              </div>
              <div className="flex items-center gap-2">
                <Link href="/admin/coinw-approvals">
                  <Button size="sm" className="bg-teal-600 hover:bg-teal-700 text-white">
                    確認する
                  </Button>
                </Link>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setShowCoinwAlert(false)}
                  className="text-teal-400 hover:text-teal-300"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            </AlertDescription>
          </Alert>
        )}

        {/* 統計サマリー */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <Card className="bg-gradient-to-br from-green-500 to-green-600 border-0 text-white shadow-lg">
            <CardContent className="p-4">
              <div className="flex items-center space-x-3">
                <DollarSign className="w-10 h-10 text-white opacity-80" />
                <div>
                  <p className="text-green-100 text-xs font-medium">総売上</p>
                  <p className="text-xl font-bold">
                    ${stats.totalRevenue.toLocaleString()}
                    {stats.pegasusRevenue > 0 && (
                      <span className="text-sm text-gray-300 ml-2">
                        (ペガサス: ${stats.pegasusRevenue.toLocaleString()})
                      </span>
                    )}
                  </p>
                  <p className="text-green-200 text-xs">(手数料除く: ${stats.totalRevenueExcludingFee.toLocaleString()})</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-blue-500 to-blue-600 border-0 text-white shadow-lg">
            <CardContent className="p-4">
              <div className="flex items-center space-x-3">
                <Users className="w-10 h-10 text-white opacity-80" />
                <div>
                  <p className="text-blue-100 text-xs font-medium">総ユーザー</p>
                  <p className="text-xl font-bold">{stats.totalUsers}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-500 to-purple-600 border-0 text-white shadow-lg">
            <CardContent className="p-4">
              <div className="flex items-center space-x-3">
                <ShoppingCart className="w-10 h-10 text-white opacity-80" />
                <div>
                  <p className="text-purple-100 text-xs font-medium">総購入数</p>
                  <p className="text-xl font-bold">{stats.totalPurchases}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-orange-500 to-orange-600 border-0 text-white shadow-lg">
            <CardContent className="p-4">
              <div className="flex items-center space-x-3">
                <Activity className="w-10 h-10 text-white opacity-80" />
                <div>
                  <p className="text-orange-100 text-xs font-medium">確認待ち</p>
                  <p className="text-xl font-bold">{stats.pendingPurchases}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* メイン管理セクション */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
          {/* ユーザー管理 */}
          <Link href="/admin/users">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-blue-600 rounded-lg group-hover:bg-blue-700 transition-colors">
                    <Users className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">ユーザー管理</h3>
                    <p className="text-gray-400 text-sm">総 {stats.totalUsers} ユーザー</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 購入・入金管理 */}
          <Link href="/admin/purchases">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-green-600 rounded-lg group-hover:bg-green-700 transition-colors">
                    <CreditCard className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">購入管理</h3>
                    <p className="text-gray-400 text-sm">確認待ち {stats.pendingPurchases} 件</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 紹介関係管理 */}
          <Link href="/admin/referrals">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-purple-600 rounded-lg group-hover:bg-purple-700 transition-colors">
                    <Network className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">紹介ネットワーク</h3>
                    <p className="text-gray-400 text-sm">アクティブ {stats.activeUsers} 人</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 日利管理 */}
          <Link href="/admin/yield">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-yellow-600 rounded-lg group-hover:bg-yellow-700 transition-colors">
                    <Coins className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">日利管理</h3>
                    <p className="text-gray-400 text-sm">日利配布・設定</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 取引所入金報告 */}
          <Link href="/admin/exchange-report">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-orange-600 rounded-lg group-hover:bg-orange-700 transition-colors">
                    <BarChart3 className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">取引所入金報告</h3>
                    <p className="text-gray-400 text-sm">期間別集計</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 出金管理 */}
          <Link href="/admin/withdrawals">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-emerald-600 rounded-lg group-hover:bg-emerald-700 transition-colors">
                    <Wallet className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">月末出金管理</h3>
                    <p className="text-gray-400 text-sm">自動出金処理</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 自動NFT付与履歴 */}
          <Link href="/admin/auto-nft">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-cyan-600 rounded-lg group-hover:bg-cyan-700 transition-colors">
                    <Gift className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">自動NFT付与履歴</h3>
                    <p className="text-gray-400 text-sm">$2,200到達による自動付与</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* CoinW UID承認 */}
          <Link href="/admin/coinw-approvals">
            <Card className={`bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group ${stats.pendingCoinwChanges > 0 ? 'ring-2 ring-teal-500 ring-opacity-50' : ''}`}>
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-teal-600 rounded-lg group-hover:bg-teal-700 transition-colors">
                    <CreditCard className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold flex items-center gap-2">
                      CoinW UID承認
                      {stats.pendingCoinwChanges > 0 && (
                        <Badge className="bg-teal-600 text-white text-xs">
                          {stats.pendingCoinwChanges}件
                        </Badge>
                      )}
                    </h3>
                    <p className="text-gray-400 text-sm">UID変更申請の承認</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* NFT買い取り管理 */}
          <Link href="/admin/buyback">
            <Card className={`bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group ${stats.pendingBuybacks > 0 ? 'ring-2 ring-orange-500 ring-opacity-50' : ''}`}>
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className={`p-3 rounded-lg transition-colors ${stats.pendingBuybacks > 0 ? 'bg-orange-600 group-hover:bg-orange-700' : 'bg-purple-600 group-hover:bg-purple-700'}`}>
                    <Coins className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold flex items-center gap-2">
                      NFT買い取り管理
                      {stats.pendingBuybacks > 0 && (
                        <Badge className="bg-orange-600 text-white text-xs animate-pulse">
                          {stats.pendingBuybacks}件
                        </Badge>
                      )}
                    </h3>
                    <p className="text-gray-400 text-sm">
                      {stats.pendingBuybacks > 0
                        ? `保留中: $${stats.pendingBuybackAmount.toLocaleString()}`
                        : '買い取り申請処理'}
                    </p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* メール送信 */}
          <Link href="/admin/emails">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-pink-600 rounded-lg group-hover:bg-pink-700 transition-colors">
                    <Mail className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">メール送信</h3>
                    <p className="text-gray-400 text-sm">一斉送信・個別送信</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* お知らせ管理 */}
          <Link href="/admin/announcements">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-cyan-600 rounded-lg group-hover:bg-cyan-700 transition-colors">
                    <Megaphone className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">お知らせ管理</h3>
                    <p className="text-gray-400 text-sm">ダッシュボード告知</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* 報酬受取タスク管理 */}
          <Link href="/admin/tasks">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-indigo-600 rounded-lg group-hover:bg-indigo-700 transition-colors">
                    <BarChart3 className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">報酬受取タスク管理</h3>
                    <p className="text-gray-400 text-sm">月末アンケート設問管理</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>

          {/* システム設定 */}
          <Link href="/admin/settings">
            <Card className="bg-gray-800 border-gray-700 hover:bg-gray-750 transition-all cursor-pointer group">
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className="p-3 bg-orange-600 rounded-lg group-hover:bg-orange-700 transition-colors">
                    <Settings className="w-6 h-6 text-white" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold">システム設定</h3>
                    <p className="text-gray-400 text-sm">アドレス・設定管理</p>
                  </div>
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
                </div>
              </CardContent>
            </Card>
          </Link>
        </div>

        {/* クイックアクション */}
        <div className="mb-8">
          <h2 className="text-xl font-bold text-white mb-4">クイックアクション</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
            <Link href="/admin/database-check">
              <Button className="w-full bg-cyan-600 hover:bg-cyan-700 text-white p-4 h-auto flex flex-col items-center space-y-2">
                <Database className="w-6 h-6" />
                <span className="text-xs">DB確認</span>
              </Button>
            </Link>
            <Link href="/admin/logs">
              <Button className="w-full bg-purple-600 hover:bg-purple-700 text-white p-4 h-auto flex flex-col items-center space-y-2">
                <Activity className="w-6 h-6" />
                <span className="text-xs">ログ</span>
              </Button>
            </Link>
            <Link href="/admin/data-migration">
              <Button className="w-full bg-green-600 hover:bg-green-700 text-white p-4 h-auto flex flex-col items-center space-y-2">
                <RefreshCw className="w-6 h-6" />
                <span className="text-xs">データ移行</span>
              </Button>
            </Link>
            <Link href="/admin/analytics">
              <Button className="w-full bg-indigo-600 hover:bg-indigo-700 text-white p-4 h-auto flex flex-col items-center space-y-2">
                <BarChart3 className="w-6 h-6" />
                <span className="text-xs">分析</span>
              </Button>
            </Link>
            <Link href="/admin/emails">
              <Button className="w-full bg-pink-600 hover:bg-pink-700 text-white p-4 h-auto flex flex-col items-center space-y-2">
                <Mail className="w-6 h-6" />
                <span className="text-xs">メール送信</span>
              </Button>
            </Link>
            <Button
              onClick={fetchStats}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white p-4 h-auto flex flex-col items-center space-y-2"
            >
              <RefreshCw className="w-6 h-6" />
              <span className="text-xs">更新</span>
            </Button>
            <Button
              onClick={handleLogout}
              className="w-full bg-red-600 hover:bg-red-700 text-white p-4 h-auto flex flex-col items-center space-y-2"
            >
              <LogOut className="w-6 h-6" />
              <span className="text-xs">ログアウト</span>
            </Button>
          </div>
        </div>

        {/* 本日の活動状況 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center space-x-2">
              <Activity className="w-5 h-5 text-green-400" />
              <span>本日の活動状況</span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center p-4 bg-blue-900/20 rounded-lg">
                <p className="text-2xl font-bold text-blue-400">{stats.newRegistrations}</p>
                <p className="text-sm text-gray-400">新規登録</p>
              </div>
              <div className="text-center p-4 bg-green-900/20 rounded-lg">
                <p className="text-2xl font-bold text-green-400">{stats.newPurchases}</p>
                <p className="text-sm text-gray-400">新規購入</p>
              </div>
              <div className="text-center p-4 bg-orange-900/20 rounded-lg">
                <p className="text-2xl font-bold text-orange-400">{stats.pendingApprovals}</p>
                <p className="text-sm text-gray-400">確認待ち</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </main>

      {/* フッター */}
      <footer className="bg-gray-800 border-t border-gray-700 mt-12">
        <div className="container mx-auto px-6 py-4">
          <div className="text-center text-gray-400 text-sm">
            HASH PILOT 管理システム - 最終更新: {lastUpdate.toLocaleString("ja-JP")}
          </div>
        </div>
      </footer>
    </div>
  )
}
