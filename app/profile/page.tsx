"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { User } from "@supabase/supabase-js"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Loader2, Edit, Save, X, Copy, Check, Share2, QrCode, User as UserIcon, LogOut, Home, Settings, TrendingUp, Menu } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { MonthlyWithdrawalAlert } from "@/components/monthly-withdrawal-alert"
import Link from "next/link"
import { checkUserNFTPurchase } from "@/lib/check-nft-purchase"

interface UserProfile {
  id: string
  user_id: string
  email: string
  coinw_uid: string
  created_at: string
  total_purchases: number
  referral_count: number
}

export default function ProfilePage() {
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")
  const [editForm, setEditForm] = useState({
    coinw_uid: "",
  })
  const [showQR, setShowQR] = useState(false)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  useEffect(() => {
    fetchProfile()
  }, [])

  // モバイルメニューの外側クリックで閉じる
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (mobileMenuOpen && !(event.target as Element).closest('header')) {
        setMobileMenuOpen(false)
      }
    }

    document.addEventListener('click', handleClickOutside)
    return () => document.removeEventListener('click', handleClickOutside)
  }, [mobileMenuOpen])

  const fetchProfile = async () => {
    try {
      setLoading(true)
      setError("")

      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        setError("ログインが必要です")
        return
      }

      // basarasystems@gmail.com は管理画面にリダイレクト
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        router.push("/admin")
        return
      }

      const { data: userData, error: userError } = await supabase
        .from("users")
        .select(`
          id,
          user_id,
          email,
          coinw_uid,
          created_at,
          total_purchases
        `)
        .eq("id", user.id)
        .single()

      if (userError) throw userError

      // NFT購入チェック
      const { hasApprovedPurchase } = await checkUserNFTPurchase(userData.user_id)
      if (!hasApprovedPurchase) {
        console.log("User has no approved NFT purchase, redirecting to /nft")
        router.push("/nft")
        return
      }

      // 紹介者数を取得
      const { count: referralCount } = await supabase
        .from("users")
        .select("id", { count: "exact", head: true })
        .eq("referrer_user_id", userData.user_id)

      const profileData = {
        ...userData,
        referral_count: referralCount || 0,
      }

      setProfile(profileData)
      setEditForm({
        coinw_uid: userData.coinw_uid || "",
      })
    } catch (error: any) {
      console.error("Profile fetch error:", error)
      setError(`プロフィールの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const updateProfile = async () => {
    try {
      setSaving(true)
      setError("")
      setSuccess("")

      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        setError("ログインが必要です")
        return
      }

      const { error: updateError } = await supabase
        .from("users")
        .update({
          coinw_uid: editForm.coinw_uid,
        })
        .eq("id", user.id)

      if (updateError) throw updateError

      setSuccess("プロフィールを更新しました")
      setEditing(false)
      await fetchProfile()
    } catch (error: any) {
      setError(`更新に失敗しました: ${error.message}`)
    } finally {
      setSaving(false)
    }
  }

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text)
    setSuccess(`${label}をコピーしました`)
    setTimeout(() => setSuccess(""), 2000)
  }

  const getReferralLink = () => {
    if (!profile?.user_id) return ""
    return `https://hashpilot.net/register?ref=${profile.user_id}`
  }

  const generateQRCode = (text: string) => {
    // Simple QR code generation using Google Charts API
    const encodedText = encodeURIComponent(text)
    return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodedText}`
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push("/")
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-blue-400" />
      </div>
    )
  }

  if (error && !profile) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
        <Card className="bg-red-900/20 border-red-500/50 max-w-md w-full mx-4">
          <CardContent className="p-6 text-center">
            <div className="text-red-400 mb-4">エラー</div>
            <div className="text-white mb-4">{error}</div>
            <Button onClick={fetchProfile} variant="outline" className="bg-transparent border-red-500/50 text-red-400 hover:bg-red-900/20">
              再試行
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black">
      {/* Header */}
      <header className="bg-gray-900/80 backdrop-blur-sm border-b border-gray-700/50 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-4">
              <Link href="/dashboard" className="flex items-center">
                <img 
                  src="/images/hash-pilot-logo.png" 
                  alt="HashPilot"
                  className="h-12 rounded-xl shadow-lg hover:shadow-xl transition-shadow duration-300"
                />
              </Link>
              <Badge variant="outline" className="hidden sm:block text-blue-400 border-blue-400/50">
                Profile
              </Badge>
            </div>
            
            <nav className="hidden md:flex items-center space-x-4">
              <Link href="/dashboard">
                <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white hover:bg-gray-700/50">
                  <Home className="h-4 w-4 mr-2" />
                  ダッシュボード
                </Button>
              </Link>
              <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white hover:bg-gray-700/50">
                <UserIcon className="h-4 w-4 mr-2" />
                プロフィール
              </Button>
              <Button onClick={handleLogout} variant="ghost" size="sm" className="text-red-400 hover:text-red-300 hover:bg-red-900/20">
                <LogOut className="h-4 w-4 mr-2" />
                ログアウト
              </Button>
            </nav>

            <div className="md:hidden">
              <Button 
                variant="ghost" 
                size="sm" 
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                className="text-gray-300 hover:text-white hover:bg-gray-700/50"
              >
                <Menu className="h-5 w-5" />
              </Button>
            </div>
          </div>
        </div>

        {/* Mobile Menu */}
        <div className={`md:hidden bg-gray-900/95 backdrop-blur-sm border-t border-gray-700/50 transition-all duration-300 ease-in-out ${mobileMenuOpen ? 'max-h-48 opacity-100' : 'max-h-0 opacity-0 overflow-hidden'}`}>
          <div className="px-4 py-3 space-y-2">
            <Link href="/dashboard">
              <Button 
                variant="ghost" 
                size="sm" 
                className="w-full justify-start text-gray-300 hover:text-white hover:bg-gray-700/50 transition-colors"
                onClick={() => setMobileMenuOpen(false)}
              >
                <Home className="h-4 w-4 mr-3" />
                ダッシュボード
              </Button>
            </Link>
            <Button 
              variant="ghost" 
              size="sm" 
              className="w-full justify-start text-blue-400 bg-blue-900/20 cursor-default"
              onClick={() => setMobileMenuOpen(false)}
            >
              <UserIcon className="h-4 w-4 mr-3" />
              プロフィール
            </Button>
            <Button 
              onClick={() => {
                handleLogout()
                setMobileMenuOpen(false)
              }}
              variant="ghost" 
              size="sm" 
              className="w-full justify-start text-red-400 hover:text-red-300 hover:bg-red-900/20 transition-colors"
            >
              <LogOut className="h-4 w-4 mr-3" />
              ログアウト
            </Button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-4xl font-bold bg-gradient-to-r from-white to-gray-300 bg-clip-text text-transparent mb-2">
            プロフィール設定
          </h1>
          <p className="text-gray-400 text-lg">アカウント情報と紹介設定を管理できます</p>
        </div>

        {error && (
          <Card className="bg-red-900/20 border-red-500/50">
            <CardContent className="p-4 text-red-400 text-center">
              {error}
            </CardContent>
          </Card>
        )}

        {success && (
          <Card className="bg-green-900/20 border-green-500/50">
            <CardContent className="p-4 text-green-400 text-center">
              {success}
            </CardContent>
          </Card>
        )}

        <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
          {/* 基本情報 */}
          <div className="xl:col-span-2">
            <Card className="bg-gradient-to-br from-gray-900/90 to-gray-800/90 border-gray-700/50 backdrop-blur-sm">
              <CardHeader className="pb-4">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-2xl font-bold text-white flex items-center space-x-3">
                    <Settings className="h-6 w-6 text-blue-400" />
                    <span>基本情報</span>
                  </CardTitle>
                  <Button
                    onClick={() => editing ? setEditing(false) : setEditing(true)}
                    variant={editing ? "destructive" : "default"}
                    size="sm"
                    className={editing ? "bg-red-600 hover:bg-red-700" : "bg-blue-600 hover:bg-blue-700"}
                  >
                    {editing ? (
                      <>
                        <X className="h-4 w-4 mr-2" />
                        キャンセル
                      </>
                    ) : (
                      <>
                        <Edit className="h-4 w-4 mr-2" />
                        編集
                      </>
                    )}
                  </Button>
                </div>
              </CardHeader>
              <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <Label className="text-sm font-medium text-gray-300">ユーザーID</Label>
                <div className="flex items-center space-x-2">
                  <div className="flex-1 bg-gray-800/50 border border-gray-600/50 rounded-lg p-3 font-mono text-white">
                    {profile?.user_id}
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => copyToClipboard(profile?.user_id || "", "ユーザーID")}
                    className="text-gray-300 border-gray-600 hover:bg-gray-700 bg-transparent shrink-0"
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-sm font-medium text-gray-300">メールアドレス</Label>
                <div className="bg-gray-800/50 border border-gray-600/50 rounded-lg p-3 text-white">
                  {profile?.email}
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-sm font-medium text-gray-300">CoinW UID</Label>
                {editing ? (
                  <Input
                    value={editForm.coinw_uid}
                    onChange={(e) => setEditForm({ ...editForm, coinw_uid: e.target.value })}
                    className="bg-gray-800/50 border-gray-600/50 text-white placeholder-gray-400 focus:border-blue-500 focus:ring-blue-500/20"
                    placeholder="CoinW UIDを入力"
                  />
                ) : (
                  <div className="bg-gray-800/50 border border-gray-600/50 rounded-lg p-3 text-white">
                    {profile?.coinw_uid || "未設定"}
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label className="text-sm font-medium text-gray-300">総投資額</Label>
                <div className="bg-gradient-to-r from-green-900/20 to-emerald-900/20 border border-green-600/30 rounded-lg p-3">
                  <div className="text-2xl font-bold text-green-400">
                    ${(profile?.total_purchases || 0).toLocaleString()}
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-sm font-medium text-gray-300">紹介者数</Label>
                <div className="bg-gradient-to-r from-blue-900/20 to-purple-900/20 border border-blue-600/30 rounded-lg p-3">
                  <div className="text-2xl font-bold text-blue-400">
                    {profile?.referral_count || 0}人
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-sm font-medium text-gray-300">登録日</Label>
                <div className="bg-gray-800/50 border border-gray-600/50 rounded-lg p-3 text-white">
                  {profile?.created_at ? new Date(profile.created_at).toLocaleDateString('ja-JP') : "不明"}
                </div>
              </div>
            </div>

            {/* 月末出金アラート */}
            <div className="border-t border-gray-600/30 pt-6">
              <MonthlyWithdrawalAlert 
                userId={profile?.user_id || ""} 
                hasCoinwUid={!!profile?.coinw_uid}
              />
            </div>

            {editing && (
              <div className="flex space-x-3 pt-6 border-t border-gray-600/30">
                <Button
                  onClick={updateProfile}
                  disabled={saving}
                  className="bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 text-white font-medium px-6 py-2"
                >
                  {saving ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                      保存中...
                    </>
                  ) : (
                    <>
                      <Save className="h-4 w-4 mr-2" />
                      変更を保存
                    </>
                  )}
                </Button>
                <Button
                  onClick={() => setEditing(false)}
                  variant="outline"
                  className="bg-transparent border-gray-600 text-gray-300 hover:bg-gray-700 hover:text-white px-6 py-2"
                >
                  <X className="h-4 w-4 mr-2" />
                  キャンセル
                </Button>
              </div>
            )}
              </CardContent>
            </Card>
          </div>

          {/* 紹介リンク & QRコード */}
          <div className="space-y-6">
            <Card className="bg-gray-900/80 border-gray-700/50 backdrop-blur-sm">
              <CardHeader className="pb-4">
                <CardTitle className="text-xl font-bold text-white flex items-center space-x-2">
                  <Share2 className="h-5 w-5 text-blue-400" />
                  <span>紹介リンク</span>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  <Label className="text-sm font-medium text-gray-300">あなたの専用リンク</Label>
                  <div className="bg-gray-800 border border-gray-600 rounded-lg p-4">
                    <div className="text-xs text-gray-400 mb-2">URL:</div>
                    <div className="text-white text-sm break-all font-mono leading-relaxed">
                      {getReferralLink()}
                    </div>
                  </div>
                  <Button
                    onClick={() => copyToClipboard(getReferralLink(), "紹介リンク")}
                    className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3"
                  >
                    <Copy className="h-4 w-4 mr-2" />
                    リンクをコピー
                  </Button>
                </div>
                
                <div className="text-sm text-gray-400 text-center px-2">
                  このリンクから登録されたユーザーがあなたの紹介者になります
                </div>
              </CardContent>
            </Card>

            <Card className="bg-gray-900/80 border-gray-700/50 backdrop-blur-sm">
              <CardHeader className="pb-4">
                <CardTitle className="text-xl font-bold text-white flex items-center space-x-2">
                  <QrCode className="h-5 w-5 text-green-400" />
                  <span>QRコード</span>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="text-center">
                  <div className="bg-white rounded-xl p-6 inline-block shadow-xl border-4 border-gray-600">
                    <img 
                      src={generateQRCode(getReferralLink())} 
                      alt="紹介リンクQRコード"
                      className="w-48 h-48 rounded-lg"
                    />
                  </div>
                </div>
                <div className="text-sm text-gray-400 text-center px-2">
                  QRコードをスキャンして簡単に紹介リンクにアクセスできます
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

      </div>
    </div>
  )
}