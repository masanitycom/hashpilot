"use client"

import { useState, useEffect, useCallback, useMemo } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Loader2, LogOut, TrendingUp, DollarSign, Users, Gift, User, Menu, X, Coins, Settings, AlertCircle, Mail } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { UnifiedReferralCalculator } from "@/lib/unified-referral-calculator"
import { ReferralTreeOptimized } from "@/components/referral-tree-optimized"
import { DailyProfitChart } from "@/components/daily-profit-chart"
import { DailyProfitCard } from "@/components/daily-profit-card"
import { LatestProfitCard } from "@/components/latest-profit-card"
import { CycleStatusCard } from "@/components/cycle-status-card"
import { AutoPurchaseHistory } from "@/components/auto-purchase-history"
import { PendingWithdrawalCard } from "@/components/pending-withdrawal-card"
import { PersonalProfitCard } from "@/components/personal-profit-card"
import { ReferralProfitCard } from "@/components/referral-profit-card"
import { MonthlyCumulativeProfitCard } from "@/components/monthly-cumulative-profit-card"
import { LastMonthProfitCard } from "@/components/last-month-profit-card"
import { OperationStatus } from "@/components/operation-status"
import { AnnouncementsBanner } from "@/components/announcements-banner"
import { DormantUserBanner } from "@/components/dormant-user-banner"
import { RewardTaskPopup } from "@/components/reward-task-popup"
import { CoinwUidPopup } from "@/components/coinw-uid-popup"
import { TermsAgreementPopup } from "@/components/terms-agreement-popup"
import { NftListCard } from "@/components/nft-list-card"
import Link from "next/link"
import { checkUserNFTPurchase, redirectIfNoNFT } from "@/lib/check-nft-purchase"

interface UserData {
  id: string
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  nft_receive_address: string | null
  total_purchases: number
  referrer_user_id: string | null
  created_at: string
  operation_start_date: string | null
  is_operation_only: boolean
  is_active_investor: boolean
  has_approved_nft: boolean
  terms_agreed_at: string | null
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
  const [currentNftCount, setCurrentNftCount] = useState<number>(0)
  const [currentInvestment, setCurrentInvestment] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [loadingStage, setLoadingStage] = useState(1)
  const [error, setError] = useState("")
  const [authChecked, setAuthChecked] = useState(false)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [latestApprovalDate, setLatestApprovalDate] = useState<string | null>(null)
  const [showNftAddressAlert, setShowNftAddressAlert] = useState(false)
  const [userHasNftAddress, setUserHasNftAddress] = useState(true)
  const [showRewardTaskPopup, setShowRewardTaskPopup] = useState(false)
  const [showReferralRewardTaskPopup, setShowReferralRewardTaskPopup] = useState(false)
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

      // NFTアドレスの確認（空文字も false として扱う）
      setUserHasNftAddress(!!userRecord.nft_receive_address && typeof userRecord.nft_receive_address === 'string' && userRecord.nft_receive_address.trim() !== '')
      
