"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { ShoppingCart, DollarSign, CheckCircle, AlertCircle, Loader2, ArrowLeft, Wallet } from "lucide-react"
import Link from "next/link"

interface UserData {
  id: string
  user_id: string
  email: string
  coinw_uid: string | null
  total_purchases: number
  nft_address: string | null
}

export default function NFTPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<UserData | null>(null)
  const [loading, setLoading] = useState(true)
  const [purchasing, setPurchasing] = useState(false)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")
  const router = useRouter()

  const NFT_PRICE = 1000 // $1000 per NFT
  const FEE_AMOUNT = 100 // $100 fee

  useEffect(() => {
    checkAuth()
  }, [])

  const checkAuth = async () => {
    try {
      const {
        data: { session },
        error: sessionError,
      } = await supabase.auth.getSession()

      if (sessionError) {
        console.error("Session error:", sessionError)
        router.push("/login")
        return
      }

      if (!session?.user) {
        router.push("/login")
        return
      }

      setUser(session.user)
      await fetchUserData(session.user.id)
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/login")
    }
  }

  const fetchUserData = async (userId: string) => {
    try {
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
    } catch (error) {
      console.error("Fetch user data error:", error)
      setError("データの取得中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  const handlePurchase = async () => {
    if (!userData) return

    try {
      setPurchasing(true)
      setError("")
      setSuccess("")

      // NFT購入レコードを作成 - amount_usdは1000に設定
      const { data: purchase, error: purchaseError } = await supabase
        .from("purchases")
        .insert({
          user_id: userData.user_id,
          amount_usd: NFT_PRICE, // $1000 investment amount
          admin_approved: false,
        })
        .select()
        .single()

      if (purchaseError) {
        throw purchaseError
      }

      setSuccess("NFT購入リクエストが送信されました。管理者の承認をお待ちください。")

      // ユーザーデータを再取得
      await fetchUserData(user.id)
    } catch (error: any) {
      console.error("Purchase error:", error)
      setError(`購入に失敗しました: ${error.message}`)
    } finally {
      setPurchasing(false)
    }
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

  if (error && !userData) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardContent className="p-6">
            <div className="text-center text-red-400">
              <p className="mb-4">{error}</p>
              <Button onClick={() => router.push("/dashboard")} variant="outline">
                ダッシュボードに戻る
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  const currentNFTCount = Math.floor((userData?.total_purchases || 0) / NFT_PRICE)

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
                  ダッシュボードに戻る
                </Button>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-white">NFT購入</h1>
                <p className="text-sm text-gray-400">HASH PILOT NFTを購入してネットワークに参加</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8 max-w-4xl">
        {/* アラート */}
        {error && (
          <Alert className="mb-6 bg-red-900 border-red-700">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription className="text-red-200">{error}</AlertDescription>
          </Alert>
        )}

        {success && (
          <Alert className="mb-6 bg-green-900 border-green-700">
            <CheckCircle className="h-4 w-4" />
            <AlertDescription className="text-green-200">{success}</AlertDescription>
          </Alert>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* NFT情報 */}
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white flex items-center">
                <ShoppingCart className="h-5 w-5 mr-2" />
                HASH PILOT NFT
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="text-center">
                <img
                  src="/images/hash-pilot-nft-new.jpg"
                  alt="HASH PILOT NFT"
                  className="w-full max-w-sm mx-auto rounded-lg"
                />
              </div>

              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <span className="text-gray-300">NFT価格</span>
                  <span className="text-2xl font-bold text-green-400">${NFT_PRICE.toLocaleString()}</span>
                </div>

                <div className="flex justify-between items-center">
                  <span className="text-gray-300">手数料</span>
                  <span className="text-lg text-yellow-400">${FEE_AMOUNT.toLocaleString()}</span>
                </div>

                <div className="border-t border-gray-600 pt-4">
                  <div className="flex justify-between items-center">
                    <span className="text-gray-300 font-medium">合計金額</span>
                    <span className="text-2xl font-bold text-white">${(NFT_PRICE + FEE_AMOUNT).toLocaleString()}</span>
                  </div>
                </div>

                <div className="bg-gray-700 rounded-lg p-4">
                  <h4 className="text-white font-medium mb-2">NFTの特典</h4>
                  <ul className="text-sm text-gray-300 space-y-1">
                    <li>• ネットワーク参加権</li>
                    <li>• 紹介報酬の受け取り権</li>
                    <li>• 月次報酬の受け取り権</li>
                    <li>• 限定コミュニティアクセス</li>
                  </ul>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* 購入情報 */}
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white flex items-center">
                <Wallet className="h-5 w-5 mr-2" />
                購入情報
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-4">
                <div>
                  <span className="text-gray-300">現在の保有NFT数</span>
                  <div className="text-3xl font-bold text-blue-400">{currentNFTCount} NFT</div>
                  <p className="text-sm text-gray-400">総投資額: ${(currentNFTCount * NFT_PRICE).toLocaleString()}</p>
                </div>

                <div className="bg-gray-700 rounded-lg p-4">
                  <h4 className="text-white font-medium mb-2">購入者情報</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-400">ユーザーID:</span>
                      <span className="text-white font-mono">{userData?.user_id}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">メール:</span>
                      <span className="text-white">{userData?.email}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">CoinW UID:</span>
                      <span className="text-white">{userData?.coinw_uid || "未設定"}</span>
                    </div>
                  </div>
                </div>

                <Button
                  onClick={handlePurchase}
                  disabled={purchasing}
                  className="w-full bg-green-600 hover:bg-green-700 text-white py-3 text-lg"
                >
                  {purchasing ? (
                    <>
                      <Loader2 className="h-5 w-5 mr-2 animate-spin" />
                      購入処理中...
                    </>
                  ) : (
                    <>
                      <DollarSign className="h-5 w-5 mr-2" />${(NFT_PRICE + FEE_AMOUNT).toLocaleString()} で購入
                    </>
                  )}
                </Button>

                <p className="text-xs text-gray-400 text-center">
                  購入後は管理者の承認が必要です。承認後にNFTが送付されます。
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
