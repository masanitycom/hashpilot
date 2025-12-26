"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Shield, ArrowLeft, Settings, Save, RefreshCw, Copy } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Switch } from "@/components/ui/switch"
import { Alert, AlertDescription } from "@/components/ui/alert"

export default function AdminSettingsPage() {
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [usdtAddressBep20, setUsdtAddressBep20] = useState("")
  const [usdtAddressTrc20, setUsdtAddressTrc20] = useState("")
  const [nftPrice, setNftPrice] = useState("1100")
  const [isSaving, setIsSaving] = useState(false)
  const [message, setMessage] = useState("")
  const [error, setError] = useState("")
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      console.log("Checking admin access for:", user.email)

      // 緊急対応: basarasystems@gmail.com または support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        await fetchSettings()
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      console.log("Admin check result:", adminCheck, adminError)

      if (adminError) {
        console.error("Admin check error:", adminError)
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          await fetchSettings()
          return
        }
        
        setError("管理者権限の確認中にエラーが発生しました")
        return
      }

      if (!adminCheck) {
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          await fetchSettings()
          return
        }
        
        setError("管理者権限がありません")
        setTimeout(() => {
          router.push("/dashboard")
        }, 3000)
        return
      }

      setIsAdmin(true)
      await fetchSettings()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  const fetchSettings = async () => {
    try {
      // システム設定を取得
      const { data: settings, error } = await supabase.from("system_settings").select("*").single()

      if (error && error.code !== "PGRST116") {
        console.error("Settings fetch error:", error)
        return
      }

      if (settings) {
        setUsdtAddressBep20(settings.usdt_address_bep20 || "")
        setUsdtAddressTrc20(settings.usdt_address_trc20 || "")
        setNftPrice(settings.nft_price?.toString() || "1100")
      }
    } catch (error) {
      console.error("Error fetching settings:", error)
    }
  }

  const saveSettings = async () => {
    setIsSaving(true)
    setMessage("")
    setError("")

    try {
      const settingsData = {
        usdt_address_bep20: usdtAddressBep20,
        usdt_address_trc20: usdtAddressTrc20,
        nft_price: Number.parseFloat(nftPrice),
        updated_at: new Date().toISOString(),
      }

      // 既存の設定があるかチェック
      const { data: existingSettings } = await supabase.from("system_settings").select("id").single()

      if (existingSettings) {
        // 既存の設定を更新
        const { error } = await supabase.from("system_settings").update(settingsData).eq("id", existingSettings.id)

        if (error) throw error
      } else {
        // 新しい設定を作成
        const { error } = await supabase.from("system_settings").insert({
          id: 1,
          ...settingsData,
        })

        if (error) throw error
      }

      setMessage("設定が保存されました。QRコードも自動更新されます。")
    } catch (error) {
      console.error("Error saving settings:", error)
      setError("設定の保存中にエラーが発生しました")
    } finally {
      setIsSaving(false)
    }
  }

  const copyToClipboard = async (text: string, type: string) => {
    try {
      await navigator.clipboard.writeText(text)
      setMessage(`${type}アドレスをコピーしました`)
    } catch (error) {
      setError("コピーに失敗しました")
    }
  }

  const generateQRCode = (address: string, network: string) => {
    if (!address) return ""
    return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(address)}&format=png`
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">設定を読み込み中...</p>
        </div>
      </div>
    )
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400 flex items-center">
              <Shield className="w-5 h-5 mr-2" />
              アクセス拒否
            </CardTitle>
          </CardHeader>
          <CardContent className="text-white">
            <p>{error || "管理者権限が必要です。"}</p>
            <Button onClick={() => router.push("/dashboard")} className="mt-4 w-full">
              ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black">
      <header className="bg-gray-800 shadow-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Shield className="w-8 h-8 text-blue-400" />
              <span className="text-xl font-bold text-white">HASH PILOT 管理者</span>
            </div>
            <Button variant="outline" size="sm" onClick={() => router.push("/admin")}>
              <ArrowLeft className="w-4 h-4 mr-2" />
              管理者ダッシュボードに戻る
            </Button>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">システム設定</h1>
          <p className="text-gray-400">HASH PILOTシステムの基本設定</p>
        </div>

        {message && (
          <Alert className="mb-6 bg-green-900 border-green-700">
            <AlertDescription className="text-green-200">{message}</AlertDescription>
          </Alert>
        )}

        {error && (
          <Alert className="mb-6 bg-red-900 border-red-700">
            <AlertDescription className="text-red-200">{error}</AlertDescription>
          </Alert>
        )}

        <Tabs defaultValue="payment" className="w-full">
          <TabsList className="bg-gray-800 border-gray-700">
            <TabsTrigger value="payment" className="data-[state=active]:bg-gray-700">
              支払い設定
            </TabsTrigger>
            <TabsTrigger value="general" className="data-[state=active]:bg-gray-700">
              基本設定
            </TabsTrigger>
            <TabsTrigger value="security" className="data-[state=active]:bg-gray-700">
              セキュリティ
            </TabsTrigger>
          </TabsList>

          <TabsContent value="payment" className="mt-6">
            <Card className="bg-gray-800 border-gray-700 text-white">
              <CardHeader>
                <CardTitle>USDT送金アドレス設定</CardTitle>
                <CardDescription className="text-gray-400">
                  ユーザーがUSDTを送金するアドレスを設定します。変更するとQRコードも自動更新されます。
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-8">
                {/* BEP20アドレス設定 */}
                <div className="space-y-4">
                  <div className="flex items-center space-x-2">
                    <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
                    <Label htmlFor="usdt-bep20" className="text-lg font-semibold">
                      BEP20 (Binance Smart Chain)
                    </Label>
                  </div>
                  <div className="flex space-x-2">
                    <Input
                      id="usdt-bep20"
                      value={usdtAddressBep20}
                      onChange={(e) => setUsdtAddressBep20(e.target.value)}
                      className="bg-gray-700 border-gray-600 text-white flex-1"
                      placeholder="0x..."
                    />
                    <Button
                      onClick={() => copyToClipboard(usdtAddressBep20, "BEP20")}
                      variant="outline"
                      size="sm"
                      className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                      disabled={!usdtAddressBep20}
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  </div>
                  {usdtAddressBep20 && (
                    <div className="flex items-center space-x-4 p-4 bg-gray-700 rounded-lg">
                      <div className="flex-1">
                        <p className="text-sm text-gray-300 mb-2">BEP20 QRコードプレビュー:</p>
                        <img
                          src={generateQRCode(usdtAddressBep20, "BEP20") || "/placeholder.svg"}
                          alt="BEP20 QR Code"
                          className="w-32 h-32 border border-gray-600 rounded"
                        />
                      </div>
                      <div className="text-sm text-gray-400">
                        <p>ネットワーク: Binance Smart Chain</p>
                        <p>手数料: 低い</p>
                        <p>確認時間: 約3分</p>
                      </div>
                    </div>
                  )}
                </div>

                {/* TRC20アドレス設定 */}
                <div className="space-y-4">
                  <div className="flex items-center space-x-2">
                    <div className="w-3 h-3 bg-red-500 rounded-full"></div>
                    <Label htmlFor="usdt-trc20" className="text-lg font-semibold">
                      TRC20 (TRON Network)
                    </Label>
                  </div>
                  <div className="flex space-x-2">
                    <Input
                      id="usdt-trc20"
                      value={usdtAddressTrc20}
                      onChange={(e) => setUsdtAddressTrc20(e.target.value)}
                      className="bg-gray-700 border-gray-600 text-white flex-1"
                      placeholder="T..."
                    />
                    <Button
                      onClick={() => copyToClipboard(usdtAddressTrc20, "TRC20")}
                      variant="outline"
                      size="sm"
                      className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                      disabled={!usdtAddressTrc20}
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  </div>
                  {usdtAddressTrc20 && (
                    <div className="flex items-center space-x-4 p-4 bg-gray-700 rounded-lg">
                      <div className="flex-1">
                        <p className="text-sm text-gray-300 mb-2">TRC20 QRコードプレビュー:</p>
                        <img
                          src={generateQRCode(usdtAddressTrc20, "TRC20") || "/placeholder.svg"}
                          alt="TRC20 QR Code"
                          className="w-32 h-32 border border-gray-600 rounded"
                        />
                      </div>
                      <div className="text-sm text-gray-400">
                        <p>ネットワーク: TRON</p>
                        <p>手数料: 無料</p>
                        <p>確認時間: 約1分</p>
                      </div>
                    </div>
                  )}
                </div>

                <Button onClick={saveSettings} disabled={isSaving} className="bg-blue-600 hover:bg-blue-700 text-white">
                  {isSaving ? (
                    <>
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                      保存中...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4 mr-2" />
                      設定を保存
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="general" className="mt-6">
            <Card className="bg-gray-800 border-gray-700 text-white">
              <CardHeader>
                <CardTitle className="flex items-center">
                  <Settings className="w-5 h-5 mr-2" />
                  基本設定
                </CardTitle>
                <CardDescription className="text-gray-400">システムの基本的な設定を管理します</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="space-y-2">
                  <Label htmlFor="nft-price">NFT価格 (USD)</Label>
                  <Input
                    id="nft-price"
                    type="number"
                    value={nftPrice}
                    onChange={(e) => setNftPrice(e.target.value)}
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                  <p className="text-sm text-gray-400">NFTの販売価格をUSDで設定します</p>
                </div>

                <div className="flex items-center space-x-2">
                  <Switch id="maintenance-mode" />
                  <Label htmlFor="maintenance-mode">メンテナンスモード</Label>
                </div>

                <Button onClick={saveSettings} disabled={isSaving} className="bg-blue-600 hover:bg-blue-700 text-white">
                  {isSaving ? (
                    <>
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                      保存中...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4 mr-2" />
                      設定を保存
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="security" className="mt-6">
            <Card className="bg-gray-800 border-gray-700 text-white">
              <CardHeader>
                <CardTitle>セキュリティ設定</CardTitle>
                <CardDescription className="text-gray-400">セキュリティ関連の設定を管理します</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="flex items-center space-x-2">
                  <Switch id="enable-2fa" />
                  <Label htmlFor="enable-2fa">二要素認証を有効化</Label>
                </div>

                <div className="flex items-center space-x-2">
                  <Switch id="ip-restriction" />
                  <Label htmlFor="ip-restriction">IP制限を有効化</Label>
                </div>

                <Button onClick={saveSettings} disabled={isSaving} className="bg-blue-600 hover:bg-blue-700 text-white">
                  {isSaving ? (
                    <>
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                      保存中...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4 mr-2" />
                      設定を保存
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>
    </div>
  )
}
