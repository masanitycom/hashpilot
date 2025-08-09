"use client"

import { useState, useEffect, useCallback, useMemo } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Loader2, LogOut, TrendingUp, DollarSign, Users, Gift, User, Menu, X, Coins, Settings, AlertCircle } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { ReferralTreeOptimized } from "@/components/referral-tree-optimized"
import { DailyProfitChart } from "@/components/daily-profit-chart"
import { DailyProfitCard } from "@/components/daily-profit-card"
import { LatestProfitCard } from "@/components/latest-profit-card"
import { MonthlyProfitCard } from "@/components/monthly-profit-card"
import { CycleStatusCard } from "@/components/cycle-status-card"
import { AutoPurchaseHistory } from "@/components/auto-purchase-history"
import { PendingWithdrawalCard } from "@/components/pending-withdrawal-card"
import { PersonalProfitCard } from "@/components/personal-profit-card"
import { ReferralProfitCard } from "@/components/referral-profit-card"
import { TotalProfitCard } from "@/components/total-profit-card"
import { OperationStatus } from "@/components/operation-status"
import Link from "next/link"
import { checkUserNFTPurchase, redirectIfNoNFT } from "@/lib/check-nft-purchase"

interface UserData {
  id: string
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  total_purchases: number
  referrer_user_id: string | null
  created_at: string
}

interface UserStats {
  total_investment: number
  direct_referrals: number
  total_referrals: number
  total_referral_investment: number
  level4_plus_referrals: number
  level4_plus_investment: number
  level1_investment: number
  level2_investment: number
  level3_investment: number
}

// ローディングコンポーネント
const LoadingCard = ({ title }: { title: string }) => (
  <Card className="bg-gray-800 border-gray-700 animate-pulse">
    <CardContent className="p-4">
      <div className="flex items-center space-x-3">
        <div className="w-8 h-8 bg-gray-600 rounded"></div>
        <div className="flex-1">
          <div className="h-4 bg-gray-600 rounded w-24 mb-2"></div>
          <div className="h-6 bg-gray-600 rounded w-16"></div>
        </div>
      </div>
    </CardContent>
  </Card>
)

// 段階的ローディング用コンポーネント
const StageLoader = ({ stage, totalStages }: { stage: number, totalStages: number }) => (
  <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
    <div className="text-center max-w-md mx-auto p-6">
      <div className="mb-6">
        <div className="w-16 h-16 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto"></div>
      </div>
      <h2 className="text-white text-xl font-semibold mb-2">ダッシュボードを読み込み中</h2>
      <div className="bg-gray-800 rounded-full h-2 mb-3">
        <div 
          className="bg-blue-600 h-2 rounded-full transition-all duration-500"
          style={{ width: `${(stage / totalStages) * 100}%` }}
        ></div>
      </div>
      <p className="text-gray-400 text-sm">
        {stage === 1 && "アカウント情報を確認中..."}
        {stage === 2 && "収益データを取得中..."}
        {stage === 3 && "統計情報を計算中..."}
        {stage === 4 && "画面を準備中..."}
      </p>
    </div>
  </div>
)