      // 並列でデータ取得を開始
      await Promise.all([
        calculateStatsOptimized(userRecord),
        fetchLatestApprovalDate(userRecord.user_id),
        fetchCurrentNftCount(userRecord.user_id),
        checkPendingRewardTask(userRecord.user_id),
        checkPendingReferralRewardTask(userRecord.user_id)
      ])
      
    } catch (error) {
      console.error("Fetch user data error:", error)
      setError("データの取得中にエラーが発生しました")
    } finally {
      setLoadingStage(4)
      setTimeout(() => setLoading(false), 500) // スムーズな遷移
    }
  }

  // 統一システムによる統計計算
  const calculateStatsOptimized = useCallback(async (userRecord: UserData) => {
    try {
      console.log('[Dashboard] calculateStatsOptimized started for user:', userRecord.user_id)
      setLoadingStage(3)

      if (!supabase) throw new Error("Supabase client not available")

      // 個人投資額
      const totalInvestment = Math.floor((userRecord.total_purchases || 0) / 1100) * 1000
      console.log('[Dashboard] totalInvestment calculated:', totalInvestment)

      // 統一計算システムを使用
      const calculator = new UnifiedReferralCalculator()
      console.log('[Dashboard] Starting unified stats calculation...')
      const unifiedStats = await calculator.calculateCompleteStats(userRecord.user_id)
      console.log('[Dashboard] Unified stats completed:', unifiedStats)
      
      // ダッシュボード用にフォーマット
      setUserStats({
        total_investment: totalInvestment,
        direct_referrals: unifiedStats.directReferrals,
        total_referrals: unifiedStats.purchasedReferrals, // 購入者のみ
        total_referral_investment: unifiedStats.totalInvestment, // 運用額
        level4_plus_referrals: unifiedStats.levelBreakdown
          .filter(l => l.level >= 4)
          .reduce((sum, l) => sum + l.purchasedCount, 0),
        level4_plus_investment: unifiedStats.levelBreakdown
          .filter(l => l.level >= 4)
          .reduce((sum, l) => sum + l.investment, 0),
        level1_investment: unifiedStats.levelBreakdown
          .find(l => l.level === 1)?.investment || 0,
        level2_investment: unifiedStats.levelBreakdown
          .find(l => l.level === 2)?.investment || 0,
        level3_investment: unifiedStats.levelBreakdown
          .find(l => l.level === 3)?.investment || 0,
      })
      
      return // 早期リターン（以下の古いコードは実行されない）

      // 全ユーザーを一度に取得（大幅な最適化）
      const { data: allUsers, error: allUsersError } = await supabase
        .from("users")
        .select("user_id, total_purchases, referrer_user_id")
        .gt("total_purchases", 0)

      if (allUsersError) {
        console.error("All users fetch error:", allUsersError)
        throw allUsersError
      }

      if (!allUsers || allUsers.length === 0) {
        setUserStats({
          total_investment: totalInvestment,
          direct_referrals: 0,
          total_referrals: 0,
          total_referral_investment: 0,
          level4_plus_referrals: 0,
          level4_plus_investment: 0,
          level1_investment: 0,
          level2_investment: 0,
          level3_investment: 0,
        })
        return
      }

      // メモリ内で階層構造を構築
      const userMap = new Map(allUsers.map(u => [u.user_id, u]))
      
      // レベル別に分類
      const level1 = allUsers.filter(u => u.referrer_user_id === userRecord.user_id)
      const level1Ids = new Set(level1.map(u => u.user_id))
      
      const level2 = allUsers.filter(u => level1Ids.has(u.referrer_user_id || ''))
      const level2Ids = new Set(level2.map(u => u.user_id))
      
      const level3 = allUsers.filter(u => level2Ids.has(u.referrer_user_id || ''))
      const level3Ids = new Set(level3.map(u => u.user_id))
      
      // レベル4以降を計算（無限レベルまで - 実際の紹介ツリーの深さまで）
      let level4Plus: any[] = []
      let currentLevelIds = new Set(level3Ids) // コピーを作成
      let allProcessedIds = new Set([...level1Ids, ...level2Ids, ...level3Ids])
      
      let level = 4
      while (currentLevelIds.size > 0 && level <= 500) { // 無限ループ防止のため最大500レベル
        const nextLevel = allUsers.filter(u => 
          currentLevelIds.has(u.referrer_user_id || '') && 
          !allProcessedIds.has(u.user_id)
        )
        if (nextLevel.length === 0) break
        
        level4Plus.push(...nextLevel)
        const newIds = new Set(nextLevel.map(u => u.user_id))
        newIds.forEach(id => allProcessedIds.add(id))
        currentLevelIds = newIds
        level++
      }

      // 投資額計算
      const calculateInvestment = (users: any[]) => 
        users.reduce((sum, u) => sum + Math.floor((u.total_purchases || 0) / 1100) * 1000, 0)

      const level1Investment = calculateInvestment(level1)
      const level2Investment = calculateInvestment(level2)
      const level3Investment = calculateInvestment(level3)
      const level4PlusInvestment = calculateInvestment(level4Plus)

      // この部分は統一システムで置き換え済み（上記参照）

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

  const fetchCurrentNftCount = async (userId: string) => {
    try {
      const { data: cycleData, error } = await supabase
        .from("affiliate_cycle")
        .select("total_nft_count, manual_nft_count, auto_nft_count")
        .eq("user_id", userId)
        .single()

      if (error) {
        console.error("Error fetching NFT count:", error)
        return
      }

      const totalNfts = cycleData?.total_nft_count || 0
      const manualNfts = cycleData?.manual_nft_count || 0
      const autoNfts = cycleData?.auto_nft_count || 0

      // 現在の投資額 = 全NFT × 1000 (運用額は手動も自動も同じ$1,000)
      // ※ 買い取り時は自動NFTは$500だが、運用額は$1,000
      const investment = totalNfts * 1000

      setCurrentNftCount(totalNfts)
      setCurrentInvestment(investment)
    } catch (error) {
      console.error("Error fetching current NFT count:", error)
    }
  }

  const checkPendingRewardTask = async (userId: string) => {
    try {
      console.log('[RewardTask] Checking for userId:', userId)

      const { data, error } = await supabase
        .from("monthly_withdrawals")
        .select("id, task_completed, status, withdrawal_month")
        .eq("user_id", userId)
        .eq("status", "on_hold")
        .eq("task_completed", false)

      console.log('[RewardTask] Query result:', { data, error })

      if (error && error.code !== 'PGRST116') {
        console.error("[RewardTask] Error checking pending reward task:", error)
        return
      }

      if (data && data.length > 0) {
        // 現在月または前月のみポップアップ表示（古い月のループ防止）
        const now = new Date()
        const currentYear = now.getFullYear()
        const currentMonth = now.getMonth() + 1
        const prevMonth = currentMonth === 1 ? 12 : currentMonth - 1
        const prevYear = currentMonth === 1 ? currentYear - 1 : currentYear

        const hasRecentTask = data.some((w: any) => {
          const monthStr = (w.withdrawal_month || '').substring(0, 7)
          const [yearStr, monthNumStr] = monthStr.split('-')
          const wYear = parseInt(yearStr, 10)
          const wMonth = parseInt(monthNumStr, 10)
          return (wYear === currentYear && wMonth === currentMonth) ||
                 (wYear === prevYear && wMonth === prevMonth)
        })

        if (hasRecentTask) {
          console.log("[RewardTask] Recent pending reward task found, showing popup")
          setShowRewardTaskPopup(true)
        } else {
          console.log("[RewardTask] Only old month tasks found, skipping popup")
        }
      } else {
        console.log("[RewardTask] No pending tasks found")
      }
    } catch (error) {
      console.error("[RewardTask] Error in checkPendingRewardTask:", error)
    }
  }

  const checkPendingReferralRewardTask = async (userId: string) => {
    try {
      console.log('[ReferralRewardTask] Checking for userId:', userId)

      const { data, error } = await supabase.rpc('get_referral_reward_task_status', {
        p_user_id: userId
      })

      if (error) {
        console.error("[ReferralRewardTask] Error fetching task status:", error)
        return
      }

      if (data && data.length > 0 && data[0].has_pending_task) {
        // 現在月または前月のみポップアップ表示（古い月のループ防止）
        const now = new Date()
        const currentYear = now.getFullYear()
        const currentMonth = now.getMonth() + 1
        const prevMonth = currentMonth === 1 ? 12 : currentMonth - 1
        const prevYear = currentMonth === 1 ? currentYear - 1 : currentYear

        const taskYear = data[0].year
        const taskMonth = data[0].month
        const isRecent = (taskYear === currentYear && taskMonth === currentMonth) ||
                         (taskYear === prevYear && taskMonth === prevMonth)

        if (isRecent) {
          console.log("[ReferralRewardTask] Recent pending task found:", data[0])
          setShowReferralRewardTaskPopup(true)
        } else {
          console.log("[ReferralRewardTask] Old month task found, skipping popup:", data[0])
        }
      } else {
        console.log("[ReferralRewardTask] No pending tasks found")
      }
    } catch (error) {
      console.error("[ReferralRewardTask] Error in checkPendingReferralRewardTask:", error)
    }
  }

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

  const handleNftAddressAlertClose = () => {
    setShowNftAddressAlert(false)
  }

  // アラート表示の判定（NFTアドレスのみ - CoinW UIDは新しいポップアップシステムで管理）
  useEffect(() => {
    if (userData && !loading) {
      // NFTアドレスが未設定の場合のみアラート表示
      if (!userHasNftAddress) {
        setShowNftAddressAlert(true)
      } else {
        setShowNftAddressAlert(false)
      }
    }
  }, [userData, loading, userHasNftAddress])

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
              <Button onClick={() => typeof window !== 'undefined' && window.location.reload()} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white">
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
              <Link href="https://t.me/+49d-9_1CXXc4MjQ1" target="_blank" rel="noopener noreferrer">
                <Button
                  variant="outline"
                  size="sm"
                  className="border-blue-500 text-blue-400 hover:bg-blue-600 bg-transparent"
                >
                  📱 公式Telegram
                </Button>
              </Link>
              <Link href="https://lin.ee/nacHdfq" target="_blank" rel="noopener noreferrer">
                <Button
                  variant="outline"
                  size="sm"
                  className="border-green-500 text-green-400 hover:bg-green-600 bg-transparent"
                >
                  個別サポート
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
              <Link href="https://t.me/+49d-9_1CXXc4MjQ1" target="_blank" rel="noopener noreferrer">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-blue-500 text-blue-400 hover:bg-blue-600 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  📱 公式Telegram
                </Button>
              </Link>
              <Link href="https://lin.ee/nacHdfq" target="_blank" rel="noopener noreferrer">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-green-500 text-green-400 hover:bg-green-600 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  個別サポート（LINE）
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
              <Link href="/inbox">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full border-gray-600 text-gray-300 hover:bg-gray-700 bg-transparent justify-start"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  <Mail className="h-4 w-4 mr-2" />
                  受信箱
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
        {/* Telegram登録促進バナー */}
        <div className="mb-6">
          <Card className="bg-gradient-to-r from-blue-700 to-cyan-600 border-blue-500 shadow-xl">
            <CardContent className="p-4">
              <div className="flex flex-col sm:flex-row items-center gap-4">
                <div className="flex-1 text-center sm:text-left">
                  <h3 className="text-lg sm:text-xl font-bold text-white mb-2 leading-relaxed">
                    📱 Hash Pilot公式<br className="sm:hidden" />Telegramが開設されました！
                  </h3>
                  <p className="text-white text-sm sm:text-base font-semibold">
                    各種お得なキャンペーン情報、<br className="sm:hidden" />イベント情報等を発信します
                  </p>
                </div>
                <div className="flex flex-col gap-2 w-full sm:w-auto">
                  <a
                    href="https://t.me/+49d-9_1CXXc4MjQ1"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="w-full sm:w-auto"
                  >
                    <Button className="w-full sm:w-auto bg-white hover:bg-gray-100 text-blue-700 font-bold px-6 py-3 shadow-lg animate-pulse">
                      <svg className="w-5 h-5 mr-2" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/>
                      </svg>
                      公式Telegramに登録する
                    </Button>
                  </a>
                  <a
                    href="https://lin.ee/nacHdfq"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="w-full sm:w-auto"
                  >
                    <Button className="w-full sm:w-auto bg-green-600 hover:bg-green-700 text-white font-medium px-6 py-2 border-2 border-green-400">
                      <svg className="w-4 h-4 mr-2" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63h2.386c.346 0 .627.285.627.63 0 .349-.281.63-.63.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63.346 0 .628.285.628.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.282.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314"/>
                      </svg>
                      個別サポートLINE
                    </Button>
                  </a>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

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
                  {userData?.nft_receive_address && <Badge className="bg-purple-600 text-white text-xs">NFT受取アドレス認証済み</Badge>}
                </div>
              </div>
              <p className="text-gray-400 text-sm md:text-base break-all">{userData?.email}</p>
              
              {/* 運用ステータス */}
              <div className="mt-4">
                <OperationStatus
                  operationStartDate={userData?.operation_start_date}
                  approvalDate={latestApprovalDate}
                />
              </div>
            </div>
            <div className="hidden md:flex md:space-x-2">
              <Link href="/inbox">
                <Button variant="outline" className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600">
                  <Mail className="h-4 w-4 mr-2" />
                  受信箱
                </Button>
              </Link>
              <Link href="/profile">
                <Button className="bg-blue-600 hover:bg-blue-700 text-white">
                  <User className="h-4 w-4 mr-2" />
                  プロフィール設定
                </Button>
              </Link>
            </div>
          </div>
        </div>

        {/* 解約ユーザーバナー（新規ユーザーには表示しない） */}
        <DormantUserBanner
          isActive={userData?.is_active_investor ?? true}
          hasApprovedNft={userData?.has_approved_nft ?? false}
        />

        {/* お知らせバナー */}
        <AnnouncementsBanner />

        {/* 最重要カード（即座に表示） */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4 mb-6">
          <MonthlyCumulativeProfitCard userId={userData?.user_id || ""} />
          <DailyProfitCard userId={userData?.user_id || ""} />
          <LastMonthProfitCard userId={userData?.user_id || ""} />
        </div>

        {/* 遅延読み込みコンテンツ */}
        <LazyLoadedContent userData={userData} userStats={userStats} currentInvestment={currentInvestment} currentNftCount={currentNftCount} />
        
        {/* アラート類 */}
        {showNftAddressAlert && (
          <NFTAddressAlert onClose={handleNftAddressAlertClose} />
        )}
      </div>

      {/* 月末報酬タスクポップアップ（月末自動出金用） */}
      {userData && (
        <RewardTaskPopup
          userId={userData.user_id}
          isOpen={showRewardTaskPopup}
          onComplete={() => {
            setShowRewardTaskPopup(false)
            window.location.reload()
          }}
        />
      )}

      {/* 紹介報酬計算完了タスクポップアップ */}
      {userData && (
        <RewardTaskPopup
          userId={userData.user_id}
          isOpen={showReferralRewardTaskPopup}
          onComplete={() => {
            setShowReferralRewardTaskPopup(false)
            window.location.reload()
          }}
        />
      )}

      {/* CoinW UID確認ポップアップ（初回ログイン時、localStorageで管理、z-index=100で最優先） */}
      {userData && (
        <CoinwUidPopup
          userId={userData.user_id}
          coinwUid={userData.coinw_uid}
        />
      )}

      {/* 利用規約への同意ポップアップ（初回のみ、DB保存で二度と表示しない、z-index=200で最優先） */}
      {userData && (
        <TermsAgreementPopup
          userId={userData.user_id}
          termsAgreedAt={userData.terms_agreed_at}
        />
      )}
    </div>
  )
}

// 遅延読み込みコンテンツ
const LazyLoadedContent = ({ userData, userStats, currentInvestment, currentNftCount }: { userData: UserData | null, userStats: UserStats | null, currentInvestment: number, currentNftCount: number }) => {
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
                ${currentInvestment.toLocaleString()}
              </span>
            </div>
            <p className="text-xs text-gray-500 mt-1">{currentNftCount} NFT保有</p>
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
                ${(userStats?.total_referral_investment || 0).toLocaleString()}
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
      <DelayedContent userData={userData} userStats={userStats} currentInvestment={currentInvestment} />
    </>
  )
}

// さらに遅延したコンテンツ
const DelayedContent = ({ userData, userStats, currentInvestment }: { userData: UserData | null, userStats: UserStats | null, currentInvestment: number }) => {
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
        <PersonalProfitCard userId={userData?.user_id || ""} totalInvestment={currentInvestment} />
        {!userData?.is_operation_only && !(userData?.is_active_investor === false && userData?.has_approved_nft === true) && (
          <ReferralProfitCard
            userId={userData?.user_id || ""}
            level1Investment={userStats?.level1_investment || 0}
            level2Investment={userStats?.level2_investment || 0}
            level3Investment={userStats?.level3_investment || 0}
          />
        )}
      </div>

      {/* 組織図（解約ユーザーは非表示、新規ユーザーは表示） */}
      {!userData?.is_operation_only && !(userData?.is_active_investor === false && userData?.has_approved_nft === true) && (
        <div className="mb-6">
          <ReferralTreeOptimized userId={userData?.user_id || ""} />
        </div>
      )}

      {/* 保有NFT一覧（運用開始日表示） */}
      <div className="mb-6">
        <NftListCard userId={userData?.user_id || ""} />
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

      {/* レベル別統計（解約ユーザーは非表示、新規ユーザーは表示） */}
      {!userData?.is_operation_only && !(userData?.is_active_investor === false && userData?.has_approved_nft === true) && (
        <LevelStats userStats={userStats} />
      )}

      {/* Level4以降の統計（解約ユーザーは非表示、新規ユーザーは表示） */}
      {!userData?.is_operation_only && !(userData?.is_active_investor === false && userData?.has_approved_nft === true) && (
        <Level4PlusStats userStats={userStats} />
      )}
    </>
  )
}

