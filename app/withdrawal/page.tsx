"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Loader2, ArrowLeft, Wallet, DollarSign, TrendingUp } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { WithdrawalRequest } from "@/components/withdrawal-request"
import Link from "next/link"

interface UserData {
  id: string
  user_id: string
  email: string
  full_name: string | null
}

interface CycleData {
  phase: string
  cum_usdt: number
  available_usdt: number
  total_nft_count: number
}

export default function WithdrawalPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<UserData | null>(null)
  const [cycleData, setCycleData] = useState<CycleData | null>(null)
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

      // ユーザーデータ取得
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
      setUserData(userRecord)

      // サイクルデータ取得
      const { data: cycleRecord, error: cycleError } = await supabase
        .from("affiliate_cycle")
        .select("*")
        .eq("user_id", userRecord.user_id)
        .single()

      if (cycleError) {
        if (cycleError.code !== "PGRST116") {
          console.error("Cycle data error:", cycleError)
        }
        // サイクルデータがない場合はデフォルト値
        setCycleData({
          phase: "USDT",
          cum_usdt: 0,
          available_usdt: 0,
          total_nft_count: 0
        })
      } else {
        setCycleData(cycleRecord)
      }
    } catch (error) {
      console.error("Fetch user data error:", error)
      setError("データの取得中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  // 認証チェック前は何も表示しない
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

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/dashboard">
                <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  ダッシュボード
                </Button>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-white">出金申請</h1>
                <p className="text-sm text-gray-400">利益の出金申請を行えます</p>
              </div>
            </div>

            <div className="flex items-center space-x-4">
              <Badge className="bg-blue-600 text-white">
                {userData?.user_id}
              </Badge>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* 概要セクション */}
        <div className="mb-8 bg-gradient-to-r from-green-900/20 to-blue-900/20 border border-green-700/50 rounded-lg p-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* 利用可能残高 */}
            <div className="text-center">
              <div className="flex items-center justify-center mb-2">
                <Wallet className="h-6 w-6 text-green-400 mr-2" />
                <span className="text-green-400 font-medium">利用可能残高</span>
              </div>
              <div className="text-3xl font-bold text-green-400">
                ${cycleData?.available_usdt.toFixed(2) || "0.00"}
              </div>
              <p className="text-xs text-gray-400 mt-1">即時出金可能</p>
            </div>

            {/* 累積残高 */}
            <div className="text-center">
              <div className="flex items-center justify-center mb-2">
                <TrendingUp className="h-6 w-6 text-blue-400 mr-2" />
                <span className="text-blue-400 font-medium">累積残高</span>
              </div>
              <div className="text-3xl font-bold text-blue-400">
                ${cycleData?.cum_usdt.toFixed(2) || "0.00"}
              </div>
              <p className="text-xs text-gray-400 mt-1">サイクル進行中</p>
            </div>

            {/* 保有NFT */}
            <div className="text-center">
              <div className="flex items-center justify-center mb-2">
                <DollarSign className="h-6 w-6 text-purple-400 mr-2" />
                <span className="text-purple-400 font-medium">保有NFT</span>
              </div>
              <div className="text-3xl font-bold text-purple-400">
                {cycleData?.total_nft_count || 0}
              </div>
              <p className="text-xs text-gray-400 mt-1">収益生成中</p>
            </div>
          </div>
        </div>

        {/* 出金申請コンポーネント */}
        <WithdrawalRequest
          userId={userData?.user_id || ""}
          availableUsdt={cycleData?.available_usdt || 0}
        />

        {/* 注意事項 */}
        <Card className="mt-8 bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white text-lg">出金に関する注意事項</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-gray-300">
            <div className="flex items-start space-x-2">
              <span className="text-yellow-400 font-bold">•</span>
              <span>最小出金額は$100です。</span>
            </div>
            <div className="flex items-start space-x-2">
              <span className="text-yellow-400 font-bold">•</span>
              <span>出金申請は管理者による審査が必要です（通常1-3営業日）。</span>
            </div>
            <div className="flex items-start space-x-2">
              <span className="text-yellow-400 font-bold">•</span>
              <span>ウォレットアドレスは正確に入力してください。間違ったアドレスへの送金は復元できません。</span>
            </div>
            <div className="flex items-start space-x-2">
              <span className="text-yellow-400 font-bold">•</span>
              <span>HOLDフェーズ中の累積残高は2200 USDT到達まで出金できません。</span>
            </div>
            <div className="flex items-start space-x-2">
              <span className="text-yellow-400 font-bold">•</span>
              <span>ネットワーク手数料は受取額から差し引かれる場合があります。</span>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}