export default function OptimizedDashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<UserData | null>(null)
  const [userStats, setUserStats] = useState<UserStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadingStage, setLoadingStage] = useState(1)
  const [error, setError] = useState("")
  const [authChecked, setAuthChecked] = useState(false)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [latestApprovalDate, setLatestApprovalDate] = useState<string | null>(null)
  const [showCoinwAlert, setShowCoinwAlert] = useState(false)
  const [showNftAddressAlert, setShowNftAddressAlert] = useState(false)
  const [userHasCoinwUid, setUserHasCoinwUid] = useState(true)
  const [userHasNftAddress, setUserHasNftAddress] = useState(true)
  const router = useRouter()

  useEffect(() => {
    checkAuth()
  }, [])

  const checkAuth = async () => {
    try {
      setLoadingStage(1)
      
      if (!supabase) {
        console.error("Supabase client not available")
        router.push("/login")
        return
      }

      const {
        data: { session },
        error: sessionError,
      } = await supabase.auth.getSession()

      setAuthChecked(true)

      if (sessionError) {
        console.error("Session error:", sessionError)
        await supabase.auth.signOut()
        router.push("/login")
        return
      }

      if (!session?.user) {
        console.log("No session found, redirecting to login")
        await supabase.auth.signOut()
        router.push("/login")
        return
      }

      const { data: { user }, error: userError } = await supabase.auth.getUser()

      if (userError || !user) {
        console.error("User fetch error:", userError)
        await supabase.auth.signOut()
        router.push("/login")
        return
      }

      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        router.push("/admin")
        return
      }

      setUser(user)
      await fetchUserData(user.id)
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/login")
    }
  }

  const fetchUserData = async (userId: string) => {
    try {
      setLoadingStage(2)
      
      const { data: userRecords, error: userError } = await supabase
        .from("users")
        .select("*")
        .eq("id", userId)

      if (userError) {
        console.error("User data error:", userError)
        setError("ユーザーデータの取得に失敗しました")
        setLoading(false)
        return
      }

      if (!userRecords || userRecords.length === 0) {
        setError("ユーザーレコードが見つかりません")
        setLoading(false)
        return
      }

      const userRecord = userRecords[0]
      
      const { hasApprovedPurchase } = await checkUserNFTPurchase(userRecord.user_id)
      if (!hasApprovedPurchase) {
        console.log("User has no approved NFT purchase, staying on dashboard with NFT purchase prompt")
        setError("NFTの購入が完了していません。投資を開始するにはNFTの購入と承認が必要です。")
      }
      
      setUserData(userRecord)
      
      // CoinW UIDとNFTアドレスの確認
      setUserHasCoinwUid(!!userRecord.coinw_uid)
      setUserHasNftAddress(!!userRecord.nft_address)
      
      // 並列でデータ取得を開始
      await Promise.all([
        calculateStatsOptimized(userRecord),
        fetchLatestApprovalDate(userRecord.user_id)
      ])
      
    } catch (error) {
      console.error("Fetch user data error:", error)
      setError("データの取得中にエラーが発生しました")
    } finally {
      setLoadingStage(4)
      setTimeout(() => setLoading(false), 500) // スムーズな遷移
    }
  }

  // 最適化された統計計算（単一クエリ + メモリ内処理）
  const calculateStatsOptimized = useCallback(async (userRecord: UserData) => {
    try {
      setLoadingStage(3)
      
      if (!supabase) throw new Error("Supabase client not available")

      // 個人投資額
      const totalInvestment = Math.floor((userRecord.total_purchases || 0) / 1100) * 1000

      // 全ユーザーを一度に取得（大幅な最適化）
      const { data: allUsers, error: allUsersError } = await supabase
        .from("users")
        .select("user_id, total_purchases, referrer_user_id")
        .gt("total_purchases", 0)

      if (allUsersError) throw allUsersError

      // メモリ内で階層構造を構築
      const userMap = new Map(allUsers?.map(u => [u.user_id, u]) || [])
      
      // レベル別に分類
      const level1 = allUsers?.filter(u => u.referrer_user_id === userRecord.user_id) || []
      const level1Ids = new Set(level1.map(u => u.user_id))
      
      const level2 = allUsers?.filter(u => level1Ids.has(u.referrer_user_id || '')) || []
      const level2Ids = new Set(level2.map(u => u.user_id))
      
      const level3 = allUsers?.filter(u => level2Ids.has(u.referrer_user_id || '')) || []
      const level3Ids = new Set(level3.map(u => u.user_id))
      
      // レベル4以降を計算（再帰的に最大10レベルまで）
      let level4Plus: any[] = []
      let currentLevelIds = level3Ids
      
      for (let level = 4; level <= 10; level++) {
        const nextLevel = allUsers?.filter(u => currentLevelIds.has(u.referrer_user_id || '')) || []
        if (nextLevel.length === 0) break
        
        level4Plus.push(...nextLevel)
        currentLevelIds = new Set(nextLevel.map(u => u.user_id))
      }

      // 投資額計算
      const calculateInvestment = (users: any[]) => 
        users.reduce((sum, u) => sum + Math.floor((u.total_purchases || 0) / 1100) * 1000, 0)

      const level1Investment = calculateInvestment(level1)
      const level2Investment = calculateInvestment(level2)
      const level3Investment = calculateInvestment(level3)
      const level4PlusInvestment = calculateInvestment(level4Plus)

      setUserStats({
        total_investment: totalInvestment,
        direct_referrals: level1.length,
        total_referrals: level1.length + level2.length + level3.length + level4Plus.length,
        total_referral_investment: level1Investment + level2Investment + level3Investment + level4PlusInvestment,
        level4_plus_referrals: level4Plus.length,
        level4_plus_investment: level4PlusInvestment,
        level1_investment: level1Investment,
        level2_investment: level2Investment,
        level3_investment: level3Investment,
      })

    } catch (error) {
      console.error("Stats calculation error:", error)
      setUserStats({
        total_investment: Math.floor((userRecord.total_purchases || 0) / 1100) * 1000,
        direct_referrals: 0,
        total_referrals: 0,
        total_referral_investment: 0,
        level4_plus_referrals: 0,
        level4_plus_investment: 0,
        level1_investment: 0,
        level2_investment: 0,
        level3_investment: 0,
      })
    }
  }, [])

  const fetchLatestApprovalDate = async (userId: string) => {
    try {
      const { data: latestPurchase } = await supabase
        .from("purchases")
        .select("admin_approved_at")
        .eq("user_id", userId)
        .eq("admin_approved", true)
        .order("admin_approved_at", { ascending: false })
        .limit(1)
        .single()

      if (latestPurchase?.admin_approved_at) {
        setLatestApprovalDate(latestPurchase.admin_approved_at)
      }
    } catch (error) {
      console.error('Fetch latest approval date error:', error)
    }
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push("/")
  }

  const handleCoinwAlertClose = () => {
    setShowCoinwAlert(false)
    localStorage.setItem('coinw_alert_dismissed', 'true')
  }

  const handleNftAddressAlertClose = () => {
    setShowNftAddressAlert(false)
    localStorage.setItem('nft_address_alert_dismissed', 'true')
  }

  // アラート表示の判定
  useEffect(() => {
    if (userData && !loading) {
      const coinwDismissed = localStorage.getItem('coinw_alert_dismissed') === 'true'
      const nftAddressDismissed = localStorage.getItem('nft_address_alert_dismissed') === 'true'
      
      if (!userHasCoinwUid && !coinwDismissed) {
        setShowCoinwAlert(true)
      } else if (!userHasNftAddress && !nftAddressDismissed) {
        setShowNftAddressAlert(true)
      }
    }
  }, [userData, loading, userHasCoinwUid, userHasNftAddress])

  // 段階的ローディング表示
  if (loading) {
    return <StageLoader stage={loadingStage} totalStages={4} />
  }

  if (error && !userData) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400">エラー</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-white">{error}</p>
            <div className="flex space-x-2">
              <Button onClick={() => window.location.reload()} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white">
                再読み込み
              </Button>
              <Link href="/nft">
                <Button variant="outline" className="flex-1 text-white border-white hover:bg-gray-700">
                  NFT購入
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  const nftCount = Math.floor((userData?.total_purchases || 0) / 1100)

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700 sticky top-0 z-50">
        <div className="container mx-auto px-4 py-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <img 
                src="/images/hash-pilot-logo.png" 
                alt="HashPilot" 
                className="h-8 md:h-10 lg:h-12 w-auto object-contain aspect-[3/1] rounded-lg shadow-lg" 
              />
              <div className="hidden sm:block">
                <p className="text-sm text-gray-400">ダッシュボード</p>
              </div>
            </div>

            {/* デスクトップメニュー */}
            <div className="hidden md:flex items-center space-x-3">
              <Link href="https://lin.ee/GHcn4pN" target="_blank" rel="noopener noreferrer">
                <Button
                  variant="outline"
                  size="sm"
                  className="border-green-500 text-green-400 hover:bg-green-600 bg-transparent"
                >
                  📱 公式LINE
                </Button>
              </Link>
              <Link href="/nft">
                <Button
                  variant="outline"
                  size="sm"
                  className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                >
                  NFT購入
                </Button>
              </Link>
              <Link href="/withdrawal">
                <Button
                  variant="outline"
                  size="sm"
                  className="border-purple-600 text-purple-400 hover:bg-purple-700 bg-transparent"
                >
                  出金状況
                </Button>
              </Link>
              <Button onClick={handleLogout} variant="ghost" size="sm" className="text-gray-300 hover:text-white">
                <LogOut className="h-4 w-4 mr-2" />
                ログアウト
              </Button>
            </div>

            {/* モバイルメニューボタン */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="md:hidden p-2 text-gray-400 hover:text-white transition-colors"
            >
              {mobileMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
            </button>
          </div>

          {/* モバイルメニュー */}
          {mobileMenuOpen && (
            <div className="md:hidden mt-4 pb-4 space-y-2">
              <Link href="https://lin.ee/GHcn4pN" target="_blank" rel="noopener noreferrer">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-green-500 text-green-400 hover:bg-green-600 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  📱 公式LINE
                </Button>
              </Link>
              <Link href="/nft">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-gray-600 text-white hover:bg-gray-700 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  NFT購入
                </Button>
              </Link>
              <Link href="/withdrawal">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-purple-600 text-purple-400 hover:bg-purple-700 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  出金状況
                </Button>
              </Link>
              <Link href="/profile">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-blue-600 text-blue-400 hover:bg-blue-700 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  <User className="h-4 w-4 mr-2" />
                  プロフィール
                </Button>
              </Link>
              <Button 
                onClick={handleLogout} 
                variant="ghost" 
                size="sm" 
                className="w-full text-red-400 hover:text-red-300 hover:bg-red-900/20 justify-start"
              >
                <LogOut className="h-4 w-4 mr-2" />
                ログアウト
              </Button>
            </div>
          )}
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* エラーメッセージ */}
        {error && (
          <div className="mb-6">
            <Card className="bg-yellow-900/20 border-yellow-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <AlertCircle className="h-5 w-5 text-yellow-400" />
                  <p className="text-yellow-200 text-sm">{error}</p>
                  <Link href="/nft">
                    <Button size="sm" className="ml-auto bg-blue-600 hover:bg-blue-700">
                      NFT購入
                    </Button>
                  </Link>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* ヒーローセクション */}
        <div className="mb-6 bg-gradient-to-r from-blue-900/20 to-purple-900/20 border border-blue-700/50 rounded-lg p-4 md:p-6">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div className="flex-1">
              <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4 mb-2">
                <h2 className="text-xl md:text-2xl font-bold text-white">こんにちは、{userData?.user_id}さん</h2>
                <div className="flex flex-wrap items-center gap-2">
                  <Badge className="bg-blue-600 text-white text-xs">ID: {userData?.user_id}</Badge>
                  {userData?.coinw_uid && <Badge className="bg-green-600 text-white text-xs">CoinW認証済み</Badge>}
                </div>
              </div>
              <p className="text-gray-400 text-sm md:text-base break-all">{userData?.email}</p>
              
              {/* 運用ステータス */}
              <div className="mt-4">
                <OperationStatus approvalDate={latestApprovalDate} />
              </div>
            </div>
            <div className="hidden md:block">
              <Link href="/profile">
                <Button className="bg-blue-600 hover:bg-blue-700 text-white">
                  <User className="h-4 w-4 mr-2" />
                  プロフィール設定
                </Button>
              </Link>
            </div>
          </div>
        </div>

        {/* 最重要カード（即座に表示） */}
        <div className="grid grid-cols-2 md:grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4 mb-6">
          <TotalProfitCard userId={userData?.user_id || ""} />
          <MonthlyProfitCard userId={userData?.user_id || ""} />
          <DailyProfitCard userId={userData?.user_id || ""} />
          <PendingWithdrawalCard userId={userData?.user_id || ""} />
        </div>

        {/* 遅延読み込みコンテンツ */}
        <LazyLoadedContent userData={userData} userStats={userStats} />
        
        {/* アラート類 */}
        {showCoinwAlert && (
          <CoinWAlert onClose={handleCoinwAlertClose} />
        )}
        
        {showNftAddressAlert && (
          <NFTAddressAlert onClose={handleNftAddressAlertClose} />
        )}
      </div>
    </div>
  )
}

