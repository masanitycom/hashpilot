"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { ArrowLeft, AlertCircle, ArrowRight, CheckCircle, RefreshCw } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Image from "next/image"

interface PurchaseData {
  id: string
  nft_quantity: number
  amount_usd: number
  payment_status: string
  admin_approved: boolean
  created_at: string
}

export default function NFTRequiredPage() {
  const [loading, setLoading] = useState(false)
  const [user, setUser] = useState<any>(null)
  const [existingPurchase, setExistingPurchase] = useState<PurchaseData | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [error, setError] = useState("")
  const [debugInfo, setDebugInfo] = useState("")
  const [authUser, setAuthUser] = useState<any>(null)
  const router = useRouter()

  const NFT_PRICE = 1100 // $1100 per NFT

  useEffect(() => {
    checkUserAndPurchase()
  }, [])

  const checkUserAndPurchase = async () => {
    try {
      setError("")
      setDebugInfo("認証状態を確認中...")

      // 認証ユーザーを取得
      const {
        data: { user: currentAuthUser },
        error: authError,
      } = await supabase.auth.getUser()

      if (authError) {
        console.error("Auth error:", authError)
        setDebugInfo(`認証エラー: ${authError.message}`)
        setError("認証エラーが発生しました")
        return
      }

      if (!currentAuthUser) {
        setDebugInfo("未認証ユーザー")
        router.push("/login")
        return
      }

      setAuthUser(currentAuthUser)
      setDebugInfo(`認証済み: ${currentAuthUser.email} (ID: ${currentAuthUser.id.substring(0, 8)}...)`)

      // ユーザーデータを取得（エラーハンドリング強化）
      try {
        const { data: userData, error: userError } = await supabase
          .from("users")
          .select("*")
          .eq("id", currentAuthUser.id)
          .single()

        if (userError) {
          console.error("User fetch error:", userError)
          setDebugInfo(`ユーザーデータエラー: ${userError.message} (Code: ${userError.code})`)

          // ユーザーレコードが存在しない場合は作成を試行
          if (userError.code === "PGRST116") {
            // No rows returned
            setDebugInfo("ユーザーレコードが存在しません。作成を試行中...")
            await createUserRecord(currentAuthUser)
            return
          }

          setError(`ユーザーデータの取得に失敗しました: ${userError.message}`)
          return
        }

        if (!userData) {
          setDebugInfo("ユーザーデータが見つかりません。作成を試行中...")
          await createUserRecord(currentAuthUser)
          return
        }

        setUser(userData)
        setDebugInfo(`ユーザーデータ取得成功: ${userData.user_id}`)

        // 既存の購入をチェック
        await checkExistingPurchases(userData.user_id)
      } catch (userFetchError: any) {
        console.error("User fetch exception:", userFetchError)
        setDebugInfo(`ユーザーデータ取得例外: ${userFetchError.message}`)
        setError(`ユーザーデータの取得でエラーが発生しました: ${userFetchError.message}`)
      }
    } catch (error: any) {
      console.error("General error:", error)
      setDebugInfo(`予期しないエラー: ${error.message}`)
      setError("データの読み込みでエラーが発生しました")
    }
  }

  const createUserRecord = async (authUser: any) => {
    try {
      setDebugInfo("ユーザーレコードを作成中...")

      // ランダムなuser_idを生成
      const generateRandomId = () => {
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let result = ""
        for (let i = 0; i < 6; i++) {
          result += chars.charAt(Math.floor(Math.random() * chars.length))
        }
        return result
      }

      const userId = generateRandomId()

      const { data: newUserData, error: insertError } = await supabase
        .from("users")
        .insert({
          id: authUser.id,
          user_id: userId,
          email: authUser.email || "",
          total_purchases: 0,
          total_referral_earnings: 0,
          is_active: true,
          has_approved_nft: false,
        })
        .select()
        .single()

      if (insertError) {
        console.error("User creation error:", insertError)
        setDebugInfo(`ユーザー作成エラー: ${insertError.message}`)
        setError(`ユーザーレコードの作成に失敗しました: ${insertError.message}`)
        return
      }

      setUser(newUserData)
      setDebugInfo(`ユーザーレコード作成成功: ${newUserData.user_id}`)

      // 作成後、購入データをチェック
      await checkExistingPurchases(newUserData.user_id)
    } catch (error: any) {
      console.error("User creation exception:", error)
      setDebugInfo(`ユーザー作成例外: ${error.message}`)
      setError(`ユーザーレコードの作成でエラーが発生しました: ${error.message}`)
    }
  }

  const checkExistingPurchases = async (userId: string) => {
    try {
      setDebugInfo(`購入データを確認中... (user_id: ${userId})`)

      const { data: purchaseData, error: purchaseError } = await supabase
        .from("purchases")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1)

      if (purchaseError) {
        console.error("Purchase fetch error:", purchaseError)
        setDebugInfo(`購入データエラー: ${purchaseError.message}`)
        // 購入データが取得できなくても続行（初回購入の場合）
      } else if (purchaseData && purchaseData.length > 0) {
        setExistingPurchase(purchaseData[0])
        setQuantity(purchaseData[0].nft_quantity)
        setDebugInfo(`既存購入データ発見: ${purchaseData[0].id}`)
      } else {
        setDebugInfo("既存購入データなし（初回購入）")
      }
    } catch (error: any) {
      console.error("Purchase check exception:", error)
      setDebugInfo(`購入チェック例外: ${error.message}`)
    }
  }

  const handleNext = async () => {
    if (!user) {
      setError("ユーザー情報が見つかりません")
      return
    }

    setLoading(true)
    setError("")
    setDebugInfo("購入処理を開始...")

    try {
      let purchaseId = existingPurchase?.id

      if (!existingPurchase) {
        // 新しい購入を作成
        setDebugInfo(`新規購入作成中... user_id: ${user.user_id}`)

        const purchaseData = {
          user_id: user.user_id,
          nft_quantity: quantity,
          amount_usd: quantity * NFT_PRICE,
          payment_status: "pending",
          admin_approved: false,
        }

        setDebugInfo(`挿入データ: ${JSON.stringify(purchaseData)}`)

        const { data, error } = await supabase.from("purchases").insert(purchaseData).select().single()

        if (error) {
          console.error("Insert error:", error)
          setDebugInfo(`挿入エラー: ${error.message} (Code: ${error.code})`)
          throw error
        }

        setDebugInfo(`購入作成成功: ${data.id}`)
        purchaseId = data.id
      } else {
        // 既存の購入を更新
        setDebugInfo(`既存購入更新中: ${existingPurchase.id}`)

        const { error } = await supabase
          .from("purchases")
          .update({
            nft_quantity: quantity,
            amount_usd: quantity * NFT_PRICE,
          })
          .eq("id", existingPurchase.id)

        if (error) {
          console.error("Update error:", error)
          setDebugInfo(`更新エラー: ${error.message}`)
          throw error
        }

        setDebugInfo("購入更新成功")
      }

      // 送金ページに遷移
      setDebugInfo("送金ページに遷移中...")
      router.push(`/nft-payment?id=${purchaseId}`)
    } catch (error: any) {
      console.error("Purchase error:", error)
      setDebugInfo(`処理エラー: ${error.message}`)
      setError(`処理でエラーが発生しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const getStatusBadge = (status: string, approved: boolean) => {
    if (approved) {
      return <Badge className="bg-green-600">承認済み</Badge>
    }

    switch (status) {
      case "pending":
        return <Badge variant="secondary">注文作成済み</Badge>
      case "payment_sent":
        return <Badge className="bg-yellow-600">送金完了・確認待ち</Badge>
      case "payment_confirmed":
        return <Badge className="bg-blue-600">入金確認済み</Badge>
      default:
        return <Badge variant="outline">{status}</Badge>
    }
  }

  if (existingPurchase?.admin_approved) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader className="text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="w-8 h-8 text-green-600" />
            </div>
            <CardTitle className="text-2xl text-white">NFT承認完了！</CardTitle>
          </CardHeader>
          <CardContent className="text-center space-y-4">
            <p className="text-gray-300">
              おめでとうございます！NFTが承認され、すべての機能にアクセスできるようになりました。
            </p>
            <Button onClick={() => router.push("/dashboard")} className="w-full">
              ダッシュボードへ
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <header className="bg-gray-800 shadow-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Button variant="outline" size="sm" onClick={() => router.push("/")}>
                <ArrowLeft className="w-4 h-4 mr-2" />
                ホーム
              </Button>
              <div className="flex items-center space-x-2">
                <Image src="/images/hash-pilot-logo.png" alt="HashPilot Logo" width={40} height={40} />
                <span className="text-xl font-bold text-white">HASH PILOT NFT必須</span>
              </div>
            </div>
            <Button variant="outline" size="sm" onClick={checkUserAndPurchase}>
              <RefreshCw className="w-4 h-4 mr-2" />
              再読み込み
            </Button>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertCircle className="w-8 h-8 text-yellow-600" />
            </div>
            <h1 className="text-4xl font-bold text-white mb-4">NFT購入が必要です</h1>
            <p className="text-xl text-gray-400">HASH PILOTの全機能を利用するには、NFTの購入と承認が必要です</p>
          </div>

          {debugInfo && (
            <Card className="mb-6 bg-blue-900 border-blue-700">
              <CardContent className="p-4">
                <p className="text-blue-200 text-sm">デバッグ情報: {debugInfo}</p>
                {authUser && (
                  <p className="text-blue-300 text-xs mt-1">
                    認証ユーザー: {authUser.email} | ID: {authUser.id.substring(0, 8)}...
                  </p>
                )}
              </CardContent>
            </Card>
          )}

          {error && (
            <Card className="mb-6 bg-red-900 border-red-700">
              <CardContent className="p-4">
                <p className="text-red-200">{error}</p>
                <Button onClick={checkUserAndPurchase} className="mt-2" size="sm">
                  再試行
                </Button>
              </CardContent>
            </Card>
          )}

          {existingPurchase && (
            <Card className="mb-6 bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center justify-between">
                  購入状況
                  {getStatusBadge(existingPurchase.payment_status, existingPurchase.admin_approved)}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-white">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-400">購入ID:</span>
                    <p className="font-mono">{existingPurchase.id}</p>
                  </div>
                  <div>
                    <span className="text-gray-400">金額:</span>
                    <p className="font-bold text-green-600">${existingPurchase.amount_usd}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          <div className="grid md:grid-cols-2 gap-8">
            <Card className="bg-gray-800 text-white">
              <CardHeader>
                <div className="w-full h-64 rounded-lg overflow-hidden">
                  <Image
                    src="/images/hash-pilot-nft-new.jpg"
                    alt="HASH PILOT NFT"
                    width={400}
                    height={256}
                    className="w-full h-full object-cover"
                  />
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-lg font-semibold">価格</span>
                    <Badge variant="secondary" className="text-lg px-3 py-1">
                      ${NFT_PRICE} USDT
                    </Badge>
                  </div>
                  <div className="text-gray-400">
                    <p>HASH PILOT必須NFT</p>
                    <p>• 全機能へのアクセス権</p>
                    <p>• 紹介システムの利用権</p>
                    <p>• 限定コミュニティ参加権</p>
                    <p>• 将来的な追加特典</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-gray-800 text-white">
              <CardHeader>
                <CardTitle>NFT購入</CardTitle>
                <CardDescription className="text-gray-400">購入数量を選択してください</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="space-y-2">
                  <Label htmlFor="quantity">購入数量</Label>
                  <Input
                    id="quantity"
                    type="number"
                    min="1"
                    max="10"
                    value={quantity}
                    onChange={(e) => setQuantity(Number.parseInt(e.target.value) || 1)}
                    className="bg-gray-700 border-gray-600 text-white placeholder-gray-400"
                  />
                  <p className="text-sm text-gray-400">最大10個まで購入可能</p>
                </div>

                <div className="bg-gray-700 p-4 rounded-lg space-y-2">
                  <div className="flex justify-between">
                    <span>単価:</span>
                    <span>${NFT_PRICE} USDT</span>
                  </div>
                  <div className="flex justify-between">
                    <span>数量:</span>
                    <span>{quantity}</span>
                  </div>
                  <div className="border-t pt-2 border-gray-600">
                    <div className="flex justify-between font-bold text-lg">
                      <span>合計:</span>
                      <span>${(quantity * NFT_PRICE).toFixed(2)} USDT</span>
                    </div>
                  </div>
                </div>

                <Button
                  onClick={handleNext}
                  disabled={loading || !user}
                  className="w-full bg-blue-600 hover:bg-blue-700"
                  size="lg"
                >
                  {loading ? (
                    "処理中..."
                  ) : (
                    <>
                      次へ（送金情報）
                      <ArrowRight className="w-5 h-5 ml-2" />
                    </>
                  )}
                </Button>

                <div className="text-sm text-gray-500 text-center">
                  次のページで送金先アドレスとQRコードを表示します
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </main>
    </div>
  )
}
