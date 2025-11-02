import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  // Staging環境のみベーシック認証を適用
  const isStaging = process.env.NEXT_PUBLIC_ENV === 'staging'

  if (!isStaging) {
    return NextResponse.next()
  }

  // ベーシック認証のチェック
  const basicAuth = request.headers.get('authorization')
  const url = request.nextUrl

  if (basicAuth) {
    const authValue = basicAuth.split(' ')[1]
    const [user, pwd] = atob(authValue).split(':')

    const validUser = process.env.BASIC_AUTH_USER || 'admin'
    const validPassword = process.env.BASIC_AUTH_PASSWORD || 'hashpilot2024'

    if (user === validUser && pwd === validPassword) {
      return NextResponse.next()
    }
  }

  // 認証失敗時
  return new NextResponse('Authentication required', {
    status: 401,
    headers: {
      'WWW-Authenticate': 'Basic realm="Staging Environment"',
    },
  })
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - api (API routes)
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     */
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
}