// 遅延読み込みコンテンツ  
const LazyLoadedContent = ({ userData, userStats }: { userData: UserData | null, userStats: UserStats | null }) => {
  const [showContent, setShowContent] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setShowContent(true), 200)
    return () => clearTimeout(timer)
  }, [])

  if (!showContent) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-4">
          <LoadingCard title="個人投資額" />
          <LoadingCard title="直接紹介" />
          <LoadingCard title="総紹介者" />
          <LoadingCard title="紹介投資額" />
        </div>
        <LoadingCard title="日利グラフ" />
        <LoadingCard title="組織図" />
      </div>
    )
  }

  return (
    <>
      {/* 統計カード */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-4 mb-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader className="p-3 pb-2">
            <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">個人投資額</CardTitle>
          </CardHeader>
          <CardContent className="p-3 pt-0">
            <div className="flex items-center space-x-1">
              <DollarSign className="h-4 w-4 text-green-400 flex-shrink-0" />
              <span className="text-base md:text-xl lg:text-2xl font-bold text-green-400 truncate">
                ${userStats?.total_investment.toLocaleString()}
              </span>
            </div>
            <p className="text-xs text-gray-500 mt-1">{Math.floor((userData?.total_purchases || 0) / 1100)} NFT保有</p>
          </CardContent>
        </Card>

        <Card className="bg-gray-800 border-gray-700">
          <CardHeader className="p-3 pb-2">
            <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">直接紹介</CardTitle>
          </CardHeader>
          <CardContent className="p-3 pt-0">
            <div className="flex items-center space-x-1">
              <Users className="h-4 w-4 text-blue-400 flex-shrink-0" />
              <span className="text-base md:text-xl lg:text-2xl font-bold text-blue-400">{userStats?.direct_referrals || 0}</span>
            </div>
            <p className="text-xs text-gray-500 mt-1">直接紹介した人数</p>
          </CardContent>
        </Card>

        <Card className="bg-gray-800 border-gray-700">
          <CardHeader className="p-3 pb-2">
            <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">総紹介者</CardTitle>
          </CardHeader>
          <CardContent className="p-3 pt-0">
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-4 w-4 text-purple-400 flex-shrink-0" />
              <span className="text-base md:text-xl lg:text-2xl font-bold text-purple-400">{userStats?.total_referrals || 0}</span>
            </div>
            <p className="text-xs text-gray-500 mt-1">全レベル合計</p>
          </CardContent>
        </Card>

        <Card className="bg-gray-800 border-gray-700">
          <CardHeader className="p-3 pb-2">
            <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">紹介投資額</CardTitle>
          </CardHeader>
          <CardContent className="p-3 pt-0">
            <div className="flex items-center space-x-1">
              <Gift className="h-4 w-4 text-orange-400 flex-shrink-0" />
              <span className="text-base md:text-xl lg:text-2xl font-bold text-orange-400 truncate">
                ${userStats?.total_referral_investment.toLocaleString()}
              </span>
            </div>
            <p className="text-xs text-gray-500 mt-1">報酬の基準額</p>
          </CardContent>
        </Card>
      </div>

      {/* 利益チャート */}
      <div className="mb-6">
        <DailyProfitChart userId={userData?.user_id || ""} />
      </div>

      {/* 残りのコンテンツ（さらに遅延） */}
      <DelayedContent userData={userData} userStats={userStats} />
    </>
  )
}

