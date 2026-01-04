"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Home, Coins } from "lucide-react"
import Link from "next/link"
import { supabase } from "@/lib/supabase"
import { NftBuybackRequest } from "@/components/nft-buyback-request"
import { checkUserNFTPurchase } from "@/lib/check-nft-purchase"

export default function NftBuybackPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const router = useRouter()

  useEffect(() => {
    checkUserAccess()
  }, [])

  const checkUserAccess = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push("/login")
        return
      }

      // basarasystems@gmail.com は管理画面にリダイレクト
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        router.push("/admin")
        return
      }

      setUser(user)

      // ユーザーデータを取得
      const { data: userInfo, error } = await supabase
        .from("users")
        .select("user_id, email, full_name")
        .eq("id", user.id)
        .single()

      if (error) {
        console.error("Error fetching user data:", error)
        router.push("/dashboard")
        return
      }

      // NFT購入チェック
      const { hasApprovedPurchase } = await checkUserNFTPurchase(userInfo.user_id)
      if (!hasApprovedPurchase) {
        console.log("User has no approved NFT purchase, redirecting to /nft")
        router.push("/dashboard")
        return
      }

      setUserData(userInfo)
    } catch (error) {
      console.error("Error checking user access:", error)
      router.push("/login")
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <div className="text-white">読み込み中...</div>
      </div>
    )
  }

  if (!userData) {
    return null
  }

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700 sticky top-0 z-50">
        <div className="container mx-auto px-4 py-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Link href="/dashboard">
                <img
                  src="/images/hash-pilot-logo.png"
                  alt="HASH PILOT"
                  className="h-8 rounded-lg"
                />
              </Link>
              <div className="flex items-center space-x-2">
                <Coins className="h-5 w-5 text-yellow-400" />
                <h1 className="text-lg font-bold text-white">NFT買取</h1>
              </div>
            </div>
            <Link href="/dashboard">
              <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white px-2">
                <Home className="h-4 w-4" />
                <span className="hidden sm:inline ml-1">戻る</span>
              </Button>
            </Link>
          </div>
        </div>
      </header>

      <div className="container mx-auto p-4 md:p-6 space-y-6">
        {/* 説明 */}
        <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-4">
          <p className="text-sm text-gray-300">手動購入NFTは1000ドル - (そのNFTの利益 ÷ 2)、自動購入NFTは500ドル - (そのNFTの利益 ÷ 2)で買い取り可能です。</p>
        </div>

        {/* NFT買い取り申請コンポーネント */}
        <NftBuybackRequest userId={userData.user_id} />
      </div>
    </div>
  )
}