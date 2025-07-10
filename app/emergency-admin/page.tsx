"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"

export default function EmergencyAdminPage() {
  const router = useRouter()

  useEffect(() => {
    // 緊急管理者ログイン - チェックなしで直接管理画面へ
    const handleEmergencyLogin = async () => {
      try {
        // 現在のユーザーを確認
        const { data: { user } } = await supabase.auth.getUser()
        
        if (user) {
          // 既にログイン済みなら管理画面へ
          router.push("/admin")
        } else {
          // ログインしていない場合はログインページへ
          router.push("/login")
        }
      } catch (error) {
        console.error("Emergency login error:", error)
        router.push("/login")
      }
    }

    handleEmergencyLogin()
  }, [router])

  return (
    <div className="min-h-screen bg-gray-900 text-white flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-2xl font-bold mb-4">緊急管理者アクセス</h1>
        <p className="text-gray-400">管理画面にリダイレクト中...</p>
      </div>
    </div>
  )
}