// さらに遅延したコンテンツ
const DelayedContent = ({ userData, userStats }: { userData: UserData | null, userStats: UserStats | null }) => {
  const [showDelayedContent, setShowDelayedContent] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setShowDelayedContent(true), 1000)
    return () => clearTimeout(timer)
  }, [])

  if (!showDelayedContent) {
    return (
      <div className="space-y-6">
        <LoadingCard title="組織図を準備中..." />
      </div>
    )
  }

  return (
    <>
      {/* 運用状況セクション */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
        <CycleStatusCard userId={userData?.user_id || ""} />
        <PersonalProfitCard userId={userData?.user_id || ""} />
        <ReferralProfitCard userId={userData?.user_id || ""} />
      </div>

      {/* 組織図 */}
      <div className="mb-6">
        <ReferralTreeOptimized userId={userData?.user_id || ""} />
      </div>

      {/* NFT買い取り申請リンク */}
      <div className="mb-6">
        <Card className="bg-gray-900/50 border-gray-700">
          <CardContent className="p-4 md:p-6">
            <div className="flex items-center justify-between flex-wrap gap-3 md:gap-4">
              <div className="flex items-center space-x-3 md:space-x-4">
                <div className="p-2 md:p-3 bg-purple-600 rounded-lg flex-shrink-0">
                  <Coins className="h-5 w-5 md:h-6 md:w-6 text-white" />
                </div>
                <div>
                  <h3 className="text-lg md:text-xl font-bold text-white">NFT買い取り申請</h3>
                </div>
              </div>
              <Link href="/nft-buyback">
                <Button className="bg-gradient-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white text-sm md:text-base px-4 md:px-6 py-2 md:py-3">
                  申請ページへ
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* 自動NFT購入履歴 */}
      <AutoPurchaseHistory userId={userData?.user_id || ""} />

      {/* レベル別統計 */}
      <LevelStats userStats={userStats} />
    </>
  )
}

