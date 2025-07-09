"use client"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Copy, ArrowLeft, CheckCircle, AlertCircle } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { QRCodeSVG } from "qrcode.react"
import Image from "next/image"

interface PurchaseData {
  id: string
  user_id: string
  nft_quantity: number
  amount_usd: number
  payment_status: string
  admin_approved: boolean
  created_at: string
}

export default function NFTPaymentPage() {
  const [loading, setLoading] = useState(false)
  const [purchase, setPurchase] = useState<PurchaseData | null>(null)
  const [transactionId, setTransactionId] = useState("")
  const [userNotes, setUserNotes] = useState("")
  const [error, setError] = useState("")
  const router = useRouter()
  const searchParams = useSearchParams()
  const purchaseId = searchParams.get("id")
  const [systemSettings, setSystemSettings] = useState<{
    usdt_address_bep20: string | null
    usdt_address_trc20: string | null
  } | null>(null)

  useEffect(() => {
    if (purchaseId) {
      fetchPurchase()
    } else {
      router.push("/nft-required")
    }
  }, [purchaseId])

  const fetchPurchase = async () => {
    try {
      setError("")

      // 購入データとシステム設定を並行取得
      const [purchaseResult, settingsResult] = await Promise.all([
        supabase.from("purchases").select("*").eq("id", purchaseId).single(),
        supabase.from("system_settings").select("usdt_address_bep20, usdt_address_trc20").single(),
      ])

      if (purchaseResult.error) {
        console.error("Purchase fetch error:", purchaseResult.error)
        throw purchaseResult.error
      }

      setPurchase(purchaseResult.data)

      if (settingsResult.data) {
        setSystemSettings(settingsResult.data)
      }
    } catch (error: any) {
      console.error("Error:", error)
      setError(`購入データの取得に失敗しました: ${error.message}`)
    }
  }

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text)
    alert(`${label}をコピーしました！`)
  }

  const handlePaymentComplete = async () => {
    if (!purchase || !transactionId.trim()) {
      alert("トランザクションIDを入力してください")
      return
    }

    setLoading(true)
    setError("")

    try {
      const { error } = await supabase
        .from("purchases")
        .update({
          payment_status: "payment_sent",
          payment_proof_url: transactionId,
          user_notes: userNotes,
        })
        .eq("id", purchase.id)

      if (error) {
        console.error("Update error:", error)
        throw error
      }

      // 送金完了後はダッシュボードに戻る
      alert("送金情報を送信しました。管理者の確認をお待ちください。承認後にNFTが有効化されます。")
      router.push("/dashboard")
    } catch (error: any) {
      console.error("Update error:", error)
      setError(`更新でエラーが発生しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  if (error && !purchase) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400">エラー</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-white">{error}</p>
            <div className="flex space-x-2">
              <Button onClick={fetchPurchase} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white">
                再試行
              </Button>
              <Button
                variant="outline"
                onClick={() => router.push("/nft-required")}
                className="flex-1 text-white border-white hover:bg-gray-700"
              >
                戻る
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (!purchase) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">読み込み中...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <header className="bg-gray-800 shadow-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Button
                variant="outline"
                size="sm"
                onClick={() => router.push("/nft-required")}
                className="bg-gray-600 hover:bg-gray-700 text-white border-gray-600"
              >
                <ArrowLeft className="w-4 h-4 mr-2" />
                戻る
              </Button>
              <div className="flex items-center space-x-2">
                <Image src="/images/hash-pilot-logo.png" alt="HashPilot Logo" width={40} height={40} />
                <span className="text-xl font-bold text-white">USDT送金手続き</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertCircle className="w-8 h-8 text-blue-600" />
            </div>
            <h1 className="text-4xl font-bold text-white mb-4">USDT送金手続き</h1>
            <p className="text-xl text-gray-400">
              以下のアドレスに指定金額のUSDTを送金し、トランザクションIDを入力してください
            </p>
          </div>

          {error && (
            <Card className="mb-6 bg-red-900 border-red-700">
              <CardContent className="p-4">
                <p className="text-red-200">{error}</p>
              </CardContent>
            </Card>
          )}

          <Card className="mb-6 bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white">購入詳細</CardTitle>
            </CardHeader>
            <CardContent className="text-white">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <span className="text-gray-400">NFT数量:</span>
                  <p className="font-bold text-2xl text-white">{purchase.nft_quantity}</p>
                </div>
                <div>
                  <span className="text-gray-400">送金金額:</span>
                  <p className="font-bold text-2xl text-green-400">${purchase.amount_usd} USDT</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="grid md:grid-cols-2 gap-8 mb-8">
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white">USDT (BEP20)</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <Label className="text-white">送金先アドレス</Label>
                  <div className="flex items-center space-x-2 mt-2">
                    <Input
                      value={systemSettings?.usdt_address_bep20 || "設定されていません"}
                      readOnly
                      className="bg-gray-700 border-gray-600 text-white font-mono text-sm"
                    />
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => copyToClipboard(systemSettings?.usdt_address_bep20 || "", "BEP20アドレス")}
                      className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
                <div className="flex justify-center">
                  <div className="bg-white p-4 rounded-lg">
                    <QRCodeSVG value={systemSettings?.usdt_address_bep20 || ""} size={150} />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white">USDT (TRC20)</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <Label className="text-white">送金先アドレス</Label>
                  <div className="flex items-center space-x-2 mt-2">
                    <Input
                      value={systemSettings?.usdt_address_trc20 || "設定されていません"}
                      readOnly
                      className="bg-gray-700 border-gray-600 text-white font-mono text-sm"
                    />
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => copyToClipboard(systemSettings?.usdt_address_trc20 || "", "TRC20アドレス")}
                      className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
                <div className="flex justify-center">
                  <div className="bg-white p-4 rounded-lg">
                    <QRCodeSVG value={systemSettings?.usdt_address_trc20 || ""} size={150} />
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white">送金完了報告</CardTitle>
              <CardDescription className="text-gray-400">送金後、以下の情報を入力してください</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <Label className="text-white">トランザクションID（必須）</Label>
                <Input
                  value={transactionId}
                  onChange={(e) => setTransactionId(e.target.value)}
                  placeholder="送金時に表示されたトランザクションIDを入力"
                  className="bg-gray-700 border-gray-600 text-white placeholder-gray-400"
                  required
                />
                <p className="text-sm text-gray-400 mt-1">ウォレットアプリの送金履歴から確認できます</p>
              </div>

              <div>
                <Label className="text-white">メモ・連絡事項（任意）</Label>
                <Textarea
                  value={userNotes}
                  onChange={(e) => setUserNotes(e.target.value)}
                  placeholder="送金完了日時、使用したネットワーク、その他の連絡事項"
                  className="bg-gray-700 border-gray-600 text-white placeholder-gray-400"
                  rows={3}
                />
              </div>

              <div className="bg-yellow-900 border border-yellow-700 rounded-lg p-4">
                <h3 className="font-semibold text-yellow-200 mb-2">重要な注意事項</h3>
                <ul className="text-sm text-yellow-200 space-y-1">
                  <li>• 正確な金額（${purchase.amount_usd} USDT）を送金してください</li>
                  <li>• 送金ネットワーク（BEP20またはTRC20）を間違えないでください</li>
                  <li>• トランザクションIDは必ず正確に入力してください</li>
                  <li>• 管理者確認後、24時間以内にNFTが有効化されます</li>
                  <li>• 送金確認まで数時間かかる場合があります</li>
                </ul>
              </div>

              <Button
                onClick={handlePaymentComplete}
                disabled={loading || !transactionId.trim()}
                className="w-full bg-green-600 hover:bg-green-700 text-white"
                size="lg"
              >
                {loading ? (
                  "送信中..."
                ) : (
                  <>
                    <CheckCircle className="w-5 h-5 mr-2" />
                    送金完了を報告
                  </>
                )}
              </Button>

              <div className="text-sm text-gray-400 text-center">
                送金完了報告後、管理者の確認をお待ちください。
                <br />
                承認後にダッシュボードでNFTステータスが更新されます。
              </div>
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  )
}
