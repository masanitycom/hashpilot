"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Loader2, ArrowLeft, Calendar, Clock, CheckCircle, AlertTriangle, Info } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { PendingWithdrawalCard } from "@/components/pending-withdrawal-card"
import { MonthlyWithdrawalAlert } from "@/components/monthly-withdrawal-alert"
import Link from "next/link"

interface UserData {
  id: string
  user_id: string
  email: string
  full_name: string | null
  reward_address_bep20: string | null
  coinw_uid: string | null
}

export default function WithdrawalPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<UserData | null>(null)
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
                <h1 className="text-xl font-bold text-white">月末自動出金</h1>
                <p className="text-sm text-gray-400">月末自動出金システムの概要と状況</p>
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
        {/* 月末出金システム概要 */}
        <Card className="mb-8 bg-gradient-to-r from-blue-900/20 to-purple-900/20 border border-blue-700/50">
          <CardHeader>
            <CardTitle className="text-white text-2xl flex items-center space-x-3">
              <Calendar className="h-6 w-6 text-blue-400" />
              <span>月末自動出金システム</span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="text-center p-4 bg-blue-900/20 rounded-lg">
                <Clock className="h-8 w-8 text-blue-400 mx-auto mb-2" />
                <p className="text-blue-300 font-medium">自動処理</p>
                <p className="text-sm text-gray-300">毎月月末に自動実行</p>
              </div>
              <div className="text-center p-4 bg-green-900/20 rounded-lg">
                <CheckCircle className="h-8 w-8 text-green-400 mx-auto mb-2" />
                <p className="text-green-300 font-medium">手数料なし</p>
                <p className="text-sm text-gray-300">管理者が手数料負担</p>
              </div>
              <div className="text-center p-4 bg-purple-900/20 rounded-lg">
                <AlertTriangle className="h-8 w-8 text-purple-400 mx-auto mb-2" />
                <p className="text-purple-300 font-medium">最小額$10</p>
                <p className="text-sm text-gray-300">$10以上で自動出金</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* 出金状況 */}
          <div className="space-y-6">
            <h2 className="text-xl font-bold text-white">あなたの出金状況</h2>
            <PendingWithdrawalCard userId={userData?.user_id || ""} />
          </div>

          {/* 設定とアラート */}
          <div className="space-y-6">
            <h2 className="text-xl font-bold text-white">設定とお知らせ</h2>
            <MonthlyWithdrawalAlert 
              userId={userData?.user_id || ""} 
              hasWithdrawalAddress={!!(userData?.reward_address_bep20 || userData?.coinw_uid)}
            />
            <Card className="bg-gray-800 border-gray-700">
              <CardContent className="p-4">
                <Link href="/profile">
                  <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white">
                    プロフィールで送金先を設定
                  </Button>
                </Link>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* システム詳細 */}
        <Card className="mt-8 bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white text-lg flex items-center space-x-2">
              <Info className="h-5 w-5 text-blue-400" />
              <span>月末自動出金システムについて</span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 text-sm text-gray-300">
            <div className="space-y-3">
              <div className="flex items-start space-x-3">
                <span className="text-blue-400 font-bold">1.</span>
                <div>
                  <p className="font-medium text-white">処理タイミング</p>
                  <p>毎月月末の日利設定完了後、翌1日にリセットと同時に出金処理を実行します。</p>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <span className="text-blue-400 font-bold">2.</span>
                <div>
                  <p className="font-medium text-white">送金方法</p>
                  <p>プロフィールで設定された報酬受取アドレス（USDT BEP20）またはCoinW UIDに送金されます。</p>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <span className="text-blue-400 font-bold">3.</span>
                <div>
                  <p className="font-medium text-white">最小出金額</p>
                  <p>$10以上の報酬がある場合に自動出金されます。$10未満の場合は翌月に繰り越されます。</p>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <span className="text-blue-400 font-bold">4.</span>
                <div>
                  <p className="font-medium text-white">送金先未設定の場合</p>
                  <p>送金先が設定されていない場合、出金は保留状態となり、設定完了後に送金されます。</p>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <span className="text-blue-400 font-bold">5.</span>
                <div>
                  <p className="font-medium text-white">確認メール</p>
                  <p>出金処理が完了すると、登録メールアドレスに確認メールが送信されます。</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}