// レベル別統計コンポーネント
const LevelStats = ({ userStats }: { userStats: UserStats | null }) => (
  <Card className="bg-gray-900/50 border-gray-700">
    <CardHeader>
      <CardTitle className="text-white text-lg">レベル別投資額統計</CardTitle>
    </CardHeader>
    <CardContent>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gradient-to-r from-blue-900/20 to-blue-900/10 border border-blue-600/30 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <DollarSign className="h-6 w-6 text-blue-400 flex-shrink-0" />
            <div>
              <h3 className="text-sm font-semibold text-blue-400">Level1投資額</h3>
              <p className="text-xs text-gray-400">報酬率: 20%</p>
            </div>
          </div>
          <div className="text-xl font-bold text-blue-400 truncate">
            ${userStats?.level1_investment.toLocaleString()}
          </div>
        </div>

        <div className="bg-gradient-to-r from-green-900/20 to-green-900/10 border border-green-600/30 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <DollarSign className="h-6 w-6 text-green-400 flex-shrink-0" />
            <div>
              <h3 className="text-sm font-semibold text-green-400">Level2投資額</h3>
              <p className="text-xs text-gray-400">報酬率: 10%</p>
            </div>
          </div>
          <div className="text-xl font-bold text-green-400 truncate">
            ${userStats?.level2_investment.toLocaleString()}
          </div>
        </div>

        <div className="bg-gradient-to-r from-purple-900/20 to-purple-900/10 border border-purple-600/30 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <DollarSign className="h-6 w-6 text-purple-400 flex-shrink-0" />
            <div>
              <h3 className="text-sm font-semibold text-purple-400">Level3投資額</h3>
              <p className="text-xs text-gray-400">報酬率: 5%</p>
            </div>
          </div>
          <div className="text-xl font-bold text-purple-400 truncate">
            ${userStats?.level3_investment.toLocaleString()}
          </div>
        </div>
      </div>
    </CardContent>
  </Card>
)

