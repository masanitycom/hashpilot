"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Loader2, LogOut, TrendingUp, DollarSign, Users, Gift, User, Menu, X, Coins, Settings, AlertCircle } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { ReferralTree } from "@/components/referral-tree"
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

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<UserData | null>(null)
  const [userStats, setUserStats] = useState<UserStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [authChecked, setAuthChecked] = useState(false)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [latestApprovalDate, setLatestApprovalDate] = useState<string | null>(null)
  const [showCoinwAlert, setShowCoinwAlert] = useState(false)
  const [showNftAddressAlert, setShowNftAddressAlert] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAuth()
  }, [])

  const checkAuth = async () => {
    try {
      if (!supabase) {
        console.error("Supabase client not available")
        router.push("/login")
        return
      }

      // セッション情報を強制的にリフレッシュ
      await supabase.auth.refreshSession()

      const {
        data: { session },
        error: sessionError,
      } = await supabase.auth.getSession()

      setAuthChecked(true)

      if (sessionError) {
        console.error("Session error:", sessionError)
        // セッションエラー時は完全にログアウト
        await supabase.auth.signOut()
        router.push("/login")
        return
      }

      if (!session?.user) {
        console.log("No session found, redirecting to login")
        router.push("/login")
        return
      }

      // basarasystems@gmail.com は管理画面にリダイレクト
      if (session.user.email === "basarasystems@gmail.com" || session.user.email === "support@dshsupport.biz") {
        console.log("Admin user detected, redirecting to admin dashboard")
        router.push("/admin")
        return
      }

      console.log("User authenticated:", session.user.id, "Email:", session.user.email)
      setUser(session.user)
      await fetchUserData(session.user)
    } catch (error) {
      console.error("Auth check error:", error)
      setAuthChecked(true)
      router.push("/login")
    }
  }

  const fetchUserData = async (user: any) => {
    try {
      if (!supabase) {
        throw new Error("Supabase client not available")
      }

      // まずメールアドレスでユーザーを検索（より確実）
      const { data: userRecords, error: userError } = await supabase
        .from("users")
        .select("*")
        .eq("email", user.email)

      if (userError) {
        console.error("User data error:", userError)
        setError("ユーザーデータの取得に失敗しました")
        setLoading(false)
        return
      }

      if (!userRecords || userRecords.length === 0) {
        console.log("User not found by email, checking by UUID:", user.id)
        // フォールバック: UUIDでも検索
        const { data: fallbackRecords, error: fallbackError } = await supabase
          .from("users")
          .select("*")
          .eq("id", user.id)
        
        if (fallbackError || !fallbackRecords || fallbackRecords.length === 0) {
          console.error("User not found by UUID either:", fallbackError)
          setError("ユーザーレコードが見つかりません。ブラウザのキャッシュをクリアしてから再度ログインしてください。")
          // 完全ログアウトを実行
          await supabase.auth.signOut()
          setLoading(false)
          router.push("/login")
          return
        }
        
        // UUIDで見つかった場合はそれを使用
        const userRecord = fallbackRecords[0]
        setUserData(userRecord)
        await calculateStats(userRecord)
        
        // CoinW UID未設定の場合はポップアップを表示
        if (!userRecord.coinw_uid || userRecord.coinw_uid.trim() === '') {
          setTimeout(() => {
            setShowCoinwAlert(true)
          }, 2000) // 2秒後に表示
        } else if (!userRecord.nft_receive_address || userRecord.nft_receive_address.trim() === '') {
          // CoinW UIDが設定済みで、NFT受取アドレスが未設定の場合
          setTimeout(() => {
            setShowNftAddressAlert(true)
          }, 2000) // 2秒後に表示
        }
        return
      }

      const userRecord = userRecords[0]
      
      // NFT購入チェック
      const { hasApprovedPurchase } = await checkUserNFTPurchase(userRecord.user_id)
      if (!hasApprovedPurchase) {
        console.log("User has no approved NFT purchase, redirecting to /nft")
        router.push("/nft")
        return
      }
      
      setUserData(userRecord)
      await calculateStats(userRecord)
      await fetchLatestApprovalDate(userRecord.user_id)
      
      // CoinW UID未設定の場合はポップアップを表示
      if (!userRecord.coinw_uid || userRecord.coinw_uid.trim() === '') {
        setTimeout(() => {
          setShowCoinwAlert(true)
        }, 2000) // 2秒後に表示
      } else if (!userRecord.nft_receive_address || userRecord.nft_receive_address.trim() === '') {
        // CoinW UIDが設定済みで、NFT受取アドレスが未設定の場合
        setTimeout(() => {
          setShowNftAddressAlert(true)
        }, 2000) // 2秒後に表示
      }
    } catch (error) {
      console.error("Fetch user data error:", error)
      setError("データの取得中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  const fetchLatestApprovalDate = async (userId: string) => {
    try {
      const { data: latestPurchase, error } = await supabase
        .from('purchases')
        .select('admin_approved_at')
        .eq('user_id', userId)
        .eq('admin_approved', true)
        .order('admin_approved_at', { ascending: false })
        .limit(1)
        .single()

      if (error) {
        console.error('Error fetching latest approval date:', error)
        return
      }

      if (latestPurchase?.admin_approved_at) {
        setLatestApprovalDate(latestPurchase.admin_approved_at)
      }
    } catch (error) {
      console.error('Fetch latest approval date error:', error)
    }
  }

  const calculateStats = async (userRecord: UserData) => {
    try {
      if (!supabase) {
        throw new Error("Supabase client not available")
      }

      // 個人投資額
      const totalInvestment = Math.floor((userRecord.total_purchases || 0) / 1000) * 1000

      // 直接紹介者数を取得（Level1）
      const { data: directReferrals, error: directError } = await supabase
        .from("users")
        .select("user_id, total_purchases")
        .eq("referrer_user_id", userRecord.user_id)

      if (directError) {
        throw directError
      }

      const directCount = directReferrals ? directReferrals.length : 0
      const level1Investment = directReferrals
        ? directReferrals.reduce((sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000, 0)
        : 0

      // 間接紹介者数を取得（レベル2とレベル3）
      let totalReferrals = directCount
      let totalReferralInvestment = level1Investment
      let level2Investment = 0
      let level3Investment = 0
      let level4PlusReferrals = 0
      let level4PlusInvestment = 0

      if (directReferrals && directReferrals.length > 0) {
        for (const directRef of directReferrals) {
          // レベル2
          const { data: level2Refs, error: level2Error } = await supabase
            .from("users")
            .select("user_id, total_purchases")
            .eq("referrer_user_id", directRef.user_id)

          if (!level2Error && level2Refs) {
            totalReferrals += level2Refs.length
            const level2InvestmentAmount = level2Refs.reduce(
              (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
              0,
            )
            level2Investment += level2InvestmentAmount
            totalReferralInvestment += level2InvestmentAmount

            // レベル3
            for (const level2Ref of level2Refs) {
              const { data: level3Refs, error: level3Error } = await supabase
                .from("users")
                .select("user_id, total_purchases")
                .eq("referrer_user_id", level2Ref.user_id)

              if (!level3Error && level3Refs) {
                totalReferrals += level3Refs.length
                const level3InvestmentAmount = level3Refs.reduce(
                  (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
                  0,
                )
                level3Investment += level3InvestmentAmount
                totalReferralInvestment += level3InvestmentAmount

                // レベル4以降の計算
                for (const level3Ref of level3Refs) {
                  await calculateDeepLevels(level3Ref.user_id, 4)
                }
              }
            }
          }
        }
      }

      // レベル4以降の再帰計算関数
      async function calculateDeepLevels(userId: string, currentLevel: number) {
        const { data: refs, error } = await supabase
          .from("users")
          .select("user_id, total_purchases")
          .eq("referrer_user_id", userId)

        if (!error && refs && refs.length > 0) {
          level4PlusReferrals += refs.length
          level4PlusInvestment += refs.reduce(
            (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
            0,
          )
          totalReferrals += refs.length
          totalReferralInvestment += refs.reduce(
            (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
            0,
          )

          // 更に深いレベルを計算（最大50レベルまで）
          if (currentLevel < 50) {
            for (const ref of refs) {
              await calculateDeepLevels(ref.user_id, currentLevel + 1)
            }
          }
        }
      }

      setUserStats({
        total_investment: totalInvestment,
        direct_referrals: directCount,
        total_referrals: totalReferrals,
        total_referral_investment: totalReferralInvestment,
        level4_plus_referrals: level4PlusReferrals,
        level4_plus_investment: level4PlusInvestment,
        level1_investment: level1Investment,
        level2_investment: level2Investment,
        level3_investment: level3Investment,
      })
    } catch (error) {
      console.error("Stats calculation error:", error)
      setUserStats({
        total_investment: Math.floor((userRecord.total_purchases || 0) / 1000) * 1000,
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
  }

  const handleLogout = async () => {
    try {
      if (supabase) {
        await supabase.auth.signOut()
      }
      router.push("/")
    } catch (error) {
      console.error("Logout error:", error)
      router.push("/")
    }
  }

  // 認証チェック前は何も表示しない（白い画面を防ぐ）
  if (!authChecked) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>認証確認中...</span>
        </div>
      </div>
    )
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

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardContent className="p-6">
            <div className="text-center text-red-400">
              <p className="mb-4">{error}</p>
              <Button onClick={() => window.location.reload()} variant="outline">
                再読み込み
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  const nftCount = Math.floor((userData?.total_purchases || 0) / 1000)

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

        {/* 統計カードと日利グラフ */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-6 mb-6 md:mb-8">
          {/* 統計カード */}
          <div className="lg:col-span-2 grid grid-cols-2 md:grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4">
            {/* 個人投資額 */}
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
                <p className="text-xs text-gray-500 mt-1">{nftCount} NFT保有</p>
              </CardContent>
            </Card>

            {/* 昨日の確定利益 */}
            <DailyProfitCard userId={userData?.user_id || ""} />
            
            {/* 今月の累積利益 */}
            <MonthlyProfitCard userId={userData?.user_id || ""} />

            {/* 保留中出金額 */}
            <PendingWithdrawalCard userId={userData?.user_id || ""} />

            {/* 直接紹介者数 */}
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

            {/* 総紹介者数 */}
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

            {/* 紹介者投資総額 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader className="p-3 pb-2">
                <CardTitle className="text-gray-300 text-xs md:text-sm font-medium">紹介者投資総額</CardTitle>
              </CardHeader>
              <CardContent className="p-3 pt-0">
                <div className="flex items-center space-x-1">
                  <Gift className="h-4 w-4 text-orange-400 flex-shrink-0" />
                  <span className="text-base md:text-xl lg:text-2xl font-bold text-orange-400 truncate">
                    ${userStats?.total_referral_investment.toLocaleString()}
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-1">紹介者の投資合計</p>
              </CardContent>
            </Card>
          </div>

          {/* 日利グラフ */}
          <div className="lg:col-span-1">
            <DailyProfitChart userId={userData?.user_id || ""} />
          </div>
        </div>

        {/* 利益分析セクション */}
        <div className="mb-6 md:mb-8">
          <Card className="bg-gray-800 border-gray-700 mb-4">
            <CardHeader className="pb-3">
              <CardTitle className="text-white text-lg font-semibold flex items-center gap-2">
                <TrendingUp className="h-5 w-5 text-blue-400" />
                利益分析
              </CardTitle>
              <p className="text-gray-400 text-sm">
                投資額別の利益内訳（個人投資額・Level3紹介報酬・合計）
              </p>
            </CardHeader>
          </Card>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6">
            {/* 個人投資利益 */}
            <PersonalProfitCard 
              userId={userData?.user_id || ""} 
              totalInvestment={userStats?.total_investment || 0}
            />
            
            {/* Level3紹介報酬 */}
            <ReferralProfitCard 
              userId={userData?.user_id || ""} 
              level1Investment={userStats?.level1_investment || 0}
              level2Investment={userStats?.level2_investment || 0}
              level3Investment={userStats?.level3_investment || 0}
            />
            
            {/* 合計利益 */}
            <TotalProfitCard 
              userId={userData?.user_id || ""} 
              totalInvestment={userStats?.total_investment || 0}
              level1Investment={userStats?.level1_investment || 0}
              level2Investment={userStats?.level2_investment || 0}
              level3Investment={userStats?.level3_investment || 0}
            />
          </div>
        </div>

        {/* NFTサイクルと購入履歴 */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 md:gap-6 mb-6 md:mb-8">
          {/* NFTサイクル状況 */}
          <CycleStatusCard userId={userData?.user_id || ""} />
          
          {/* 自動NFT購入履歴 */}
          <AutoPurchaseHistory userId={userData?.user_id || ""} />
        </div>

        {/* NFT買い取り申請リンク */}
        <div className="mb-6 md:mb-8">
          <Card className="bg-gray-900/50 border-gray-700">
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-start space-x-4">
                  <div className="p-3 bg-purple-600 rounded-lg">
                    <Coins className="h-6 w-6 text-white" />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white mb-2">NFT買い取り申請</h3>
                    <p className="text-gray-400 mb-4">
                      保有中のNFTを買い取り申請できます。
                    </p>
                  </div>
                </div>
                <Link href="/nft-buyback">
                  <Button className="bg-gradient-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white">
                    買い取り申請ページへ
                  </Button>
                </Link>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 紹介ツリーセクション */}
        <div className="mb-6 md:mb-8">
          <ReferralTree userId={userData?.user_id || ""} />
        </div>

        {/* レベル別投資額統計セクション */}
        <div className="mb-6 md:mb-8">
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader className="pb-4">
              <CardTitle className="text-xl font-bold text-white flex items-center space-x-2">
                <TrendingUp className="h-6 w-6 text-green-400" />
                <span>レベル別投資額統計</span>
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 md:gap-6 mb-6">
                {/* Level1投資額 */}
                <div className="bg-gradient-to-r from-green-900/20 to-emerald-900/20 border border-green-600/30 rounded-lg p-4 md:p-6">
                  <div className="flex items-center space-x-2 mb-2 md:mb-3">
                    <DollarSign className="h-6 w-6 md:h-8 md:w-8 text-green-400 flex-shrink-0" />
                    <div>
                      <h3 className="text-sm md:text-lg font-semibold text-green-400">Level1投資額</h3>
                      <p className="text-xs md:text-sm text-gray-400">報酬率: 20%</p>
                    </div>
                  </div>
                  <div className="text-xl md:text-3xl font-bold text-green-400 truncate">
                    ${userStats?.level1_investment.toLocaleString()}
                  </div>
                </div>

                {/* Level2投資額 */}
                <div className="bg-gradient-to-r from-blue-900/20 to-indigo-900/20 border border-blue-600/30 rounded-lg p-4 md:p-6">
                  <div className="flex items-center space-x-2 mb-2 md:mb-3">
                    <DollarSign className="h-6 w-6 md:h-8 md:w-8 text-blue-400 flex-shrink-0" />
                    <div>
                      <h3 className="text-sm md:text-lg font-semibold text-blue-400">Level2投資額</h3>
                      <p className="text-xs md:text-sm text-gray-400">報酬率: 10%</p>
                    </div>
                  </div>
                  <div className="text-xl md:text-3xl font-bold text-blue-400 truncate">
                    ${userStats?.level2_investment.toLocaleString()}
                  </div>
                </div>

                {/* Level3投資額 */}
                <div className="bg-gradient-to-r from-purple-900/20 to-violet-900/20 border border-purple-600/30 rounded-lg p-4 md:p-6">
                  <div className="flex items-center space-x-2 mb-2 md:mb-3">
                    <DollarSign className="h-6 w-6 md:h-8 md:w-8 text-purple-400 flex-shrink-0" />
                    <div>
                      <h3 className="text-sm md:text-lg font-semibold text-purple-400">Level3投資額</h3>
                      <p className="text-xs md:text-sm text-gray-400">報酬率: 5%</p>
                    </div>
                  </div>
                  <div className="text-xl md:text-3xl font-bold text-purple-400 truncate">
                    ${userStats?.level3_investment.toLocaleString()}
                  </div>
                </div>
              </div>

              {/* Level4以降の統計 */}
              <div className="border-t border-gray-600/30 pt-4 md:pt-6">
                <h3 className="text-base md:text-lg font-semibold text-orange-400 mb-3 md:mb-4">Level4以降の総計</h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 md:gap-6">
                  <div className="bg-gradient-to-r from-gray-800 to-gray-700 border border-orange-600/30 rounded-lg p-4 md:p-6">
                    <div className="flex items-center space-x-2 mb-2 md:mb-3">
                      <Users className="h-6 w-6 md:h-8 md:w-8 text-orange-400 flex-shrink-0" />
                      <div>
                        <h3 className="text-sm md:text-lg font-semibold text-orange-400">Level4以降の人数</h3>
                        <p className="text-xs md:text-sm text-gray-300">Level4以降の合計人数</p>
                      </div>
                    </div>
                    <div className="text-xl md:text-3xl font-bold text-orange-400">
                      {userStats?.level4_plus_referrals || 0}人
                    </div>
                  </div>

                  <div className="bg-gradient-to-r from-gray-800 to-gray-700 border border-orange-600/30 rounded-lg p-4 md:p-6">
                    <div className="flex items-center space-x-2 mb-2 md:mb-3">
                      <DollarSign className="h-6 w-6 md:h-8 md:w-8 text-orange-400 flex-shrink-0" />
                      <div>
                        <h3 className="text-sm md:text-lg font-semibold text-orange-400">Level4以降の投資額</h3>
                        <p className="text-xs md:text-sm text-gray-300">Level4以降の投資合計</p>
                      </div>
                    </div>
                    <div className="text-xl md:text-3xl font-bold text-orange-400 truncate">
                      ${userStats?.level4_plus_investment.toLocaleString()}
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* CoinW UID設定促進ポップアップ */}
      {showCoinwAlert && (
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
                  onClick={() => setShowCoinwAlert(false)}
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
                    onClick={() => setShowCoinwAlert(false)}
                    className="flex-1 bg-blue-600 hover:bg-blue-700 text-white w-full"
                  >
                    プロフィール設定へ
                  </Button>
                </Link>
                <Button
                  variant="outline"
                  onClick={() => setShowCoinwAlert(false)}
                  className="flex-1 border-gray-600 text-gray-300 hover:bg-gray-700"
                >
                  後で設定する
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* NFT受取アドレス設定促進ポップアップ */}
      {showNftAddressAlert && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <Card className="bg-gray-900 border-purple-500/50 max-w-md w-full mx-4 shadow-2xl">
            <CardHeader className="pb-4">
              <div className="flex items-center justify-between">
                <CardTitle className="text-xl font-bold text-purple-400 flex items-center space-x-2">
                  <Coins className="h-6 w-6" />
                  <span>NFT受取アドレス設定のお願い</span>
                </CardTitle>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowNftAddressAlert(false)}
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
                  NFT受取アドレスの設定が必要です
                </h3>
                <p className="text-gray-300 text-sm mb-4">
                  NFT受取アドレスの設定がないと、管理者がNFTを送付できません。プロフィール設定からNFT受取アドレスを登録してください。
                </p>
              </div>
              <div className="flex flex-col sm:flex-row gap-3">
                <Link href="/profile">
                  <Button
                    onClick={() => setShowNftAddressAlert(false)}
                    className="flex-1 bg-purple-600 hover:bg-purple-700 text-white w-full"
                  >
                    プロフィール設定へ
                  </Button>
                </Link>
                <Button
                  variant="outline"
                  onClick={() => setShowNftAddressAlert(false)}
                  className="flex-1 border-gray-600 text-gray-300 hover:bg-gray-700"
                >
                  後で設定する
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
