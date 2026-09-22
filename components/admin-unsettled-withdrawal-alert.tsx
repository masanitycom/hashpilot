"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { AlertTriangle, X } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface UnsettledMonth {
  month: string        // 'YYYY-MM'
  count: number
  amount: number
}

export interface UnsettledSummary {
  months: UnsettledMonth[]
  totalCount: number
  totalAmount: number
}

/**
 * 前月以前に「未清算」の monthly_withdrawals が残っているかを調べる。
 *
 * 未清算 = status が completed でなく、notes に繰越理由も書かれていないレコード。
 *
 * status だけでは判定できない:
 *   2026年7月分は 434件中 428件を送金しており、on_hold（タスク未完了）の
 *   ユーザーにも送金している。つまり pending だけを見ると検知漏れする。
 *
 * 意図的に送金しなかったユーザー（CoinW UID未設定・最低出金額未満など）は
 * notes に「翌月分に繰越」と記載する運用なので、notes に「繰越」を含むものだけを
 * 正常として除外する。
 *
 * ※ 「notes が空でないもの」を除外にしてはいけない。修正スクリプト等が別用途で
 *   notes を書き込むことがあり、それらまで警告対象から外れてしまう
 *   （2026-09-02 の8月分修正で全434件に notes が入った実績あり）。
 *
 * 未清算のまま月末処理が走ると available_usdt が減っていないため、
 * 翌月分の出金額に前月分が丸ごと乗る（＝二重払いのリスク）。
 */
export async function fetchUnsettledWithdrawals(
  // この月初日より前の pending を対象にする（省略時は今月初日 ＝「前月以前」）
  beforeMonthStart?: string,
): Promise<UnsettledSummary> {
  const now = new Date()
  const cutoff =
    beforeMonthStart || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`

  const { data, error } = await supabase
    .from("monthly_withdrawals")
    .select("withdrawal_month, total_amount, notes")
    .in("status", ["pending", "on_hold"])
    .lt("withdrawal_month", cutoff)

  if (error || !data) {
    return { months: [], totalCount: 0, totalAmount: 0 }
  }

  const map = new Map<string, UnsettledMonth>()
  data.forEach((row: any) => {
    // notes に「繰越」と書かれているものは意図的な未送金なので除外
    if (String(row.notes || "").includes("繰越")) return

    const key = String(row.withdrawal_month).slice(0, 7)
    const entry = map.get(key) || { month: key, count: 0, amount: 0 }
    entry.count += 1
    entry.amount += Number(row.total_amount || 0)
    map.set(key, entry)
  })

  const months = Array.from(map.values()).sort((a, b) => a.month.localeCompare(b.month))

  return {
    months,
    totalCount: months.reduce((s, m) => s + m.count, 0),
    totalAmount: months.reduce((s, m) => s + m.amount, 0),
  }
}

const DISMISS_KEY = "unsettled_withdrawal_alert_dismissed"

export function AdminUnsettledWithdrawalAlert() {
  const [summary, setSummary] = useState<UnsettledSummary | null>(null)
  // モーダルを閉じたらこのタブを閉じるまで再表示しない（ページ遷移・リロードごとに出ると作業にならない）
  const [modalDismissed, setModalDismissed] = useState(false)
  const [bannerHidden, setBannerHidden] = useState(false)

  useEffect(() => {
    try {
      if (sessionStorage.getItem(DISMISS_KEY)) setModalDismissed(true)
    } catch {}
    fetchUnsettledWithdrawals().then(setSummary)
  }, [])

  if (!summary || summary.totalCount === 0) {
    return null
  }

  const dismissModal = () => {
    setModalDismissed(true)
    try {
      sessionStorage.setItem(DISMISS_KEY, "1")
    } catch {}
  }

  const dayOfMonth = new Date().getDate()
  // 20日以降は月末処理が近いので、バナーに加えてモーダルでも知らせる
  const isCritical = dayOfMonth >= 20

  const monthLabels = summary.months
    .map((m) => `${Number(m.month.slice(5, 7))}月分 ${m.count}件 / $${m.amount.toFixed(2)}`)
    .join("、")

  const banner = bannerHidden ? null : (
    <div className="bg-red-900/40 border border-red-600 rounded-md px-3 py-2 mb-4 text-sm">
      <div className="flex items-center gap-2">
        <AlertTriangle className="h-4 w-4 text-red-400 shrink-0" />
        <p className="flex-1 min-w-0 text-red-100">
          <span className="font-bold text-red-200">送金完了処理が未実施</span>
          <span className="ml-1">（{monthLabels}）</span>
        </p>
        <Link
          href="/admin/withdrawals"
          className="shrink-0 bg-red-600 hover:bg-red-700 text-white text-xs font-bold px-2 py-1 rounded"
        >
          出金管理へ
        </Link>
        <button
          onClick={() => setBannerHidden(true)}
          className="shrink-0 p-1 text-red-300 hover:text-white"
          aria-label="閉じる"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  )

  if (!isCritical || modalDismissed) {
    return banner
  }

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4" onClick={dismissModal}>
        <div
          className="bg-gray-900 border-2 border-red-600 rounded-lg max-w-md w-full max-h-[85vh] overflow-y-auto p-4 relative"
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={dismissModal}
            className="absolute top-2 right-2 p-1 text-gray-400 hover:text-white"
            aria-label="閉じる"
          >
            <X className="h-5 w-5" />
          </button>

          <div className="flex items-center gap-2 mb-3 pr-6">
            <AlertTriangle className="h-5 w-5 text-red-500 shrink-0" />
            <h2 className="text-base font-bold text-red-400">送金完了処理が未実施です</h2>
          </div>

          <div className="bg-black/40 rounded p-2 mb-3 text-sm">
            {summary.months.map((m) => (
              <div key={m.month} className="flex justify-between text-white py-0.5">
                <span>
                  {m.month.slice(0, 4)}年{m.month.slice(5, 7)}月分
                </span>
                <span className="font-mono">
                  {m.count}件 / ${m.amount.toFixed(2)}
                </span>
              </div>
            ))}
          </div>

          <p className="text-red-100 text-xs mb-2">
            送金済みなら出金管理画面で「完了済みにする」を実行してください。未処理のまま月末の日利を入力すると、
            <span className="font-bold">翌月分に前月分が上乗せされ二重払い</span>になります（月末日の日利入力はブロックされます）。
          </p>
          <p className="text-yellow-300 text-xs mb-3">
            ※ 意図的に送金しない場合は notes に「翌月分に繰越」と記載すれば警告から外れます。
          </p>

          <div className="flex gap-2">
            <Link
              href="/admin/withdrawals"
              onClick={dismissModal}
              className="flex-1 bg-red-600 hover:bg-red-700 text-white text-sm font-bold px-3 py-2 rounded text-center"
            >
              出金管理画面へ
            </Link>
            <button
              onClick={dismissModal}
              className="px-3 py-2 rounded border border-gray-600 text-gray-300 text-sm hover:bg-gray-800"
            >
              閉じる
            </button>
          </div>
        </div>
      </div>
      {banner}
    </>
  )
}
