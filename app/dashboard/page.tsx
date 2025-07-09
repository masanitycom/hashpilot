"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Loader2, LogOut, TrendingUp, DollarSign, Users, Gift, User } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { ReferralTree } from "@/components/referral-tree"
import { DailyProfitChart } from "@/components/daily-profit-chart"
import Link from "next/link"

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
}

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<UserData | null>(null)
  const [userStats, setUserStats] = useState<UserStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [authChecked, setAuthChecked] = useState(false)
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

      const {
        data: { session },
        error: sessionError,
      } = await supabase.auth.getSession()

      setAuthChecked(true)

      if (sessionError) {
        console.error("Session error:", sessionError)
        router.push("/login")
        return
      }

      if (!session?.user) {
        console.log("No session found, redirecting to login")
        router.push("/login")
        return
      }

      console.log("User authenticated:", session.user.id)
      setUser(session.user)
      await fetchUserData(session.user.id)
    } catch (error) {
      console.error("Auth check error:", error)
      setAuthChecked(true)
      router.push("/login")
    }
  }

  const fetchUserData = async (userId: string) => {
    try {
      if (!supabase) {
        throw new Error("Supabase client not available")
      }

      const { data: userRecords, error: userError } = await supabase.from("users").select("*").eq("id", userId)

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
      setUserData(userRecord)
      await calculateStats(userRecord)
    } catch (error) {
      console.error("Fetch user data error:", error)
      setError("データの取得中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  const calculateStats = async (userRecord: UserData) => {
    try {
      if (!supabase) {
        throw new Error("Supabase client not available")
      }

      // 個人投資額
      const totalInvestment = Math.floor((userRecord.total_purchases || 0) / 1000) * 1000

      // 直接紹介者数を取得
      const { data: directReferrals, error: directError } = await supabase
        .from("users")
        .select("user_id, total_purchases")
        .eq("referrer_user_id", userRecord.user_id)

      if (directError) {
        throw directError
      }

      const directCount = directReferrals ? directReferrals.length : 0
      const directInvestment = directReferrals
        ? directReferrals.reduce((sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000, 0)
        : 0

      // 間接紹介者数を取得（レベル2とレベル3）
      let totalReferrals = directCount
      let totalReferralInvestment = directInvestment

      if (directReferrals && directReferrals.length > 0) {
        for (const directRef of directReferrals) {
          // レベル2
          const { data: level2Refs, error: level2Error } = await supabase
            .from("users")
            .select("user_id, total_purchases")
            .eq("referrer_user_id", directRef.user_id)

          if (!level2Error && level2Refs) {
            totalReferrals += level2Refs.length
            totalReferralInvestment += level2Refs.reduce(
              (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
              0,
            )

            // レベル3
            for (const level2Ref of level2Refs) {
              const { data: level3Refs, error: level3Error } = await supabase
                .from("users")
                .select("user_id, total_purchases")
                .eq("referrer_user_id", level2Ref.user_id)

              if (!level3Error && level3Refs) {
                totalReferrals += level3Refs.length
                totalReferralInvestment += level3Refs.reduce(
                  (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
                  0,
                )
              }
            }
          }
        }
      }

      setUserStats({
        total_investment: totalInvestment,
        direct_referrals: directCount,
        total_referrals: totalReferrals,
        total_referral_investment: totalReferralInvestment,
      })
    } catch (error) {
      console.error("Stats calculation error:", error)
      setUserStats({
        total_investment: Math.floor((userRecord.total_purchases || 0) / 1000) * 1000,
        direct_referrals: 0,
        total_referrals: 0,
        total_referral_investment: 0,
      })
    }
  }

  const handleLogout = async () => {
    try {
      if (supabase) {
        await supabase.auth.signOut()
      }
      router.push("/login")
    } catch (error) {
      console.error("Logout error:", error)
      router.push("/login")
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
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-8" />
              <div>
                <h1 className="text-xl font-bold text-white">HASH PILOT</h1>
                <p className="text-sm text-gray-400">ダッシュボード</p>
              </div>
            </div>

            <div className="flex items-center space-x-4">
              <Link href="/nft">
                <Button
                  variant="outline"
                  size="sm"
                  className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                >
                  NFT購入
                </Button>
              </Link>
              <Button onClick={handleLogout} variant="ghost" size="sm" className="text-gray-300 hover:text-white">
                <LogOut className="h-4 w-4 mr-2" />
                ログアウト
              </Button>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* ヒーローセクション */}
        <div className="mb-8 bg-gradient-to-r from-blue-900/20 to-purple-900/20 border border-blue-700/50 rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <div className="flex items-center space-x-4 mb-4">
                <h2 className="text-2xl font-bold text-white">こんにちは、{userData?.user_id}さん</h2>
                <div className="flex items-center space-x-2">
                  <Badge className="bg-blue-600 text-white">ID: {userData?.user_id}</Badge>
                  {userData?.coinw_uid && <Badge className="bg-green-600 text-white">CoinW認証済み</Badge>}
                </div>
              </div>
              <p className="text-gray-400">{userData?.email}</p>
            </div>
            <div>
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
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {/* 統計カード */}
          <div className="lg:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* 個人投資額 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader className="pb-3">
                <CardTitle className="text-gray-300 text-sm font-medium">個人投資額</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-5 w-5 text-green-400" />
                  <span className="text-2xl font-bold text-green-400">
                    ${userStats?.total_investment.toLocaleString()}.00
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-1">{nftCount} NFT保有</p>
              </CardContent>
            </Card>

            {/* 直接紹介者数 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader className="pb-3">
                <CardTitle className="text-gray-300 text-sm font-medium">直接紹介</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-center space-x-2">
                  <Users className="h-5 w-5 text-blue-400" />
                  <span className="text-2xl font-bold text-blue-400">{userStats?.direct_referrals || 0}</span>
                </div>
                <p className="text-xs text-gray-500 mt-1">直接紹介した人数</p>
              </CardContent>
            </Card>

            {/* 総紹介者数 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader className="pb-3">
                <CardTitle className="text-gray-300 text-sm font-medium">総紹介者</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-center space-x-2">
                  <TrendingUp className="h-5 w-5 text-purple-400" />
                  <span className="text-2xl font-bold text-purple-400">{userStats?.total_referrals || 0}</span>
                </div>
                <p className="text-xs text-gray-500 mt-1">全レベル合計</p>
              </CardContent>
            </Card>

            {/* 紹介者投資総額 */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader className="pb-3">
                <CardTitle className="text-gray-300 text-sm font-medium">紹介者投資総額</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-center space-x-2">
                  <Gift className="h-5 w-5 text-orange-400" />
                  <span className="text-2xl font-bold text-orange-400">
                    ${userStats?.total_referral_investment.toLocaleString()}.00
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

        {/* 紹介ツリーセクション */}
        <div className="mb-8">
          <ReferralTree userId={userData?.user_id || ""} />
        </div>
      </div>
    </div>
  )
}
