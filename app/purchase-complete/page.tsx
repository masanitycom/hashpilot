"use client"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Copy, CheckCircle, ArrowLeft } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"
import { QRCodeSVG } from "qrcode.react"
import Image from "next/image"

interface PurchaseData {
  id: string
  nft_quantity: number
  amount_usd: number
  created_at: string
}

export default function PurchaseCompletePage() {
  const [purchase, setPurchase] = useState<PurchaseData | null>(null)
  const [loading, setLoading] = useState(true)
  const router = useRouter()
  const searchParams = useSearchParams()
  const purchaseId = searchParams.get("id")

  // USDT送金先アドレス（実際の運用では環境変数から取得）
  const USDT_BEP20_ADDRESS = "0x1234567890123456789012345678901234567890"
  const USDT_TRC20_ADDRESS = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

  useEffect(() => {
    if (purchaseId) {
      fetchPurchase()
    } else {
      router.push("/nft")
    }
  }, [purchaseId])

  const fetchPurchase = async () => {
    try {
      const { data, error } = await supabase.from("purchases").select("*").eq("id", purchaseId).single()

      if (error) throw error
      setPurchase(data)

      // 自動返信メール送信（実際の実装では別途メール送信サービスを使用）
      await sendConfirmationEmail(data)
    } catch (error) {
      console.error("Error:", error)
      router.push("/nft")
    } finally {
      setLoading(false)
    }
  }

  const sendConfirmationEmail = async (purchaseData: PurchaseData) => {
    // 実際の実装ではメール送信APIを呼び出し
    console.log("Sending confirmation email for purchase:", purchaseData.id)
  }

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text)
    alert(`${label}をコピーしました！`)
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-400">読み込み中...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <header className="bg-gray-800 shadow-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center space-x-4">
            <Link href="/dashboard">
              <Button variant="outline" size="sm">
                <ArrowLeft className="w-4 h-4 mr-2" />
                ダッシュボード
              </Button>
            </Link>
            <div className="flex items-center space-x-2">
              <Image src="/images/hash-pilot-logo.png" alt="Logo" width={32} height={32} />
              <span className="text-xl font-bold text-white">購入完了</span>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="max-w-2xl mx-auto">
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="w-8 h-8 text-green-600" />
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">購入完了！</h1>
            <p className="text-gray-400">ご購入ありがとうございます。以下のアドレスにUSDTをお送りください。</p>
          </div>

          <Card className="mb-6 bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white">購入詳細</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <span className="text-sm text-gray-500">購入ID</span>
                  <p className="font-mono text-sm text-white">{purchase?.id}</p>
                </div>
                <div>
                  <span className="text-sm text-gray-500">購入日時</span>
                  <p className="text-sm text-white">
                    {purchase?.created_at && new Date(purchase.created_at).toLocaleString("ja-JP")}
                  </p>
                </div>
                <div>
                  <span className="text-sm text-gray-500">NFT数量</span>
                  <p className="font-bold text-white">{purchase?.nft_quantity}</p>
                </div>
                <div>
                  <span className="text-sm text-gray-500">支払い金額</span>
                  <p className="font-bold text-green-600">${purchase?.amount_usd.toFixed(2)} USDT</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="mb-6 bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white">USDT送金先アドレス (BEP20)</CardTitle>
              <CardDescription className="text-gray-400">Binance Smart Chain (BSC) ネットワーク</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center space-x-2">
                <input
                  type="text"
                  value={USDT_BEP20_ADDRESS}
                  readOnly
                  className="flex-1 px-3 py-2 border border-gray-600 rounded-md bg-gray-700 font-mono text-sm text-white"
                />
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => copyToClipboard(USDT_BEP20_ADDRESS, "BEP20アドレス")}
                >
                  <Copy className="w-4 h-4" />
                </Button>
              </div>
              <div className="flex justify-center">
                <div className="bg-white p-4 border rounded-lg">
                  <QRCodeSVG value={USDT_BEP20_ADDRESS} size={150} />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="mb-6 bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-white">USDT送金先アドレス (TRC20)</CardTitle>
              <CardDescription className="text-gray-400">TRON ネットワーク</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center space-x-2">
                <input
                  type="text"
                  value={USDT_TRC20_ADDRESS}
                  readOnly
                  className="flex-1 px-3 py-2 border border-gray-600 rounded-md bg-gray-700 font-mono text-sm text-white"
                />
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => copyToClipboard(USDT_TRC20_ADDRESS, "TRC20アドレス")}
                >
                  <Copy className="w-4 h-4" />
                </Button>
              </div>
              <div className="flex justify-center">
                <div className="bg-white p-4 border rounded-lg">
                  <QRCodeSVG value={USDT_TRC20_ADDRESS} size={150} />
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
            <h3 className="font-semibold text-yellow-800 mb-2">重要な注意事項</h3>
            <ul className="text-sm text-yellow-700 space-y-1">
              <li>• 正確な金額（${purchase?.amount_usd.toFixed(2)} USDT）をお送りください</li>
              <li>• 送金確認後、24時間以内にNFTをお送りします</li>
              <li>• 確認メールをお送りしましたのでご確認ください</li>
              <li>• ご不明な点がございましたらサポートまでお問い合わせください</li>
            </ul>
          </div>

          <div className="text-center">
            <Link href="/dashboard">
              <Button size="lg">ダッシュボードに戻る</Button>
            </Link>
          </div>
        </div>
      </main>
    </div>
  )
}
