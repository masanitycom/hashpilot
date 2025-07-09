"use client"

import type React from "react"

import { useState } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { supabase } from "@/lib/supabase"

export default function LoginForm() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) {
        console.error("Login error:", error)
        setError(error.message)
        return
      }

      if (data.session) {
        router.push("/dashboard")
        router.refresh()
      }
    } catch (err: any) {
      console.error("Login exception:", err)
      setError("ログイン処理中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && <div className="bg-red-900/50 border border-red-500 text-red-300 p-3 rounded-md">{error}</div>}

      <div>
        <label htmlFor="email" className="block text-sm font-medium text-gray-300 mb-1">
          メールアドレス
        </label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-md text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div>
        <label htmlFor="password" className="block text-sm font-medium text-gray-300 mb-1">
          パスワード
        </label>
        <input
          id="password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-md text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div className="flex items-center justify-between">
        <Link href="/reset-password" className="text-sm text-blue-400 hover:text-blue-300">
          パスワードをお忘れですか？
        </Link>
      </div>

      <button
        type="submit"
        disabled={loading}
        className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {loading ? "ログイン中..." : "ログイン"}
      </button>

      <div className="text-center text-sm text-gray-400">
        アカウントをお持ちでない場合は{" "}
        <Link href="/register" className="text-blue-400 hover:text-blue-300">
          新規登録
        </Link>
        してください
      </div>
    </form>
  )
}