// アラートコンポーネント
const CoinWAlert = ({ onClose }: { onClose: () => void }) => (
  <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
    <Card className="bg-gray-900 border-blue-500/50 max-w-md w-full mx-4 shadow-2xl">
      <CardHeader className="pb-4">
        <div className="flex items-center justify-between">
          <CardTitle className="text-xl font-bold text-blue-400 flex items-center space-x-2">
            <AlertCircle className="h-6 w-6" />
            <span>CoinW UID設定のお願い</span>
          </CardTitle>
          <Button
            variant="ghost"
            size="sm"
            onClick={onClose}
            className="text-gray-400 hover:text-white"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-center">
          <div className="bg-yellow-500/20 rounded-full p-3 w-16 h-16 mx-auto mb-4 flex items-center justify-center">
            <Settings className="h-8 w-8 text-yellow-400" />
          </div>
          <h3 className="text-lg font-semibold text-white mb-2">
            CoinW UIDの設定が必要です
          </h3>
          <p className="text-gray-300 text-sm mb-4">
            CoinW UIDの設定がないと、報酬の送金ができません。プロフィール設定からCoinW UIDを登録してください。
          </p>
        </div>
        <div className="flex flex-col sm:flex-row gap-3">
          <Link href="/profile">
            <Button
              onClick={onClose}
              className="flex-1 bg-blue-600 hover:bg-blue-700 text-white w-full"
            >
              プロフィール設定へ
            </Button>
          </Link>
          <Button
            variant="outline"
            onClick={onClose}
            className="flex-1 border-gray-400 text-gray-200 hover:bg-gray-600 hover:text-white bg-gray-700/50"
          >
            後で設定する
          </Button>
        </div>
      </CardContent>
    </Card>
  </div>
)

