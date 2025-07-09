import Link from "next/link"
import { Button } from "@/components/ui/button"

export default function HomePage() {
  return (
    <div className="min-h-screen relative text-white flex flex-col">
      {/* 背景画像 */}
      <div
        className="absolute inset-0 bg-cover bg-center bg-no-repeat"
        style={{
          backgroundImage: "url('/images/hash-pilot-hero-bg.jpg')",
        }}
      >
        {/* オーバーレイ */}
        <div className="absolute inset-0 bg-black/40"></div>
      </div>

      {/* コンテンツ */}
      <div className="relative z-10 flex flex-col min-h-screen">
        <header className="container mx-auto px-4 py-6">
          <nav className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10" />
            </div>
            {/* デスクトップ用ナビゲーション */}
            <div className="hidden md:flex space-x-4">
              <Link href="/login">
                <Button
                  variant="outline"
                  className="bg-gradient-to-r from-yellow-400 via-yellow-500 to-yellow-600 text-black border-yellow-400 hover:from-yellow-500 hover:via-yellow-600 hover:to-yellow-700 hover:text-black font-semibold shadow-lg hover:shadow-xl transition-all duration-300 transform hover:scale-105"
                >
                  ログイン
                </Button>
              </Link>
              <Link href="/admin-login">
                <Button
                  variant="outline"
                  className="text-red-400 border-red-400 hover:bg-red-900/50 backdrop-blur-sm bg-transparent"
                >
                  管理者
                </Button>
              </Link>
              <Link href="/pre-register">
                <Button className="bg-gradient-to-r from-amber-400 via-yellow-500 to-amber-600 hover:from-amber-500 hover:via-yellow-600 hover:to-amber-700 text-black font-bold shadow-lg hover:shadow-xl transition-all duration-300 transform hover:scale-105 border border-yellow-300">
                  新規登録
                </Button>
              </Link>
            </div>
            {/* モバイル用ハンバーガーメニュー */}
            <div className="md:hidden">
              <details className="relative">
                <summary className="list-none cursor-pointer">
                  <div className="w-6 h-6 flex flex-col justify-center items-center">
                    <span className="block w-5 h-0.5 bg-white mb-1"></span>
                    <span className="block w-5 h-0.5 bg-white mb-1"></span>
                    <span className="block w-5 h-0.5 bg-white"></span>
                  </div>
                </summary>
                <div className="absolute right-0 top-8 bg-black/80 backdrop-blur-md border border-yellow-500/30 rounded-lg shadow-2xl p-4 space-y-3 min-w-[150px] z-50">
                  <Link href="/login" className="block">
                    <Button
                      variant="outline"
                      className="w-full bg-gradient-to-r from-yellow-400 via-yellow-500 to-yellow-600 text-black border-yellow-400 hover:from-yellow-500 hover:via-yellow-600 hover:to-yellow-700 hover:text-black font-semibold"
                    >
                      ログイン
                    </Button>
                  </Link>
                  <Link href="/admin-login" className="block">
                    <Button
                      variant="outline"
                      className="w-full text-red-400 border-red-400 hover:bg-red-900/50 bg-transparent"
                    >
                      管理者
                    </Button>
                  </Link>
                  <Link href="/pre-register" className="block">
                    <Button className="w-full bg-gradient-to-r from-amber-400 via-yellow-500 to-amber-600 hover:from-amber-500 hover:via-yellow-600 hover:to-amber-700 text-black font-bold border border-yellow-300">
                      新規登録
                    </Button>
                  </Link>
                </div>
              </details>
            </div>
          </nav>
        </header>

        <main className="flex-1 container mx-auto px-4 py-12 flex items-center justify-center">
          <div className="text-center max-w-md mx-auto">
            <div className="mb-8">
              <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-32 mx-auto mb-6 drop-shadow-2xl" />
              <div className="text-xl md:text-2xl font-light text-yellow-100 mb-4">未来への投資を、今始めよう</div>
              <div className="text-sm text-gray-300 mb-8">HASH PILOTで暗号通貨投資の新しい世界を体験してください</div>
            </div>
            <div className="space-y-4">
              <Link href="/pre-register" className="block">
                <Button
                  size="lg"
                  className="w-full px-12 py-6 text-xl bg-gradient-to-r from-amber-400 via-yellow-500 to-amber-600 hover:from-amber-500 hover:via-yellow-600 hover:to-amber-700 text-black font-bold shadow-2xl hover:shadow-3xl transition-all duration-300 transform hover:scale-105 border-2 border-yellow-300 relative overflow-hidden group"
                >
                  <span className="relative z-10">今すぐ会員登録</span>
                  <div className="absolute inset-0 bg-gradient-to-r from-yellow-300 via-amber-400 to-yellow-500 opacity-0 group-hover:opacity-20 transition-opacity duration-300"></div>
                </Button>
              </Link>
              <Link href="/login" className="block">
                <Button
                  variant="outline"
                  size="lg"
                  className="w-full px-12 py-6 text-xl bg-black/60 text-white border-2 border-yellow-400 hover:bg-yellow-500/20 hover:text-yellow-100 hover:border-yellow-300 font-bold shadow-xl hover:shadow-2xl transition-all duration-300 transform hover:scale-105 backdrop-blur-md"
                >
                  ログイン
                </Button>
              </Link>
            </div>
          </div>
        </main>

        <footer className="bg-black/60 backdrop-blur-sm text-white py-8 mt-auto border-t border-yellow-500/20">
          <div className="container mx-auto px-4 text-center">
            <p className="text-yellow-100">&copy; 2025 HASH PILOT. All rights reserved.</p>
          </div>
        </footer>
      </div>
    </div>
  )
}