// Level4以降統計コンポーネント
const Level4PlusStats = ({ userStats }: { userStats: UserStats | null }) => (
  <Card className="bg-gray-900/50 border-gray-700">
    <CardHeader>
      <CardTitle className="text-white text-lg">Level4以降の総計</CardTitle>
    </CardHeader>
    <CardContent>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-gradient-to-r from-orange-900/20 to-orange-900/10 border border-orange-600/30 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <Users className="h-6 w-6 text-orange-400 flex-shrink-0" />
            <div>
              <h3 className="text-sm font-semibold text-orange-400">Level4以降の人数</h3>
              <p className="text-xs text-gray-400">Level4以降の合計人数</p>
            </div>
          </div>
          <div className="text-xl font-bold text-orange-400">
            {userStats?.level4_plus_referrals || 0}人
          </div>
        </div>

        <div className="bg-gradient-to-r from-orange-900/20 to-orange-900/10 border border-orange-600/30 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <DollarSign className="h-6 w-6 text-orange-400 flex-shrink-0" />
            <div>
              <h3 className="text-sm font-semibold text-orange-400">Level4以降の投資額</h3>
              <p className="text-xs text-gray-400">Level4以降の投資合計</p>
            </div>
          </div>
          <div className="text-xl font-bold text-orange-400 truncate">
            ${(userStats?.level4_plus_investment || 0).toLocaleString()}
          </div>
        </div>
      </div>
    </CardContent>
  </Card>
)

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
            ${(userStats?.level1_investment || 0).toLocaleString()}
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
            ${(userStats?.level2_investment || 0).toLocaleString()}
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
            ${(userStats?.level3_investment || 0).toLocaleString()}
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
