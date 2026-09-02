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

export function AdminUnsettledWithdrawalAlert() {
  const [summary, setSummary] = useState<UnsettledSummary | null>(null)
  const [dismissed, setDismissed] = useState(false)

  useEffect(() => {
    fetchUnsettledWithdrawals().then(setSummary)
  }, [])

  if (!summary || summary.totalCount === 0) {
    return null
  }

  const dayOfMonth = new Date().getDate()
  // 20日以降は月末処理が近いので、バナーではなく全画面モーダルで止める
  const isCritical = dayOfMonth >= 20

  const monthLabels = summary.months
    .map((m) => `${m.month.slice(0, 4)}年${m.month.slice(5, 7)}月分（${m.count}件 / $${m.amount.toFixed(2)}）`)
    .join("、")

  const banner = (
    <div className="bg-red-900/40 border-2 border-red-600 rounded-lg p-4 mb-6">
      <div className="flex items-start gap-3">
        <AlertTriangle className="h-6 w-6 text-red-400 shrink-0 mt-0.5" />
        <div className="flex-1">
          <p className="text-red-200 font-bold text-lg">送金完了処理が未実施です</p>
          <p className="text-red-100 mt-1">{monthLabels} の送金完了処理が済んでいません。</p>
          <p className="text-red-100 mt-2 text-sm">
            送金済みなら、月末までに必ず出金管理画面で「完了済みにする」を実行してください。
            未処理のまま月末の日利を入力すると、翌月分の出金額に前月分が上乗せされ二重払いになります。
          </p>
          <Link
            href="/admin/withdrawals"
            className="inline-block mt-3 bg-red-600 hover:bg-red-700 text-white font-bold px-4 py-2 rounded"
          >
            出金管理画面へ
          </Link>
        </div>
      </div>
    </div>
  )

  if (!isCritical || dismissed) {
    return banner
  }

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4">
        <div className="bg-gray-900 border-4 border-red-600 rounded-xl max-w-2xl w-full p-6 relative">
          <button
            onClick={() => setDismissed(true)}
            className="absolute top-3 right-3 text-gray-400 hover:text-white"
            aria-label="閉じる"
          >
            <X className="h-6 w-6" />
          </button>

          <div className="flex items-center gap-3 mb-4">
            <AlertTriangle className="h-10 w-10 text-red-500" />
            <h2 className="text-2xl font-bold text-red-400">送金完了処理が未実施です</h2>
          </div>

          <p className="text-white text-lg mb-4">
            以下の出金の送金完了処理が済んでいません。
          </p>

          <div className="bg-black/40 rounded-lg p-4 mb-4">
            {summary.months.map((m) => (
              <div key={m.month} className="flex justify-between text-white py-1">
                <span>
                  {m.month.slice(0, 4)}年{m.month.slice(5, 7)}月分
                </span>
                <span className="font-mono">
                  {m.count}件 / ${m.amount.toFixed(2)}
                </span>
              </div>
            ))}
            <div className="border-t border-gray-600 mt-2 pt-2 flex justify-between text-red-300 font-bold">
              <span>合計</span>
              <span className="font-mono">
                {summary.totalCount}件 / ${summary.totalAmount.toFixed(2)}
              </span>
            </div>
          </div>

          <div className="bg-red-950/60 border border-red-700 rounded-lg p-4 mb-4">
            <p className="text-red-200 font-bold mb-1">このまま月末を迎えると何が起きるか</p>
            <p className="text-red-100 text-sm">
              完了処理をしないと available_usdt から出金額が引かれません。その状態で月末の日利を入力すると
              月末処理が自動で走り、<span className="font-bold">翌月分の出金額に前月分がそのまま上乗せ</span>されます。
              気づかず送金すると前月分の二重払いになります。
            </p>
          </div>

          <p className="text-yellow-300 text-sm mb-4">
            ※ 送金済みなら「完了済みにする」を実行してください。意図的に送金しない場合は notes に「翌月分に繰越」と記載すれば、この警告から除外されます。
            <br />※ 未処理のままだと月末日の日利入力がブロックされます。
          </p>

          <div className="flex gap-3">
            <Link
              href="/admin/withdrawals"
              className="flex-1 bg-red-600 hover:bg-red-700 text-white font-bold px-4 py-3 rounded text-center"
            >
              出金管理画面へ
            </Link>
            <button
              onClick={() => setDismissed(true)}
              className="px-4 py-3 rounded border border-gray-600 text-gray-300 hover:bg-gray-800"
            >
              あとで
            </button>
          </div>
        </div>
      </div>
      {banner}
    </>
  )
}