const NFTAddressAlert = ({ onClose }: { onClose: () => void }) => (
  <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
    <Card className="bg-gray-900 border-purple-500/50 max-w-md w-full mx-4 shadow-2xl">
      <CardHeader className="pb-4">
        <div className="flex items-center justify-between">
          <CardTitle className="text-xl font-bold text-purple-400 flex items-center space-x-2">
            <AlertCircle className="h-6 w-6" />
            <span>NFTアドレス設定のお願い</span>
          </CardTitle>
          <Button
            variant="ghost"
            size="sm"
            onClick={onClose}
            className="text-gray-400 hover:text-white"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-center">
          <div className="bg-purple-500/20 rounded-full p-3 w-16 h-16 mx-auto mb-4 flex items-center justify-center">
            <Coins className="h-8 w-8 text-purple-400" />
          </div>
          <h3 className="text-lg font-semibold text-white mb-2">
            NFTアドレスの設定が必要です
          </h3>
          <p className="text-gray-300 text-sm mb-4">
            NFTを受け取るためのウォレットアドレスを設定してください。プロフィール設定から登録できます。
          </p>
        </div>
        <div className="flex flex-col sm:flex-row gap-3">
          <Link href="/profile">
            <Button
              onClick={onClose}
              className="flex-1 bg-purple-600 hover:bg-purple-700 text-white w-full"
            >
              プロフィール設定へ
            </Button>
          </Link>
          <Button
            variant="outline"
            onClick={onClose}
            className="flex-1 border-gray-400 text-gray-200 hover:bg-gray-600 hover:text-white bg-gray-700/50"
          >
            後で設定する
          </Button>
        </div>
      </CardContent>
    </Card>
  </div>
)