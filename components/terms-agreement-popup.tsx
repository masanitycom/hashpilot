"use client"

import { useEffect, useRef, useState } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { AlertTriangle, ChevronDown } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface TermsAgreementPopupProps {
  userId: string
  termsAgreedAt: string | null
  userEmail?: string | null
}

const STORAGE_KEY_PREFIX = "terms_agreed_v1_"

async function logTermsEvent(payload: {
  user_id?: string
  user_email?: string | null
  auth_uid?: string | null
  event: string
  error_message?: string | null
  rows_affected?: number | null
  context?: Record<string, unknown>
}) {
  try {
    const ua = typeof navigator !== "undefined" ? navigator.userAgent : null
    await supabase.from("terms_agreement_log").insert({
      user_id: payload.user_id ?? null,
      user_email: payload.user_email ?? null,
      auth_uid: payload.auth_uid ?? null,
      event: payload.event,
      error_message: payload.error_message ?? null,
      rows_affected: payload.rows_affected ?? null,
      user_agent: ua,
      context: payload.context ?? null,
    })
  } catch {
    // ログ書き込み失敗は本処理に影響させない
  }
}

export function TermsAgreementPopup({ userId, termsAgreedAt, userEmail }: TermsAgreementPopupProps) {
  const [isMounted, setIsMounted] = useState(false)
  const [isVisible, setIsVisible] = useState(false)
  const [scrolledToBottom, setScrolledToBottom] = useState(false)
  const [check1, setCheck1] = useState(false)
  const [check2, setCheck2] = useState(false)
  const [check3, setCheck3] = useState(false)
  const [saving, setSaving] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)
  const sentinelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    setIsMounted(true)
    if (typeof window === "undefined" || !userId) return

    // DBに同意日時があれば絶対に表示しない（キャッシュクリアでも再表示されない）
    if (termsAgreedAt) {
      localStorage.setItem(`${STORAGE_KEY_PREFIX}${userId}`, termsAgreedAt)
      return
    }

    // DBに記録がない場合のみ表示（localStorageは初回表示のチラつき防止用）
    const localAgreed = localStorage.getItem(`${STORAGE_KEY_PREFIX}${userId}`)
    if (!localAgreed) {
      setIsVisible(true)
    }
  }, [userId, termsAgreedAt])

  useEffect(() => {
    if (!isVisible) return
    const el = scrollRef.current
    if (!el) return

    const checkBottom = () => {
      const threshold = 30
      const reachedBottom = el.scrollHeight - el.scrollTop - el.clientHeight <= threshold
      if (reachedBottom) setScrolledToBottom(true)
    }

    checkBottom()
    el.addEventListener("scroll", checkBottom, { passive: true })
    return () => el.removeEventListener("scroll", checkBottom)
  }, [isVisible])

  useEffect(() => {
    if (!isVisible) return
    const sentinel = sentinelRef.current
    const root = scrollRef.current
    if (!sentinel || !root) return
    if (typeof IntersectionObserver === "undefined") return

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setScrolledToBottom(true)
        }
      },
      { root, threshold: 0, rootMargin: "0px 0px 50px 0px" }
    )

    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [isVisible])

  const scrollToBottom = () => {
    const el = scrollRef.current
    if (!el) return
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" })
    // 「下までスクロールして続きを読む」ボタン押下時は、検知が外れる端末でも
    // 確実にチェックボックスを有効化できるよう直接フラグを立てる
    setScrolledToBottom(true)
  }

  const handleAgree = async () => {
    if (typeof window === "undefined" || saving) return
    setSaving(true)
    setErrorMsg(null)
    const now = new Date().toISOString()

    let authUid: string | null = null

    void logTermsEvent({
      user_id: userId,
      user_email: userEmail,
      event: "attempt",
      context: { now },
    })

    try {
      const authResult = await Promise.race([
        supabase.auth.getUser(),
        new Promise<never>((_, reject) =>
          setTimeout(
            () => reject(new Error("通信がタイムアウトしました。電波の良い場所で再度お試しください。")),
            15000
          )
        ),
      ])

      const authUser = (authResult as any)?.data?.user
      authUid = authUser?.id ?? null

      if (!authUser) {
        void logTermsEvent({
          user_id: userId,
          user_email: userEmail,
          event: "auth_failed",
          error_message: "supabase.auth.getUser returned no user",
        })
        throw new Error("ログイン情報を取得できませんでした。一度ログアウトしてから再度お試しください。")
      }

      const { data: updated, error: dbError } = await supabase
        .from("users")
        .update({ terms_agreed_at: now })
        .eq("id", authUser.id)
        .select("id, terms_agreed_at")

      if (dbError) {
        void logTermsEvent({
          user_id: userId,
          user_email: userEmail,
          auth_uid: authUid,
          event: "update_failed",
          error_message: dbError.message,
          context: { code: dbError.code, details: dbError.details, hint: dbError.hint },
        })
        throw new Error(`保存に失敗しました（${dbError.message}）。もう一度お試しください。`)
      }

      const rowCount = updated?.length ?? 0
      if (rowCount === 0) {
        void logTermsEvent({
          user_id: userId,
          user_email: userEmail,
          auth_uid: authUid,
          event: "no_rows",
          rows_affected: 0,
          error_message: "UPDATE matched 0 rows (auth.id != public.users.id?)",
        })
        throw new Error(
          "ユーザー情報の更新先が見つかりませんでした。サポートまでご連絡ください。"
        )
      }

      void logTermsEvent({
        user_id: userId,
        user_email: userEmail,
        auth_uid: authUid,
        event: "success",
        rows_affected: rowCount,
      })

      // DB保存成功時のみキャッシュに記録し、ポップアップを閉じる
      localStorage.setItem(`${STORAGE_KEY_PREFIX}${userId}`, now)
      setIsVisible(false)
    } catch (e: any) {
      console.error("[TermsAgreement] 保存失敗:", e)
      void logTermsEvent({
        user_id: userId,
        user_email: userEmail,
        auth_uid: authUid,
        event: "unexpected_error",
        error_message: e?.message || String(e),
      })
      setErrorMsg(
        e?.message || "保存に失敗しました。通信環境をご確認の上、もう一度お試しください。"
      )
    } finally {
      setSaving(false)
    }
  }

  if (!isMounted || !isVisible) return null

  const allChecked = check1 && check2 && check3
  const canAgree = scrolledToBottom && allChecked

  return (
    <div className="fixed inset-0 bg-black/90 z-[200] flex items-center justify-center p-2 sm:p-4">
      <div className="w-full max-w-2xl max-h-[95vh] flex flex-col">
        <Card className="bg-gray-900 border-red-500 border-2 shadow-2xl flex flex-col max-h-[95vh]">
          <CardContent className="p-0 flex flex-col min-h-0">
            <div className="p-4 sm:p-6 border-b border-gray-700 flex items-start gap-3">
              <div className="flex-shrink-0">
                <div className="w-10 h-10 bg-red-500 rounded-full flex items-center justify-center">
                  <AlertTriangle className="w-6 h-6 text-white" />
                </div>
              </div>
              <div>
                <h2 className="text-white font-bold text-lg sm:text-xl">
                  重要事項説明およびシステム利用規約への同意
                </h2>
                <p className="text-gray-400 text-xs sm:text-sm mt-1">
                  下までお読みいただき、全ての項目にチェックしてください
                </p>
              </div>
            </div>

            <div
              ref={scrollRef}
              className="overflow-y-auto px-4 sm:px-6 py-4 text-gray-200 text-sm leading-relaxed flex-1"
              style={{ maxHeight: "55vh" }}
            >
              <p className="mb-4">
                本サービス（以下「本システム」）のご利用に際し、以下の内容を十分にご確認ください。ユーザーが本システムにサインインしたことをもって、本規約の全てに同意したものとみなされます。
              </p>

              <h3 className="text-white font-bold mt-5 mb-2">1. 本システムの立場（システム提供者としての明示）</h3>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  <span className="font-semibold text-white">非開発者・非運用者の明示:</span>{" "}
                  当方は本システムという「場（プラットフォーム）」および「技術基盤」の提供者であり、本システム内で稼働する具体的な運用ロジック、アルゴリズムの開発者ではありません。
                </li>
                <li>
                  <span className="font-semibold text-white">非登録業者の明示:</span>{" "}
                  当方は金融商品取引法上の登録業者（投資助言・代理業、投資運用業等）ではありません。特定の金融商品の勧誘、売買の指示、または資産の運用代行を行う立場にはありません。
                </li>
              </ul>

              <h3 className="text-white font-bold mt-5 mb-2">2. NFTの性質とリスクに関する同意</h3>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  <span className="font-semibold text-white">非金融商品:</span>{" "}
                  本システムを通じて購入または運用されるNFTは、特定の収益を保証する有価証券ではなく、デジタルデータとしての価値を有するものです。
                </li>
                <li>
                  <span className="font-semibold text-white">価格変動リスク:</span>{" "}
                  NFTの資産価値は市場動向、ブロックチェーン技術の変化、およびその他の外部要因により激しく変動し、購入価格を大幅に下回る、あるいは無価値になる可能性があります。
                </li>
                <li>
                  <span className="font-semibold text-white">元本および利益の非保証:</span>{" "}
                  過去の運用実績やシミュレーションは将来の成果を約束するものではなく、いかなる場合も元本保証および利益の保証は存在しません。
                </li>
              </ul>

              <h3 className="text-white font-bold mt-5 mb-2">3. 免責事項（責任の所在）</h3>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  <span className="font-semibold text-white">自己責任の原則:</span>{" "}
                  本システムを利用したNFTの購入、保持、運用設定、およびその結果生じる一切の損害（直接的・間接的を問わず）について、ユーザーは全責任を負うものとし、当方は一切の賠償責任を負いません。
                </li>
                <li>
                  <span className="font-semibold text-white">技術的免責:</span>{" "}
                  ブロックチェーンネットワークの遅延、スマートコントラクトのバグ、ハッキング、システムメンテナンス、またはAPIの仕様変更に起因する損失について、当方は補償いたしません。
                </li>
                <li>
                  <span className="font-semibold text-white">第三者ロジックの免責:</span>{" "}
                  本システム上で第三者が提供するロジックや戦略を利用する場合、その内容の妥当性や結果について当方は一切関与せず、保証も行いません。
                </li>
              </ul>

              <h3 className="text-white font-bold mt-5 mb-2">4. 禁止事項</h3>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  <span className="font-semibold text-white">不正行為の禁止:</span>{" "}
                  システムの脆弱性を突く行為、リバースエンジニアリング、およびアカウントの第三者への貸与・譲渡を固く禁じます。
                </li>
                <li>
                  <span className="font-semibold text-white">日本国内法遵守:</span>{" "}
                  ユーザーは、自身の居住国の法律（特に日本の金融商品取引法、出資法等）を遵守し、自身の判断で利用するものとします。
                </li>
              </ul>

              <div className="mt-6 p-3 bg-green-900/40 border border-green-600 rounded-lg text-green-200 text-sm">
                最後までお読みいただきありがとうございます。下のチェック項目にご同意ください。
              </div>
              <div ref={sentinelRef} aria-hidden="true" className="h-1 w-full" />
            </div>

            {!scrolledToBottom && (
              <button
                type="button"
                onClick={scrollToBottom}
                className="mx-4 sm:mx-6 my-2 flex items-center justify-center gap-2 bg-blue-600/20 hover:bg-blue-600/30 border border-blue-500 text-blue-200 text-sm py-2 rounded-lg transition"
              >
                <ChevronDown className="w-4 h-4 animate-bounce" />
                下までスクロールして続きを読む
              </button>
            )}

            <div className="p-4 sm:p-6 border-t border-gray-700 space-y-3">
              <div
                className={`space-y-2 transition-opacity ${
                  scrolledToBottom ? "opacity-100" : "opacity-50 pointer-events-none"
                }`}
              >
                <label className="flex items-start gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={check1}
                    onChange={(e) => setCheck1(e.target.checked)}
                    disabled={!scrolledToBottom}
                    className="mt-1 w-4 h-4 rounded border-gray-400 text-blue-600 focus:ring-blue-500 cursor-pointer flex-shrink-0"
                  />
                  <span className="text-gray-200 text-sm">
                    私は、本システムが投資助言や運用代行を行うものではなく、単なるシステム提供であると理解しました。
                  </span>
                </label>
                <label className="flex items-start gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={check2}
                    onChange={(e) => setCheck2(e.target.checked)}
                    disabled={!scrolledToBottom}
                    className="mt-1 w-4 h-4 rounded border-gray-400 text-blue-600 focus:ring-blue-500 cursor-pointer flex-shrink-0"
                  />
                  <span className="text-gray-200 text-sm">
                    私は、NFTの価値が消失するリスクを理解し、余剰資金の範囲内で自己責任において利用することに同意します。
                  </span>
                </label>
                <label className="flex items-start gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={check3}
                    onChange={(e) => setCheck3(e.target.checked)}
                    disabled={!scrolledToBottom}
                    className="mt-1 w-4 h-4 rounded border-gray-400 text-blue-600 focus:ring-blue-500 cursor-pointer flex-shrink-0"
                  />
                  <span className="text-gray-200 text-sm">
                    私は、本システムの利用に関し、運営者に対して一切の損害賠償請求を行わないことを誓約します。
                  </span>
                </label>
              </div>

              {errorMsg && (
                <div className="p-3 bg-red-900/40 border border-red-500 rounded-lg text-red-100 text-sm whitespace-pre-wrap">
                  {errorMsg}
                </div>
              )}

              <Button
                onClick={handleAgree}
                disabled={!canAgree || saving}
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 disabled:text-gray-400 text-white font-bold py-3 text-base"
              >
                {saving
                  ? "保存中..."
                  : !scrolledToBottom
                    ? "下までスクロールしてください"
                    : !allChecked
                      ? "全ての項目にチェックしてください"
                      : errorMsg
                        ? "もう一度試す"
                        : "同意して続ける"}
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
